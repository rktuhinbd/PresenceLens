// INTEGRATION tier — the presentation layer over the **real** persistence.
//
// These are plain `test()` cases, not `testWidgets`, and that is a deliberate
// split rather than a convenience: `testWidgets` runs inside a fake-async zone
// where the real SQLite engine's file I/O never completes. So the claims that
// need a real database — reconciliation, durability under a scheduling failure,
// what the screen state says after a genuine drain — are made here, against the
// real DAO, the real `QueueProcessor` and the real use cases
// (`TEST_STRATEGY.md` §2).
//
// What is still *not* claimed: that Android runs a worker. Every scheduling
// assertion here is about what the app **asked** for, never about what the OS
// did with the request (`RS-02`).

import 'package:flutter_test/flutter_test.dart';
import 'package:presence_lens_capture/data/sync/connectivity_drain_trigger.dart';
import 'package:presence_lens_capture/data/sync/queue_processor.dart';
import 'package:presence_lens_capture/domain/entities/failure_category.dart';
import 'package:presence_lens_capture/domain/entities/image_status.dart';
import 'package:presence_lens_capture/domain/entities/queued_image.dart';
import 'package:presence_lens_capture/domain/entities/upload_outcome.dart';
import 'package:presence_lens_capture/domain/ports/sync_scheduler.dart';
import 'package:presence_lens_capture/domain/ports/upload_api.dart';
import 'package:presence_lens_capture/domain/usecases/capture_into_batch.dart';
import 'package:presence_lens_capture/domain/usecases/finish_batch.dart';
import 'package:presence_lens_capture/domain/usecases/record_capture.dart';
import 'package:presence_lens_capture/presentation/batch/batch_cubit.dart';
import 'package:presence_lens_capture/presentation/uploads/sync_bloc.dart';
import 'package:presence_lens_capture/presentation/uploads/sync_event.dart';

import '../support/fakes.dart';
import '../support/queue_harness.dart';

/// The presentation layer wired to real SQLite.
class _Rig {
  _Rig._(
    this.queue,
    this.bloc,
    this.batch,
    this.scheduler,
    this.connectivity,
    this.store,
  );

  static Future<_Rig> create({
    bool hasLink = true,
    UploadApi? api,
    SchedulingOutcome drainOutcome = SchedulingOutcome.requested,
    bool withProcessor = true,
  }) async {
    final QueueHarness queue = await QueueHarness.create();
    final FakeCaptureStore store = FakeCaptureStore();
    final MutableClock clock = MutableClock(DateTime.utc(2026, 8, 30, 9));
    final RecordingScheduler scheduler = RecordingScheduler(
      drainOutcome: drainOutcome,
    );
    final FakeConnectivity connectivity = FakeConnectivity(hasLinkNow: hasLink);
    final UploadApi transport =
        api ??
        ScriptedUploadApi(
          (QueuedImage image, int _) =>
              UploadSucceeded(idempotencyKey: image.id),
        );

    final SyncBloc bloc = SyncBloc(
      queue: queue.dao,
      scheduler: scheduler,
      connectivity: connectivity,
      queueProcessor: withProcessor
          ? QueueProcessor(
              queue: queue.dao,
              api: transport,
              store: store,
              clock: clock,
            )
          : null,
      drainTrigger: ConnectivityDrainTrigger(
        connectivity: connectivity,
        scheduler: scheduler,
      ),
      completionHold: const Duration(seconds: 1),
    );

    final BatchCubit batch = BatchCubit(
      queue: queue.dao,
      finishBatch: FinishBatch(
        queue: queue.dao,
        scheduler: scheduler,
        clock: clock,
      ),
    );

    final _Rig rig = _Rig._(queue, bloc, batch, scheduler, connectivity, store)
      .._clock = clock;
    await batch.start();
    return rig;
  }

  final QueueHarness queue;
  final SyncBloc bloc;
  final BatchCubit batch;
  final RecordingScheduler scheduler;
  final FakeConnectivity connectivity;
  final FakeCaptureStore store;
  late final MutableClock _clock;

  /// The capture path, wired exactly as the camera's is.
  CaptureIntoBatch get captureIntoBatch => CaptureIntoBatch(
    queue: queue.dao,
    recordCapture: RecordCapture(
      queue: queue.dao,
      store: store,
      ids: _ids,
      clock: _clock,
    ),
    ids: _ids,
    clock: _clock,
  );

  final SequentialIdGenerator _ids = SequentialIdGenerator();

