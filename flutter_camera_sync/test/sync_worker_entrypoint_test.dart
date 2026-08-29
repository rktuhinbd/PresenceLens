// The worker's result mapping (FLT-SYNC-002, FLT-SYNC-004, FLT-ERR-007,
// ADR-F19).
//
// The plugin callback itself cannot run on a host — nor can `path_provider`,
// which is why the isolate builds its layer through an injectable factory. What
// is asserted here is the decision the worker actually makes: finish, continue,
// or ask the platform to back off.
//
// This is NOT evidence that Android ran the worker. That is a device check
// (`SYNC_ENGINE.md` §10) and is not claimed anywhere in this file.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:presence_lens_capture/data/api/mock_upload_api.dart';
import 'package:presence_lens_capture/data/composition/data_layer.dart';
import 'package:presence_lens_capture/data/sync/queue_processor.dart';
import 'package:presence_lens_capture/data/sync/work_manager_sync_scheduler.dart';
import 'package:presence_lens_capture/domain/entities/batch_status.dart';
import 'package:presence_lens_capture/domain/entities/failure_category.dart';
import 'package:presence_lens_capture/domain/entities/image_status.dart';
import 'package:presence_lens_capture/domain/entities/queued_image.dart';
import 'package:presence_lens_capture/domain/ports/sync_scheduler.dart';
import 'package:presence_lens_capture/sync_worker_entrypoint.dart';

import 'support/fakes.dart';
import 'support/queue_harness.dart';

