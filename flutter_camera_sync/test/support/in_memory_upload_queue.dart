import 'dart:async';

import 'package:presence_lens_capture/domain/entities/batch_status.dart';
import 'package:presence_lens_capture/domain/entities/capture_batch.dart';
import 'package:presence_lens_capture/domain/entities/failure_category.dart';
import 'package:presence_lens_capture/domain/entities/image_status.dart';
import 'package:presence_lens_capture/domain/entities/queued_image.dart';
import 'package:presence_lens_capture/domain/ports/upload_queue.dart';

/// The durable queue, in memory, for the `WIDGET` tier only.
///
/// **Why this exists, and what it must not be mistaken for.** `testWidgets` runs
/// its body inside a fake-async zone, so the real `sqflite_common_ffi` engine —
/// which does genuine file I/O — never completes a future there. A widget test
/// therefore cannot drive the real DAO, and pretending otherwise would simply
/// hang.
///
/// So the tiers are split rather than blurred: **widget tests use this**, and the
/// persistence rules themselves are proven where they can be proven honestly —
/// against real SQLite, in the `DATA` and integration tiers, which run as plain
/// `test()` cases (`TEST_STRATEGY.md` §2, §6).
///
/// It implements the same observable contract the screens depend on: one draft
/// batch at a time, a count advanced with the insert, enqueue moving a whole
/// batch in one step, and a change announcement after every mutation. Anything a
/// widget asserts about the queue is asserted against those rules, not against a
/// stub that answers whatever the test wanted.
class InMemoryUploadQueue implements UploadQueue {
  final Map<String, CaptureBatch> _batches = <String, CaptureBatch>{};
  final Map<String, QueuedImage> _images = <String, QueuedImage>{};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// When true, every read throws — the "a failed query is not an empty queue"
  /// path.
  bool failReads = false;

  /// When true, [enqueueBatch] throws — the "the durable transaction itself was
  /// refused" path, which must leave the draft intact.
  bool failEnqueue = false;

  @override
  Stream<void> get changes => _changes.stream;

  void _notify() {
    if (!_changes.isClosed) {
      _changes.add(null);
    }
  }

  void _guardReads() {
    if (failReads) {
      throw StateError('database unavailable');
    }
  }

  @override
  Future<CaptureBatch?> openDraftBatch() async {
    _guardReads();
    for (final CaptureBatch batch in _sortedBatches()) {
      if (batch.status == BatchStatus.draft) {
        return batch;
      }
    }
    return null;
  }

  @override
  Future<CaptureBatch> createDraftBatch({
    required String id,
    required DateTime createdAt,
  }) async {
    if (await openDraftBatch() != null) {
      throw StateError('a draft batch is already open');
    }
    final CaptureBatch batch = CaptureBatch(
      id: id,
      createdAt: createdAt,
      status: BatchStatus.draft,
    );
    _batches[id] = batch;
    _notify();
    return batch;
  }

  @override
  Future<void> addCapture(QueuedImage image) async {
    final CaptureBatch? batch = _batches[image.batchId];
    if (batch == null) {
      throw StateError('no such batch ${image.batchId}');
    }
    _images[image.id] = image;
    // Advanced with the insert, exactly as the DAO does inside its transaction
    // (invariant I9).
    _batches[batch.id] = batch.copyWith(imageCount: batch.imageCount + 1);
    _notify();
  }

  @override
  Future<CaptureBatch> enqueueBatch(
    String batchId, {
    required DateTime queuedAt,
  }) async {
    if (failEnqueue) {
      throw StateError('transaction refused');
    }
    final CaptureBatch? batch = _batches[batchId];
    if (batch == null || batch.status != BatchStatus.draft) {
      throw StateError('batch $batchId is not an open draft');
    }
    if (batch.imageCount == 0) {
      throw StateError('an empty batch cannot be enqueued');
    }
    for (final QueuedImage image in _imagesOf(batchId)) {
      if (image.status == ImageStatus.draft) {
        _images[image.id] = image.copyWith(status: ImageStatus.pending);
      }
    }
    final CaptureBatch queued = batch.copyWith(
      status: BatchStatus.queued,
      queuedAt: queuedAt,
    );
    _batches[batchId] = queued;
    _notify();
    return queued;
  }

