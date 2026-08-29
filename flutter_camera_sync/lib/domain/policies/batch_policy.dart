import '../entities/batch_status.dart';
import '../entities/capture_batch.dart';

/// Why a batch may not be finished.
enum EnqueueRefusal {
  /// The batch is not a draft — it was already finished, or is complete.
  notADraft('This batch has already been finished.'),

  /// The batch holds no captures (`FLT-BAT-006`).
  noImages('Capture at least one image before finishing the batch.');

  const EnqueueRefusal(this.message);

  /// A reason the user could be shown.
  final String message;
}

/// The rules that govern a batch's boundaries and its aggregate state.
///
/// The assessment never defines "batch" (root `AMB-10`), so the definition is
/// made explicit here and tested, rather than being left to emerge from
/// whatever the UI happens to do (`FLT-BAT-004`).
class BatchPolicy {
  /// Creates the policy. It carries no state.
  const BatchPolicy();

  static const Map<BatchStatus, Set<BatchStatus>> _legal =
      <BatchStatus, Set<BatchStatus>>{
        BatchStatus.draft: <BatchStatus>{BatchStatus.queued},
        BatchStatus.queued: <BatchStatus>{BatchStatus.completed},
        BatchStatus.completed: <BatchStatus>{},
      };

  /// Whether moving a batch [from] one status [to] another is allowed.
  bool isLegalTransition(BatchStatus from, BatchStatus to) =>
      _legal[from]?.contains(to) ?? false;

  /// Whether a new batch may be opened.
  ///
  /// At most one draft exists at a time; the next capture after a batch is
  /// finished opens the next one.
  ///
  /// This is a **capture-workflow rule**, enforced where batches are created —
  /// which is the foreground, and only the foreground. It is deliberately not a
  /// database constraint (`ADR-F20`).
  bool canOpenBatch({required bool hasOpenDraft}) => !hasOpenDraft;

  /// The reason [batch] may not be finished, or `null` if it may.
  EnqueueRefusal? refuseEnqueue(CaptureBatch batch) {
    if (batch.status != BatchStatus.draft) {
      return EnqueueRefusal.notADraft;
    }
    if (batch.imageCount <= 0) {
      return EnqueueRefusal.noImages;
    }
    return null;
  }

  /// Whether a batch holding [imageCount] images of which [uploadedCount] are
  /// confirmed uploaded is complete (invariant I8).
  ///
  /// An empty batch is never complete — otherwise a batch that had failed to
  /// receive any capture would present itself as a success. Nor is a batch
  /// holding a permanently failed item: that item was not delivered, and
  /// letting it pass as "completed" would be the UI telling the user something
  /// untrue.
  bool isComplete({required int imageCount, required int uploadedCount}) =>
      imageCount > 0 && uploadedCount == imageCount;
}
