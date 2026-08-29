/// What went wrong while moving a capture into durable storage.
enum CaptureStoreFailure {
  /// The temporary file handed over by the camera is not there.
  sourceMissing('The captured image was no longer available to save.'),

  /// The durable copy could not be written — storage full, permissions, IO.
  writeFailed('The image could not be saved to this device.');

  const CaptureStoreFailure(this.message);

  /// A reason the user could be shown.
  final String message;
}

/// Raised when a capture could not be made durable.
class CaptureStoreException implements Exception {
  /// Creates the exception.
  const CaptureStoreException(this.failure, {this.cause});

  /// Which failure occurred.
  final CaptureStoreFailure failure;

  /// The underlying error, kept for logs.
  final Object? cause;

  @override
  String toString() => 'CaptureStoreException(${failure.name}): $cause';
}

/// App-owned durable storage for captured image bytes.
///
/// This is the boundary at which a capture becomes real (`FLT-CAM-015`). The
/// camera plugin writes to a temporary location it may reclaim; nothing is
/// queued until the bytes are somewhere the app controls.
///
/// The port speaks in `String` paths rather than `File` objects so the domain
/// layer stays free of `dart:io` as well as of plugins.
abstract interface class CaptureStore {
  /// Copies the file at [sourcePath] into durable storage for [imageId] inside
  /// [batchId], returning the durable absolute path.
  ///
  /// Throws [CaptureStoreException] and leaves nothing behind if it cannot
  /// complete — a partially written file must never be returned as durable,
  /// because a queue row would then point at a truncated image (`FLT-ERR-005`).
  Future<String> persist({
    required String batchId,
    required String imageId,
    required String sourcePath,
    String extension = 'jpg',
  });

  /// Whether a durable file is still present at [localPath].
  Future<bool> exists(String localPath);

  /// Deletes the durable file at [localPath].
  ///
  /// Returns whether a file was actually removed. Used both for compensation
  /// after a failed insert and for post-upload housekeeping.
  Future<bool> delete(String localPath);

  /// Removes the whole directory belonging to [batchId], if it exists.
  Future<void> deleteBatch(String batchId);
}
