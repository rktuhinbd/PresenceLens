import '../entities/capture_batch.dart';
import '../ports/clock.dart';
import '../ports/sync_scheduler.dart';
import '../ports/upload_queue.dart';

/// The result of finishing a batch.
///
/// Carries the scheduling outcome alongside the batch so a caller can tell the
/// difference between "queued, and a drain was requested" and "queued, but the
/// platform would not take the request". Both are successes as far as the user's
/// photos are concerned; only the second needs asking again later.
class FinishBatchResult {
  /// Creates a result.
  const FinishBatchResult({required this.batch, required this.scheduling});

  /// The batch, now `QUEUED`.
  final CaptureBatch batch;

  /// What the platform said about the drain request.
  final SchedulingOutcome scheduling;

  /// Whether the images are durably queued.
  ///
  /// Always true if this object exists: the transaction committed before
  /// scheduling was even attempted.
  bool get isDurablyQueued => true;
}

/// Closes the open batch and asks for its images to be uploaded.
///
/// The second operation this app has that spans two ports, and it earns a use
/// case for the same reason [RecordCapture] does: the *ordering* between them is
/// the rule, and it has to live somewhere testable rather than in whichever
/// Cubit happens to call it.
///
/// **Ordering rule.** The durable transaction first, the scheduling request
/// second, and never the reverse:
///
/// * if the transaction fails, nothing is scheduled — there is no uploadable
///   work to schedule for;
/// * if scheduling fails, the batch stays `QUEUED` and the images stay
///   `PENDING`. A lost wake-up costs a delay; it must never cost a photo
///   (`SYNC_ENGINE.md` §8).
///
/// This is also the app's **only** entry-scheduling call site that is driven by
/// the user, and deliberately so. A capture is `DRAFT` until its batch is
/// finished, and a `DRAFT` image is not uploadable — so pressing the shutter
/// schedules nothing, and a twenty-photo session produces one drain request
/// rather than twenty (`ADR-F21`).
class FinishBatch {
  /// Creates the use case.
  const FinishBatch({
    required UploadQueue queue,
    required SyncScheduler scheduler,
    required Clock clock,
  }) : _queue = queue,
       _scheduler = scheduler,
       _clock = clock;

  final UploadQueue _queue;
  final SyncScheduler _scheduler;
  final Clock _clock;

  /// Finishes [batchId] and requests a drain.
  ///
  /// Rethrows whatever [UploadQueue.enqueueBatch] refuses with — an empty batch,
  /// an already-finished one — **without** having scheduled anything.
  Future<FinishBatchResult> call(String batchId) async {
    final CaptureBatch queued = await _queue.enqueueBatch(
      batchId,
      queuedAt: _clock.nowUtc(),
    );

    // Only now. Everything above this line is durable, and nothing below it can
    // undo any of it.
    final SchedulingOutcome scheduling = await _scheduler.scheduleDrain();

    return FinishBatchResult(batch: queued, scheduling: scheduling);
  }
}
