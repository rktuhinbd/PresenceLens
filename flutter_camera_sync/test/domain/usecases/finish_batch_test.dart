// Finishing a batch: the durable transaction, then the drain request
// (FLT-BAT-005, FLT-SYNC-004, ADR-F21).
//
// Properties F, G, H and J of the final scheduling audit live here.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:presence_lens_capture/data/storage/file_system_capture_store.dart';
import 'package:presence_lens_capture/domain/entities/batch_status.dart';
import 'package:presence_lens_capture/domain/entities/image_status.dart';
import 'package:presence_lens_capture/domain/entities/queued_image.dart';
import 'package:presence_lens_capture/domain/ports/sync_scheduler.dart';
import 'package:presence_lens_capture/domain/usecases/finish_batch.dart';
import 'package:presence_lens_capture/domain/usecases/record_capture.dart';

import '../../support/fakes.dart';
import '../../support/queue_harness.dart';

void main() {
  late QueueHarness harness;
  late RecordingScheduler scheduler;
  late MutableClock clock;
  late FinishBatch finishBatch;
  late RecordCapture recordCapture;

  final DateTime now = DateTime.utc(2026, 8, 30, 11);

  setUp(() async {
    harness = await QueueHarness.create();
    scheduler = RecordingScheduler();
    clock = MutableClock(now);
    finishBatch = FinishBatch(
      queue: harness.dao,
      scheduler: scheduler,
      clock: clock,
    );
    recordCapture = RecordCapture(
      queue: harness.dao,
      store: FileSystemCaptureStore(
        root: Directory(p.join(harness.directory.path, 'captures')),
      ),
      ids: SequentialIdGenerator(prefix: 'img'),
      clock: clock,
    );
  });

  tearDown(() async {
    await harness.dispose();
  });

  Future<File> tempCapture(String name) =>
      File(p.join(harness.directory.path, name)).writeAsString('bytes');

  Future<void> captureInto(String batchId, String name) async {
    clock.advance(const Duration(seconds: 1));
    await recordCapture(
      batchId: batchId,
      sourcePath: (await tempCapture(name)).path,
    );
  }

  group('F — scheduling happens after the durable transaction', () {
    test('the batch is queued and a drain is requested', () async {
      await harness.dao.createDraftBatch(id: 'b1', createdAt: now);
      await captureInto('b1', 'a.jpg');

      final FinishBatchResult result = await finishBatch('b1');

      expect(result.batch.status, BatchStatus.queued);
      expect(result.scheduling, SchedulingOutcome.requested);
      expect(scheduler.scheduleCount, 1);
    });

    test('the images are already PENDING when the request is made', () async {
      // The ordering assertion with teeth: the scheduler reads the queue at the
      // moment it is called, and must find the work already committed. Asking
      // first and committing second would let a worker start, see nothing, and
      // finish — the very race this gate closes.
      await harness.dao.createDraftBatch(id: 'b1', createdAt: now);
      await captureInto('b1', 'a.jpg');
      await captureInto('b1', 'b.jpg');

      int pendingWhenScheduled = -1;
      final FinishBatch observing = FinishBatch(
        queue: harness.dao,
        scheduler: _ObservingScheduler(() async {
          pendingWhenScheduled = await harness.countWithStatus(
            ImageStatus.pending,
          );
        }),
        clock: clock,
      );

      await observing('b1');

      expect(pendingWhenScheduled, 2);
    });

    test('every image moved in the same transaction', () async {
      await harness.dao.createDraftBatch(id: 'b1', createdAt: now);
      await captureInto('b1', 'a.jpg');
      await captureInto('b1', 'b.jpg');

      await finishBatch('b1');

      for (final QueuedImage image in await harness.dao.imagesInBatch('b1')) {
        expect(image.status, ImageStatus.pending);
      }
    });
  });

  group('G — a refused transaction schedules nothing', () {
    test('an empty batch is refused, and no drain is requested', () async {
      await harness.dao.createDraftBatch(id: 'b1', createdAt: now);

      await expectLater(finishBatch('b1'), throwsA(isA<StateError>()));

      expect(
        scheduler.scheduleCount,
        0,
        reason: 'there is no uploadable work to schedule for',
      );
      expect((await harness.dao.batchById('b1'))!.status, BatchStatus.draft);
    });

    test(
      'an already-finished batch is refused, and schedules nothing',
      () async {
        await harness.dao.createDraftBatch(id: 'b1', createdAt: now);
        await captureInto('b1', 'a.jpg');
        await finishBatch('b1');
        expect(scheduler.scheduleCount, 1);

        await expectLater(finishBatch('b1'), throwsA(isA<StateError>()));

        expect(scheduler.scheduleCount, 1, reason: 'no second request');
      },
    );

    test(
      'a batch that does not exist is refused, and schedules nothing',
      () async {
        await expectLater(finishBatch('ghost'), throwsA(isA<StateError>()));

        expect(scheduler.scheduleCount, 0);
      },
    );
  });

  group('H — a DRAFT capture schedules nothing', () {
    test('recording captures never asks for a drain', () async {
      // A `DRAFT` image is not uploadable, so waking a worker for it would
      // achieve nothing — and a twenty-photo session would build twenty idle
      // nodes on the chain. `RecordCapture` takes no scheduler at all, so this
      // cannot regress by accident (`ADR-F21`).
      await harness.dao.createDraftBatch(id: 'b1', createdAt: now);

      for (int i = 0; i < 5; i++) {
        await captureInto('b1', 'shot-$i.jpg');
      }

      expect(scheduler.scheduleCount, 0);
      expect(scheduler.continuationCount, 0);
      expect(await harness.countWithStatus(ImageStatus.draft), 5);
    });

    test('a whole session produces exactly one drain request', () async {
      await harness.dao.createDraftBatch(id: 'b1', createdAt: now);
      for (int i = 0; i < 20; i++) {
        await captureInto('b1', 'shot-$i.jpg');
      }

      await finishBatch('b1');

      expect(
        scheduler.scheduleCount,
        1,
        reason: '20 captures, 1 finished batch, 1 request',
      );
    });
  });

  group('J — a scheduling failure cannot undo durable work', () {
    test('the batch stays queued and its images stay pending', () async {
      scheduler.drainOutcome = SchedulingOutcome.unavailable;
      await harness.dao.createDraftBatch(id: 'b1', createdAt: now);
      await captureInto('b1', 'a.jpg');

      final FinishBatchResult result = await finishBatch('b1');

      expect(result.scheduling, SchedulingOutcome.unavailable);
      expect(result.isDurablyQueued, isTrue);
      expect((await harness.dao.batchById('b1'))!.status, BatchStatus.queued);
      expect(await harness.dao.outstandingCount(), 1);
      final QueuedImage stored = (await harness.dao.imagesInBatch('b1')).single;
      expect(stored.status, ImageStatus.pending);
      expect(File(stored.localPath).existsSync(), isTrue);
    });

    test(
      'and the caller is told, rather than being handed an exception',
      () async {
        scheduler.drainOutcome = SchedulingOutcome.unavailable;
        await harness.dao.createDraftBatch(id: 'b1', createdAt: now);
        await captureInto('b1', 'a.jpg');

        await expectLater(finishBatch('b1'), completes);
      },
    );
  });
}

/// Runs a callback at the instant scheduling is requested.
class _ObservingScheduler implements SyncScheduler {
  _ObservingScheduler(this._onSchedule);

  final Future<void> Function() _onSchedule;

  @override
  Future<SchedulingOutcome> scheduleDrain() async {
    await _onSchedule();
    return SchedulingOutcome.requested;
  }

  @override
  Future<SchedulingOutcome> scheduleContinuation() async =>
      SchedulingOutcome.requested;
}
