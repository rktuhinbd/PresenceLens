import '../entities/queued_image.dart';
import '../entities/upload_outcome.dart';

/// The network seam.
///
/// No API is supplied by the assessment (p3 Note), so this interface is real
/// and its only implementation is a deterministic mock (`ADR-F06`). A genuine
/// HTTP client drops in here without any other file changing.
abstract interface class UploadApi {
  /// Attempts to upload [image], returning the outcome rather than throwing.
  ///
  /// Implementations should classify their own failures into an
  /// [UploadFailed]; an exception escaping this call is treated by the
  /// processor as an unclassified — and therefore retryable — fault.
  Future<UploadOutcome> upload(QueuedImage image);
}