  @override
  Future<QueuedImage?> claimNext({
    required DateTime now,
    required DateTime leaseCutoff,
    Set<String> skip = const <String>{},
  }) async {
    final List<QueuedImage> eligible =
        _images.values.where((QueuedImage i) {
          if (skip.contains(i.id)) {
            return false;
          }
          if (i.status == ImageStatus.pending) {
            return true;
          }
          return i.status == ImageStatus.uploading &&
              i.claimedAt != null &&
              i.claimedAt!.isBefore(leaseCutoff);
        }).toList()..sort((QueuedImage a, QueuedImage b) {
          final int byTime = a.capturedAt.compareTo(b.capturedAt);
          return byTime != 0 ? byTime : a.id.compareTo(b.id);
        });

    if (eligible.isEmpty) {
      return null;
    }
    final QueuedImage claimed = eligible.first.copyWith(
      status: ImageStatus.uploading,
      claimedAt: now,
    );
    _images[claimed.id] = claimed;
    _notify();
    return claimed;
  }

  @override
  Future<bool> recordSuccess(String imageId, {required DateTime now}) async {
    final QueuedImage? image = _images[imageId];
    if (image == null || image.status == ImageStatus.uploaded) {
      return false;
    }
    _images[imageId] = image.copyWith(
      status: ImageStatus.uploaded,
      lastAttemptAt: now,
      clearClaimedAt: true,
    );
    final CaptureBatch? batch = _batches[image.batchId];
    if (batch != null &&
        _imagesOf(batch.id).every((QueuedImage i) => !i.status.isOutstanding)) {
      _batches[batch.id] = batch.copyWith(status: BatchStatus.completed);
    }
    _notify();
    return true;
  }

  @override
  Future<bool> recordRetryableFailure(
    String imageId, {
    required FailureCategory category,
    required DateTime now,
  }) async {
    final QueuedImage? image = _images[imageId];
    if (image == null) {
      return false;
    }
    // Neither the row nor the file is otherwise touched — the transition that
    // makes `FLT-SYNC-003` true.
    _images[imageId] = image.copyWith(
      status: ImageStatus.pending,
      attemptCount: image.attemptCount + 1,
      lastAttemptAt: now,
      lastFailure: category,
      clearClaimedAt: true,
    );
    _notify();
    return true;
  }

  @override
  Future<bool> recordPermanentFailure(
    String imageId, {
    required FailureCategory category,
    required DateTime now,
  }) async {
    final QueuedImage? image = _images[imageId];
    if (image == null) {
      return false;
    }
    _images[imageId] = image.copyWith(
      status: ImageStatus.failedPermanent,
      attemptCount: image.attemptCount + 1,
      lastAttemptAt: now,
      lastFailure: category,
      clearClaimedAt: true,
    );
    _notify();
    return true;
  }

  @override
  Future<QueuedImage?> imageById(String id) async {
    _guardReads();
    return _images[id];
  }

  @override
  Future<CaptureBatch?> batchById(String id) async {
    _guardReads();
    return _batches[id];
  }

  @override
  Future<List<CaptureBatch>> allBatches() async {
    _guardReads();
    return _sortedBatches().reversed.toList();
  }

  @override
  Future<List<QueuedImage>> imagesInBatch(String batchId) async {
    _guardReads();
    return _imagesOf(batchId);
  }

  @override
  Future<int> outstandingCount() async {
    _guardReads();
    return _images.values
        .where((QueuedImage i) => i.status.isOutstanding)
        .length;
  }

  @override
  Future<void> deleteBatch(String batchId) async {
    _batches.remove(batchId);
    _images.removeWhere((_, QueuedImage i) => i.batchId == batchId);
    _notify();
  }

  /// How many images currently hold [status]. For assertions.
  int countWithStatus(ImageStatus status) =>
      _images.values.where((QueuedImage i) => i.status == status).length;

  /// Every image, for assertions.
  List<QueuedImage> get images => _images.values.toList();

  /// Closes the change stream.
  Future<void> close() => _changes.close();

  List<CaptureBatch> _sortedBatches() => _batches.values.toList()
    ..sort(
      (CaptureBatch a, CaptureBatch b) => a.createdAt.compareTo(b.createdAt),
    );

  List<QueuedImage> _imagesOf(String batchId) =>
      _images.values.where((QueuedImage i) => i.batchId == batchId).toList()
        ..sort(
          (QueuedImage a, QueuedImage b) =>
              a.capturedAt.compareTo(b.capturedAt),
        );
}
