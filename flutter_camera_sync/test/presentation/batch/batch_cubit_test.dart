// `BLOC` tier — the open batch, over real SQLite.
//
// The claim worth defending here is that the count on screen is **read back**
// rather than tallied: that is what makes it survive process death, and what
// stops the camera's number and the batch control's number drifting apart.

import 'package:flutter_test/flutter_test.dart';
import 'package:presence_lens_capture/domain/entities/batch_status.dart';
import 'package:presence_lens_capture/domain/entities/capture_batch.dart';
import 'package:presence_lens_capture/domain/entities/image_status.dart';
import 'package:presence_lens_capture/domain/entities/queued_image.dart';
import 'package:presence_lens_capture/domain/ports/sync_scheduler.dart';
import 'package:presence_lens_capture/domain/usecases/capture_into_batch.dart';
import 'package:presence_lens_capture/domain/usecases/finish_batch.dart';
import 'package:presence_lens_capture/domain/usecases/record_capture.dart';
import 'package:presence_lens_capture/presentation/batch/batch_cubit.dart';
import 'package:presence_lens_capture/presentation/batch/batch_state.dart';

import '../../support/fakes.dart';
import '../../support/in_memory_upload_queue.dart';
import '../../support/queue_harness.dart';

class _Rig {
  _Rig(this.queue, this.cubit, this.scheduler, this.capture);

  static Future<_Rig> create({
    SchedulingOutcome drainOutcome = SchedulingOutcome.requested,
  }) async {
    final QueueHarness queue = await QueueHarness.create();
    final FakeCaptureStore store = FakeCaptureStore();
    final MutableClock clock = MutableClock(DateTime.utc(2026, 8, 30, 9));
    final SequentialIdGenerator ids = SequentialIdGenerator();
    final RecordingScheduler scheduler = RecordingScheduler(
      drainOutcome: drainOutcome,
    );

    return _Rig(
      queue,
      BatchCubit(
        queue: queue.dao,
        finishBatch: FinishBatch(
          queue: queue.dao,
          scheduler: scheduler,
          clock: clock,
        ),
      ),
      scheduler,
      CaptureIntoBatch(
        queue: queue.dao,
        recordCapture: RecordCapture(
          queue: queue.dao,
          store: store,
          ids: ids,
          clock: clock,
        ),
        ids: ids,
        clock: clock,
      ),
    );
  }

  final QueueHarness queue;
  final BatchCubit cubit;
  final RecordingScheduler scheduler;
  final CaptureIntoBatch capture;