  /// Waits for the bloc to go quiet.
  ///
  /// Real time, not microtask yields: the database engine does genuine file I/O
  /// off the main isolate, so a chain of `Future.value` hops would return before
  /// the first query had even started.
  Future<void> settle() async {
    for (int i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  Future<void> dispose() async {
    await bloc.close();
    await batch.close();
    await connectivity.dispose();
    await queue.dispose();
  }
}

void main() {
  group('startup reconciliation — closing RS-11', () {
    test('durable pending work found at launch requests a drain', () async {
      final _Rig rig = await _Rig.create(withProcessor: false);
      addTearDown(rig.dispose);
      // Left behind by a previous process: queued, pending, nothing scheduled.
      await rig.queue.seedQueuedBatch(batchId: 'b1', count: 2);
      final int before = rig.scheduler.scheduleCount;

      rig.bloc.add(const SyncStarted());
      await rig.settle();

      // The residual risk F1 recorded: a scheduling request that was lost is
      // never retried until *something* asks again. This is that something.
      expect(rig.scheduler.scheduleCount, before + 1);
      expect(rig.bloc.state.lastScheduling, SchedulingOutcome.requested);
      expect(rig.bloc.state.pendingCount, 2);
    });

    test('an empty queue at launch asks the OS for nothing', () async {
      final _Rig rig = await _Rig.create(withProcessor: false);
      addTearDown(rig.dispose);

      rig.bloc.add(const SyncStarted());
      await rig.settle();

      // Waking a worker for an empty queue is a battery cost with no benefit.
      expect(rig.scheduler.scheduleCount, 0);
      expect(rig.bloc.state.isEmpty, isTrue);
    });

    test('a DRAFT capture alone schedules nothing', () async {
      final _Rig rig = await _Rig.create(withProcessor: false);
      addTearDown(rig.dispose);
      rig.bloc.add(const SyncStarted());
      await rig.settle();

      await rig.captureIntoBatch(temporaryPath: 'tmp/one.jpg');
      await rig.settle();

      // A `DRAFT` image is not uploadable, so a twenty-photo session produces
      // zero drain requests (`ADR-F21`). The queue change is still observed.
      expect(rig.scheduler.scheduleCount, 0);
      // And a draft is not a *pending upload*, so it is not listed as one.
      expect(rig.bloc.state.isEmpty, isTrue);
      expect(rig.batch.state.imageCount, 1);
    });
  });

  group('resume and connectivity reconciliation', () {
    test('a resume with pending work requests a drain', () async {
      final _Rig rig = await _Rig.create(withProcessor: false);
      addTearDown(rig.dispose);
      await rig.queue.seedQueuedBatch(batchId: 'b1', count: 1);
      rig.bloc.add(const SyncStarted());
      await rig.settle();
      final int afterStartup = rig.scheduler.scheduleCount;

      rig.bloc.add(const SyncResumed());
      await rig.settle();

      expect(rig.scheduler.scheduleCount, afterStartup + 1);
    });

    test('regaining a link requests a drain', () async {
      final _Rig rig = await _Rig.create(hasLink: false, withProcessor: false);
      addTearDown(rig.dispose);
      await rig.queue.seedQueuedBatch(batchId: 'b1', count: 1);
      rig.bloc.add(const SyncStarted());
      await rig.settle();
      final int before = rig.scheduler.scheduleCount;

      rig.connectivity.emit(true);
      await rig.settle();

      // Requested exactly once, by the F1 trigger. The bloc deliberately does
      // not also ask, so one signal does not become two chain nodes.
      expect(rig.scheduler.scheduleCount, before + 1);
      expect(rig.bloc.state.hasLink, isTrue);
    });

    test('losing a link schedules nothing and gates nothing', () async {
      final _Rig rig = await _Rig.create(withProcessor: false);
      addTearDown(rig.dispose);
      await rig.queue.seedQueuedBatch(batchId: 'b1', count: 1);
      rig.bloc.add(const SyncStarted());
      await rig.settle();
      final int before = rig.scheduler.scheduleCount;

      rig.connectivity.emit(false);
      await rig.settle();

      expect(rig.scheduler.scheduleCount, before);
      expect(rig.bloc.state.hasLink, isFalse);
      // The work is untouched: connectivity is advisory and never a gate.
      expect(rig.bloc.state.pendingCount, 1);
    });
  });

  group('a scheduling failure never costs a photograph', () {
    test('the queue stays intact and the refusal is visible', () async {
      final _Rig rig = await _Rig.create(
        drainOutcome: SchedulingOutcome.unavailable,
        withProcessor: false,
      );
      addTearDown(rig.dispose);
      await rig.queue.seedQueuedBatch(batchId: 'b1', count: 3);

      rig.bloc.add(const SyncStarted());
      await rig.settle();

      expect(rig.bloc.state.lastScheduling, SchedulingOutcome.unavailable);
      // Nothing durable moved. A lost wake-up costs a delay, never a photo.
      expect(await rig.queue.countWithStatus(ImageStatus.pending), 3);
      expect(rig.bloc.state.pendingCount, 3);
    });

    test('a later resume asks again', () async {
      final _Rig rig = await _Rig.create(
        drainOutcome: SchedulingOutcome.unavailable,
        withProcessor: false,
      );
      addTearDown(rig.dispose);
      await rig.queue.seedQueuedBatch(batchId: 'b1', count: 1);
      rig.bloc.add(const SyncStarted());
      await rig.settle();

      rig.scheduler.drainOutcome = SchedulingOutcome.requested;
      rig.bloc.add(const SyncResumed());
      await rig.settle();

      expect(rig.bloc.state.lastScheduling, SchedulingOutcome.requested);
    });
  });

  group('finish batch to visible pending work', () {
    test(
      'finishing moves the whole batch and the screen state follows',
      () async {
        final _Rig rig = await _Rig.create(
          hasLink: false,
          withProcessor: false,
        );
        addTearDown(rig.dispose);
        rig.bloc.add(const SyncStarted());
        await rig.settle();

        await rig.captureIntoBatch(temporaryPath: 'tmp/a.jpg');
        await rig.captureIntoBatch(temporaryPath: 'tmp/b.jpg');
        await rig.batch.refresh();
        expect(rig.batch.state.imageCount, 2);

        // A local, durable act performed with no link at all.
        final String? finished = await rig.batch.finish();
        rig.bloc.add(const SyncBatchFinished());
        await rig.settle();

        expect(finished, isNotNull);
        expect(await rig.queue.countWithStatus(ImageStatus.pending), 2);
        expect(rig.batch.state.hasCaptures, isFalse);
        expect(rig.bloc.state.batches, hasLength(1));
        expect(rig.bloc.state.pendingCount, 2);
      },
    );

    test('an empty batch is refused without scheduling anything', () async {
      final _Rig rig = await _Rig.create(withProcessor: false);
      addTearDown(rig.dispose);

      final String? finished = await rig.batch.finish();

      expect(finished, isNull);
      expect(rig.scheduler.scheduleCount, 0);
    });
  });

  group('a foreground drain moves the queue and the screen with it', () {
    test(
      'a successful pass leaves nothing pending and the batch synced',
      () async {
        final _Rig rig = await _Rig.create();
        addTearDown(rig.dispose);
        final List<QueuedImage> seeded = await rig.queue.seedQueuedBatch(
          batchId: 'b1',
          count: 2,
        );
        for (final QueuedImage image in seeded) {
          rig.store.files.add(image.localPath);
        }

        rig.bloc.add(const SyncStarted());
        await rig.settle();

        expect(await rig.queue.countWithStatus(ImageStatus.uploaded), 2);
        expect(rig.bloc.state.pendingCount, 0);
        // Held briefly so the success is witnessed rather than glimpsed.
        expect(rig.bloc.state.batches.single.isSynced, isTrue);
      },
    );

    test('a completed batch collapses out after its hold', () async {
      final _Rig rig = await _Rig.create();
      addTearDown(rig.dispose);
      final List<QueuedImage> seeded = await rig.queue.seedQueuedBatch(
        batchId: 'b1',
        count: 1,
      );
      rig.store.files.add(seeded.single.localPath);

      rig.bloc.add(const SyncStarted());
      await rig.settle();
      expect(rig.bloc.state.batches, hasLength(1));

      await Future<void>.delayed(const Duration(milliseconds: 1200));
      await rig.settle();

      // And the screen is then the empty *success* state, not an error.
      expect(rig.bloc.state.isEmpty, isTrue);
    });

    test('a retryable failure keeps the row, the file and the count', () async {
      final _Rig rig = await _Rig.create(
        hasLink: false,
        api: ScriptedUploadApi(
          (QueuedImage _, int _) => const UploadFailed(FailureCategory.offline),
        ),
      );
      addTearDown(rig.dispose);
      final List<QueuedImage> seeded = await rig.queue.seedQueuedBatch(
        batchId: 'b1',
        count: 1,
      );
      rig.store.files.add(seeded.single.localPath);

      rig.bloc.add(const SyncStarted());
      await rig.settle();

      expect(await rig.queue.countWithStatus(ImageStatus.pending), 1);
      expect(rig.store.files, contains(seeded.single.localPath));
      expect(rig.bloc.state.pendingCount, 1);
      final QueuedImage? row = await rig.queue.dao.imageById(seeded.single.id);
      expect(row!.attemptCount, 1);
    });

    test(
      'a cleanup failure never shows a synced item as pending again',
      () async {
        final _Rig rig = await _Rig.create();
        addTearDown(rig.dispose);
        final List<QueuedImage> seeded = await rig.queue.seedQueuedBatch(
          batchId: 'b1',
          count: 1,
        );
        rig.store.files.add(seeded.single.localPath);
        // Housekeeping, not delivery: a file that will not delete must never send
        // a confirmed upload back to the queue (`SYNC_ENGINE.md` §5).
        rig.store.failDelete = true;

        rig.bloc.add(const SyncStarted());
        await rig.settle();

        expect(await rig.queue.countWithStatus(ImageStatus.uploaded), 1);
        expect(await rig.queue.countWithStatus(ImageStatus.pending), 0);
        expect(rig.bloc.state.pendingCount, 0);
      },
    );
  });
}
