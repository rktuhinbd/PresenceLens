import '../entities/capture_batch.dart';
import '../entities/queued_image.dart';
import '../ports/clock.dart';
import '../ports/id_generator.dart';
import '../ports/upload_queue.dart';
import 'record_capture.dart';

/// What one capture produced.
class CaptureResult {
  /// Creates a result.
  const CaptureResult({
    required this.image,
    required this.batch,
    required this.openedBatch,
  });

  /// The image, now durable and recorded.
  final QueuedImage image;

  /// The draft batch it joined, with its count already advanced.
  final CaptureBatch batch;

  /// Whether this capture is the one that opened the batch.
  final bool openedBatch;

  /// How many images the batch now holds.
  int get imageCount => batch.imageCount;
}

/// Puts one capture into the batch that is currently accepting them, opening
/// that batch if this is the first shot of a new one.
///
/// It earns a use case by the bar `ARCHITECTURE.md` §9 sets — orchestrating
/// more than one port — and by holding a rule that would otherwise end up
/// duplicated in whichever cubit pressed the shutter: **the batch boundary**.
/// `FLT-BAT-004` defines it as "a batch opens on the first capture after the
/// previous batch was enqueued, and closes when the user finishes it", and this
/// is where the first half of that sentence is executed.
///
/// It deliberately does **not** schedule anything. A `DRAFT` image is not
/// uploadable, so a twenty-photo session produces zero drain requests; the one
/// request happens when the user finishes the batch ([FinishBatch],
/// `ADR-F21`).
class CaptureIntoBatch {
  /// Creates the use case.
  const CaptureIntoBatch({
    required UploadQueue queue,
    required RecordCapture recordCapture,
    required IdGenerator ids,
    required Clock clock,
  }) : _queue = queue,
       _recordCapture = recordCapture,
       _ids = ids,
       _clock = clock;

  final UploadQueue _queue;
  final RecordCapture _recordCapture;
  final IdGenerator _ids;
  final Clock _clock;

  /// Records the camera's temporary file at [temporaryPath].
  ///
  /// Rethrows whatever [RecordCapture] refuses with. The ordering that matters
  /// is preserved by delegation rather than reimplemented: bytes durable first,
  /// row second, and the file removed again if the row cannot be written
  /// (`FLT-ERR-005`, invariant I1).
  ///
  /// If the batch had to be opened and the capture then fails, the empty draft
  /// batch survives. That is deliberate: the next shutter press joins it, and
  /// an empty draft is refused at enqueue anyway (`FLT-BAT-006`), so it can
  /// neither be uploaded nor shown as work. Deleting it would mean a
  /// compensating write on a failure path whose only symptom is a row nobody
  /// sees.
  Future<CaptureResult> call({
    required String temporaryPath,
    String extension = 'jpg',
  }) async {
    final CaptureBatch? existing = await _queue.openDraftBatch();
    final bool opened = existing == null;

    final CaptureBatch batch =
        existing ??
        await _queue.createDraftBatch(
          id: _ids.newId(),
          createdAt: _clock.nowUtc(),
        );

    final QueuedImage image = await _recordCapture(
      batchId: batch.id,
      sourcePath: temporaryPath,
      extension: extension,
    );

    // Re-read rather than incrementing the local copy: the count is
    // denormalised and advanced inside the insert's own transaction
    // (`DATA_MODEL.md` §5), so the database is the only thing that knows the
    // true value.
    final CaptureBatch? refreshed = await _queue.batchById(batch.id);

    return CaptureResult(
      image: image,
      batch: refreshed ?? batch.copyWith(imageCount: batch.imageCount + 1),
      openedBatch: opened,
    );
  }
}