  Future<void> settle() async {
    for (int i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  Future<void> dispose() async {
    await cubit.close();
    await queue.dispose();
  }
}

void main() {
  test(
    'a draft left by a previous process is picked up with its count',
    () async {
      final _Rig rig = await _Rig.create();
      addTearDown(rig.dispose);
      // What a killed app leaves behind: an open batch with real rows in it.
      await rig.capture(temporaryPath: 'tmp/a.jpg');
      await rig.capture(temporaryPath: 'tmp/b.jpg');

      await rig.cubit.start();

      expect(rig.cubit.state.imageCount, 2);
      expect(rig.cubit.state.hasCaptures, isTrue);
      expect(rig.cubit.state.latestCapture, isNotNull);
    },
  );

  test(
    'repeated captures join one batch and the count follows the queue',
    () async {
      final _Rig rig = await _Rig.create();
      addTearDown(rig.dispose);
      await rig.cubit.start();

      await rig.capture(temporaryPath: 'tmp/a.jpg');
      await rig.capture(temporaryPath: 'tmp/b.jpg');
      await rig.capture(temporaryPath: 'tmp/c.jpg');
      await rig.settle();

      // One batch, three images — the boundary rule lives in `CaptureIntoBatch`
      // and is not restated here (`FLT-BAT-004`).
      final List<CaptureBatch> batches = await rig.queue.dao.allBatches();
      expect(batches, hasLength(1));
      expect(rig.cubit.state.imageCount, 3);
    },
  );

  test(
    'finishing queues every image in one step and opens no new batch',
    () async {
      final _Rig rig = await _Rig.create();
      addTearDown(rig.dispose);
      await rig.cubit.start();
      await rig.capture(temporaryPath: 'tmp/a.jpg');
      await rig.capture(temporaryPath: 'tmp/b.jpg');
      await rig.cubit.refresh();

      final String? id = await rig.cubit.finish();

      expect(id, isNotNull);
      expect(await rig.queue.countWithStatus(ImageStatus.pending), 2);
      expect(await rig.queue.countWithStatus(ImageStatus.draft), 0);
      expect(rig.cubit.state.draft, isNull);
      expect(rig.cubit.state.imageCount, 0);
      // The next shutter press opens the next batch; finishing does not
      // pre-create one.
      expect(await rig.queue.dao.openDraftBatch(), isNull);
    },
  );

  test('a refused schedule still leaves the batch durably queued', () async {
    final _Rig rig = await _Rig.create(
      drainOutcome: SchedulingOutcome.unavailable,
    );
    addTearDown(rig.dispose);
    await rig.cubit.start();
    await rig.capture(temporaryPath: 'tmp/a.jpg');
    await rig.cubit.refresh();

    final String? id = await rig.cubit.finish();

    // The ordering rule: the transaction commits before anything is scheduled,
    // so a lost wake-up costs a delay and never a photograph.
    expect(id, isNotNull);
    expect(rig.cubit.state.lastScheduling, SchedulingOutcome.unavailable);
    final CaptureBatch? batch = await rig.queue.dao.batchById(id!);
    expect(batch!.status, BatchStatus.queued);
    expect(await rig.queue.countWithStatus(ImageStatus.pending), 1);
  });

  test('an empty batch is refused, and says so without scheduling', () async {
    final _Rig rig = await _Rig.create();
    addTearDown(rig.dispose);
    await rig.cubit.start();

    final String? id = await rig.cubit.finish();

    expect(id, isNull);
    expect(rig.cubit.state.failure, BatchActionFailure.emptyBatch);
    expect(rig.scheduler.scheduleCount, 0);
  });

  test('two finishes in flight produce one queued batch', () async {
    final _Rig rig = await _Rig.create();
    addTearDown(rig.dispose);
    await rig.cubit.start();
    await rig.capture(temporaryPath: 'tmp/a.jpg');
    await rig.cubit.refresh();

    final List<String?> results = await Future.wait(<Future<String?>>[
      rig.cubit.finish(),
      rig.cubit.finish(),
    ]);

    // The duplicate is dropped rather than queued: `enqueueBatch` refuses a
    // batch that is no longer a draft, and surfacing that as an error would
    // report a failure for an action that succeeded.
    expect(results.where((String? id) => id != null), hasLength(1));
    expect(rig.scheduler.scheduleCount, 1);
    expect(await rig.queue.countWithStatus(ImageStatus.pending), 1);
  });

  test(
    'a refused transaction keeps the batch and never reports success',
    () async {
      // The one case the real engine will not produce on demand, so the fault is
      // injected at the port instead.
      final InMemoryUploadQueue queue = InMemoryUploadQueue();
      addTearDown(queue.close);
      final MutableClock clock = MutableClock(DateTime.utc(2026, 8, 30, 9));
      final RecordingScheduler scheduler = RecordingScheduler();
      final BatchCubit cubit = BatchCubit(
        queue: queue,
        finishBatch: FinishBatch(
          queue: queue,
          scheduler: scheduler,
          clock: clock,
        ),
      );
      addTearDown(cubit.close);

      await queue.createDraftBatch(id: 'b1', createdAt: clock.nowUtc());
      await queue.addCapture(
        QueuedImage(
          id: 'i1',
          batchId: 'b1',
          localPath: 'durable/b1/i1.jpg',
          capturedAt: clock.nowUtc(),
          status: ImageStatus.draft,
        ),
      );
      await cubit.start();
      queue.failEnqueue = true;

      final String? id = await cubit.finish();

      expect(id, isNull);
      expect(cubit.state.failure, BatchActionFailure.finishFailed);
      expect(cubit.state.isFinishing, isFalse);
      // Nothing was scheduled for work that does not exist, and the draft is
      // still there to try again with.
      expect(scheduler.scheduleCount, 0);
      expect(cubit.state.hasCaptures, isTrue);
    },
  );
}
