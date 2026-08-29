import '../entities/capture_batch.dart';
import '../entities/failure_category.dart';
import '../entities/queued_image.dart';

/// The durable queue: batches, images, and every state change either can make.
///
/// Every method that changes state is written so that repeating it is harmless
/// and so that the *database* decides who wins a race, because the UI isolate
/// and the WorkManager isolate hold separate connections and no Dart lock spans
/// them (`ADR-F04`).
abstract interface class UploadQueue {
  /// The batch currently accepting captures, or `null` if none is open.
  Future<CaptureBatch?> openDraftBatch();

  /// Creates and returns a new draft batch.
  ///
  /// Refuses while another draft is open. That rule is an **application-level
  /// capture-workflow policy**, not a database constraint: there is exactly one
  /// creator of draft batches — the foreground capture flow — and the
  /// background worker never creates one. A `UNIQUE` index would be database
  /// complexity bought for a race that no second writer exists to cause
  /// (`ADR-F20`).
  ///
  /// The check is a read followed by an insert and is therefore *not* atomic
  /// across connections. That is stated rather than papered over: it is safe
  /// only because of the single-writer assumption above.
  Future<CaptureBatch> createDraftBatch({
    required String id,
    required DateTime createdAt,
  });

  /// Inserts a captured image and advances its batch's image count, in one
  /// transaction (invariant I9).
  ///
  /// The caller must already have persisted the bytes: this row is a promise
  /// that a file exists (invariant I1).
  Future<void> addCapture(QueuedImage image);

  /// Finishes a batch: the batch becomes queued and **all** of its draft images
  /// become pending, in a single transaction (invariant I2, `FLT-BAT-005`).
  ///
  /// This is a local, durable act. It requires no network and makes no upload
  /// (`ADR-F14`). Throws [StateError] if the batch is not a non-empty draft.
  Future<CaptureBatch> enqueueBatch(
    String batchId, {
    required DateTime queuedAt,
  });

  /// Atomically takes ownership of the next item eligible for upload.
  ///
  /// Eligible means pending, or claimed before [leaseCutoff] and therefore
  /// abandoned. Returns the claimed row, or `null` when there is nothing to do.
  /// Exactly one of two concurrent callers can succeed on the same row
  /// (`FLT-SYNC-008`).
  ///
  /// [skip] excludes ids the caller has already attempted. A retryable failure
  /// returns an item to `PENDING`, which makes it immediately claimable again;
  /// without this the same drain pass would pick it straight back up and retry
  /// it in a tight loop, which is the app taking over the backoff that belongs
  /// to the OS (`RS-04`).
  Future<QueuedImage?> claimNext({
    required DateTime now,
    required DateTime leaseCutoff,
    Set<String> skip,
  });

  /// Records a confirmed upload, and completes the batch if it was the last
  /// outstanding image.
  ///
  /// Returns whether this call was the one that made the change; a repeat
  /// returns `false` and alters nothing (invariant I7).
  Future<bool> recordSuccess(String imageId, {required DateTime now});

  /// Returns a failed item to the queue, incrementing its attempt count.
  ///
  /// Neither the row nor the file is touched otherwise (invariant I6) — this is
  /// the transition that makes `FLT-SYNC-003` true.
  Future<bool> recordRetryableFailure(
    String imageId, {
    required FailureCategory category,
    required DateTime now,
  });

  /// Removes an unprocessable item from the work set (invariant I10).
  Future<bool> recordPermanentFailure(
    String imageId, {
    required FailureCategory category,
    required DateTime now,
  });

  /// The image with [id], or `null`.
  Future<QueuedImage?> imageById(String id);

  /// The batch with [id], or `null`.
  Future<CaptureBatch?> batchById(String id);

  /// Every batch, newest first.
  Future<List<CaptureBatch>> allBatches();

  /// The images in [batchId], in capture order.
  Future<List<QueuedImage>> imagesInBatch(String batchId);

  /// How many images are still outstanding across the whole queue.
  ///
  /// Drives the background worker's result: while this is above zero there is
  /// work left and the OS should be asked to come back.
  Future<int> outstandingCount();

  /// Deletes a batch and its rows. The caller removes the files.
  Future<void> deleteBatch(String batchId);

  /// Emits after every change to the queue, so a UI can re-read it.
  Stream<void> get changes;
}