void main() {
  late QueueHarness harness;
  late MutableClock clock;
  late RecordingScheduler scheduler;

  final DateTime now = DateTime.utc(2026, 8, 29, 12);

  setUp(() async {
    harness = await QueueHarness.create();
    clock = MutableClock(now);
    scheduler = RecordingScheduler();
  });

  tearDown(() async {
    await harness.dispose();
  });

  /// Builds the layer the way the worker would: its own connection to the same
  /// file, its own directory, nothing handed across from anywhere else.
  ///
  /// The scheduler is injected because the real one would reach the plugin, and
  /// there is no plugin on a host. What is under test is the *decision*, and
  /// the decision is visible in what the worker asks the scheduler for.
  DataLayerFactory workerLayer(MockScenario scenario) {
    return () async => assembleDataLayer(
      database: await harness.openConnection(),
      capturesRoot: Directory(p.join(harness.directory.path, 'captures')),
      forBackground: true,
      scenario: scenario,
      uploadLatency: Duration.zero,
      clock: clock,
      scheduler: scheduler,
    );
  }

  Future<List<QueuedImage>> seedWithFiles({
    required String batchId,
    required int count,
  }) async {
    final List<QueuedImage> images = await harness.seedQueuedBatch(
      batchId: batchId,
      count: count,
    );
    for (final QueuedImage image in images) {
      await Directory(p.dirname(image.localPath)).create(recursive: true);
      await File(image.localPath).writeAsString('bytes');
    }
    return images;
  }

  Future<bool> runWorker(MockScenario scenario) => runDrainTask(
    WorkManagerSyncScheduler.taskName,
    buildLayer: workerLayer(scenario),
  );

  group('the task finishes', () {
    test('an empty queue completes, and asks for nothing', () async {
      expect(
        await runWorker(MockScenario.alwaysSucceed),
        isTrue,
        reason: 'nothing to do is success, not a retry',
      );
      expect(scheduler.continuationCount, 0);
      expect(scheduler.scheduleCount, 0);
    });

    test('a fully drained queue completes, and asks for nothing', () async {
      await seedWithFiles(batchId: 'b1', count: 3);

      expect(await runWorker(MockScenario.alwaysSucceed), isTrue);

      expect(scheduler.continuationCount, 0);
      expect(await harness.dao.outstandingCount(), 0);
      expect(
        (await harness.dao.batchById('b1'))!.status,
        BatchStatus.completed,
      );
    });

    test('permanent failures complete the task rather than looping', () async {
      // Those items have left the work set, so there is nothing to come back
      // for. Returning retry here is how a queue ends up retried forever
      // (`FLT-ERR-007`).
      await seedWithFiles(batchId: 'b1', count: 1);

      expect(await runWorker(MockScenario.failPermanently), isTrue);

      expect(scheduler.continuationCount, 0);
      final QueuedImage stored = (await harness.dao.imageById('b1-image-0'))!;
      expect(stored.status, ImageStatus.failedPermanent);
      expect(stored.lastFailure, FailureCategory.serverRejected);
    });

    test('a queue whose files are gone still terminates', () async {
      // Rows seeded without ever writing the files: every item resolves to a
      // permanent local failure, and the worker stops asking to come back.
      await harness.seedQueuedBatch(batchId: 'b1', count: 2);

      expect(await runWorker(MockScenario.alwaysSucceed), isTrue);

      expect(await harness.dao.outstandingCount(), 0);
      for (final QueuedImage image in await harness.dao.imagesInBatch('b1')) {
        expect(image.status, ImageStatus.failedPermanent);
        expect(image.lastFailure, FailureCategory.missingLocalFile);
      }
    });
  });

  group('the task asks WorkManager to retry (backoff is correct here)', () {
    test('a queue that will not upload returns false', () async {
      await seedWithFiles(batchId: 'b1', count: 2);

      expect(
        await runWorker(MockScenario.alwaysFailRetryable),
        isFalse,
        reason: 'false is WorkManager retry',
      );

      expect(
        scheduler.continuationCount,
        0,
        reason: 'a failed slice must not enqueue a successor as well',
      );
      expect(await harness.dao.outstandingCount(), 2);
      for (final QueuedImage image in await harness.dao.imagesInBatch('b1')) {
        expect(image.status, ImageStatus.pending);
        expect(image.attemptCount, 1);
        expect(File(image.localPath).existsSync(), isTrue);
      }
    });

    test('a failure to build the layer asks for a retry', () async {
      // The database could not be opened, the directory was unavailable, a
      // plugin was not ready. Nothing is lost, so the honest answer is
      // "come back".
      expect(
        await runDrainTask(
          WorkManagerSyncScheduler.taskName,
          buildLayer: () async => throw Exception('no database here'),
        ),
        isFalse,
      );
    });
  });

  group('healthy backlog continues instead of failing (ADR-F19)', () {
    // The defect this whole group exists for: a bounded slice that uploaded
    // everything it was allowed to used to report the same thing as a slice
    // that could not upload at all. On Android that meant a hundred healthy
    // photos drained under a backoff curve that grew every time they succeeded.

    test(
      'a bound-limited healthy slice does NOT report an upload failure',
      () async {
        // 30 items, a 25-item bound: the first pass is entirely successful and
        // still leaves work.
        await seedWithFiles(batchId: 'b1', count: 30);

        final bool result = await runWorker(MockScenario.alwaysSucceed);

        expect(
          result,
          isTrue,
          reason: 'the slice succeeded; returning false would invite backoff',
        );
        expect(
          await harness.countWithStatus(ImageStatus.uploaded),
          QueueProcessor.defaultMaxItemsPerDrain,
        );
        expect(await harness.dao.outstandingCount(), 5);
      },
    );

    test('and it leaves a continuation scheduled', () async {
      await seedWithFiles(batchId: 'b1', count: 30);

      await runWorker(MockScenario.alwaysSucceed);

      expect(
        scheduler.continuationCount,
        1,
        reason: 'the backlog must have something coming back for it',
      );
      expect(
        scheduler.scheduleCount,
        0,
        reason: 'a worker never re-registers entry work (RS-04)',
      );
    });

    test('exactly one continuation per slice — no duplicate chains', () async {
      await seedWithFiles(batchId: 'b1', count: 60);

      await runWorker(MockScenario.alwaysSucceed);
      expect(scheduler.continuationCount, 1);

      await runWorker(MockScenario.alwaysSucceed);
      expect(scheduler.continuationCount, 2);
    });

    test('successive slices drain the queue with nothing lost', () async {
      // The data-integrity half of the fix. Slices are bounded, so the queue is
      // handed between invocations; every item must survive that handover
      // exactly once.
      final List<QueuedImage> seeded = await seedWithFiles(
        batchId: 'b1',
        count: 60,
      );

      bool result = await runWorker(MockScenario.alwaysSucceed);
      int passes = 1;
      while (await harness.dao.outstandingCount() > 0) {
        expect(result, isTrue, reason: 'no healthy pass may report a failure');
        result = await runWorker(MockScenario.alwaysSucceed);
        passes++;
        expect(passes, lessThan(10), reason: 'guard against a runaway loop');
      }

      expect(passes, 3, reason: '60 items at a 25-item bound');
      expect(result, isTrue);
      expect(
        await harness.countWithStatus(ImageStatus.uploaded),
        seeded.length,
      );
      expect(
        (await harness.dao.batchById('b1'))!.status,
        BatchStatus.completed,
      );
    });

    test('the last slice completes without asking for another', () async {
      await seedWithFiles(batchId: 'b1', count: 30);

      await runWorker(MockScenario.alwaysSucceed);
      expect(scheduler.continuationCount, 1);

      expect(await runWorker(MockScenario.alwaysSucceed), isTrue);
      expect(
        scheduler.continuationCount,
        1,
        reason: 'a drained queue must not chain another wake-up',
      );
    });

    test(
      'if the continuation cannot be scheduled, it falls back to retry',
      () async {
        // The safe direction. A backlog delayed by backoff is recoverable; a
        // backlog nobody is coming back for is not.
        scheduler.continuationOutcome = SchedulingOutcome.unavailable;
        await seedWithFiles(batchId: 'b1', count: 30);

        final bool result = await runWorker(MockScenario.alwaysSucceed);

        expect(result, isFalse);
        expect(scheduler.continuationCount, 1);
        expect(
          await harness.dao.outstandingCount(),
          5,
          reason: 'the uploaded 25 are still recorded; nothing was rolled back',
        );
      },
    );
  });

  group('task identity', () {
    test('an unrecognised task name completes without work', () async {
      bool built = false;

      final bool result = await runDrainTask(
        'some.other.task',
        buildLayer: () async {
          built = true;
          return workerLayer(MockScenario.alwaysSucceed)();
        },
      );

      expect(result, isTrue);
      expect(
        built,
        isFalse,
        reason: 'no data layer is built for a foreign task',
      );
    });
  });

  test('the worker closes the connection it opened', () async {
    await seedWithFiles(batchId: 'b1', count: 1);
    DataLayer? built;

    await runDrainTask(
      WorkManagerSyncScheduler.taskName,
      buildLayer: () async {
        built = await workerLayer(MockScenario.alwaysSucceed)();
        return built!;
      },
    );

    expect(built, isNotNull);
    expect(
      built!.database.isOpen,
      isFalse,
      reason: 'the worker isolate must not leak a database handle',
    );
  });
}
