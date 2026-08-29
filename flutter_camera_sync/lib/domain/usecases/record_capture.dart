import '../entities/image_status.dart';
import '../entities/queued_image.dart';
import '../ports/capture_store.dart';
import '../ports/clock.dart';
import '../ports/id_generator.dart';
import '../ports/upload_queue.dart';

/// Makes one capture durable: bytes first, then the row that promises them.
///
/// It earns its place as a use case because it is the one operation that spans
/// two ports and has to stay consistent across both when either fails — the
/// architecture's stated bar for introducing one (`ARCHITECTURE.md` §9).
///
/// **Ordering rule (`DATA_MODEL.md` §6).** File, then row. A crash in between
/// leaves an orphan file: invisible, bounded, reclaimable. The other order
/// leaves a dangling row — a queue item that can never succeed and that the
/// user is told is still coming.
class RecordCapture {
  /// Creates the use case.
  const RecordCapture({
    required UploadQueue queue,
    required CaptureStore store,
    required IdGenerator ids,
    required Clock clock,
  }) : _queue = queue,
       _store = store,
       _ids = ids,
       _clock = clock;

  final UploadQueue _queue;
  final CaptureStore _store;
  final IdGenerator _ids;
  final Clock _clock;

  /// Persists the camera's temporary file at [sourcePath] into [batchId] and
  /// records it.
  ///
  /// Throws [CaptureStoreException] if the bytes could not be made durable, in
  /// which case **no row is written** (`FLT-ERR-005`, invariant I1). If the row
  /// cannot be written after the file was, the file just written is removed
  /// again before the error is rethrown, so the normal flow leaves no orphan.
  Future<QueuedImage> call({
    required String batchId,
    required String sourcePath,
    String extension = 'jpg',
  }) async {
    final String imageId = _ids.newId();

    // Bytes first. If this throws, nothing has been claimed to exist.
    final String durablePath = await _store.persist(
      batchId: batchId,
      imageId: imageId,
      sourcePath: sourcePath,
      extension: extension,
    );

    final QueuedImage image = QueuedImage(
      id: imageId,
      batchId: batchId,
      localPath: durablePath,
      capturedAt: _clock.nowUtc(),
      status: ImageStatus.draft,
    );

    try {
      await _queue.addCapture(image);
    } catch (_) {
      // Compensation. The destination is named after an id generated moments
      // ago, so this can only ever delete the file this call just wrote — never
      // a pre-existing capture.
      await _deleteQuietly(durablePath);
      rethrow;
    }

    return image;
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      await _store.delete(path);
    } catch (_) {
      // The insert already failed and is about to be reported. Losing the
      // compensation as well leaves a harmless orphan file, and masking the
      // real error with this one would be strictly worse.
    }
  }
}
