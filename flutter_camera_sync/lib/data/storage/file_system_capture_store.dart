import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/ports/capture_store.dart';

/// Durable, app-owned storage for captured image bytes.
///
/// Layout, per `DATA_MODEL.md` §1:
///
/// ```text
/// <root>/<batchId>/<imageId>.<extension>
/// ```
///
/// Grouping by batch makes discarding a batch one directory removal and an
/// orphan scan a directory listing, rather than a full-table join.
///
/// The root is injected rather than resolved here. `path_provider` is a plugin,
/// and taking it as a dependency would make every test of this class need a
/// Flutter binding — so the composition root resolves the directory once and
/// this class does file work.
class FileSystemCaptureStore implements CaptureStore {
  /// Creates a store rooted at [root].
  const FileSystemCaptureStore({required Directory root}) : _root = root;

  /// Suffix of the temporary file used while a copy is in progress.
  static const String partialSuffix = '.part';

  final Directory _root;

  /// The directory this store owns.
  Directory get root => _root;

  /// The durable path an image would occupy, whether or not it exists yet.
  ///
  /// Deterministic, so a test can assert the location and a reviewer can find
  /// the file on a device without guessing.
  String pathFor({
    required String batchId,
    required String imageId,
    String extension = 'jpg',
  }) => p.join(_root.path, batchId, '$imageId.$extension');

  @override
  Future<String> persist({
    required String batchId,
    required String imageId,
    required String sourcePath,
    String extension = 'jpg',
  }) async {
    final File source = File(sourcePath);
    // `existsSync` rather than `exists`: the async variants of the stat-like
    // `dart:io` calls hop to a helper isolate and are slower than the blocking
    // ones they wrap, for a syscall measured in microseconds
    // (`avoid_slow_async_io`). The method stays async because the port is.
    if (!source.existsSync()) {
      throw const CaptureStoreException(CaptureStoreFailure.sourceMissing);
    }

    final String destination = pathFor(
      batchId: batchId,
      imageId: imageId,
      extension: extension,
    );
    final File partial = File('$destination$partialSuffix');

    try {
      await Directory(p.dirname(destination)).create(recursive: true);

      // Copy to a sibling temporary name, then rename into place. The rename is
      // atomic within a directory, so the durable path either does not exist or
      // holds a complete file — a half-written image can never be handed back
      // as durable and then have a queue row written against it.
      await source.copy(partial.path);
      await partial.rename(destination);
    } on FileSystemException catch (error) {
      await _deleteQuietly(partial);
      throw CaptureStoreException(
        CaptureStoreFailure.writeFailed,
        cause: error,
      );
    }

    // The plugin's temporary file has served its purpose. Failing to remove it
    // costs cache space the OS reclaims; it must not fail the capture, which
    // has already succeeded.
    await _deleteQuietly(source);

    return destination;
  }

  @override
  Future<bool> exists(String localPath) async => File(localPath).existsSync();

  @override
  Future<bool> delete(String localPath) async {
    final File file = File(localPath);
    if (!file.existsSync()) {
      return false;
    }
    await file.delete();
    return true;
  }

  @override
  Future<void> deleteBatch(String batchId) async {
    final Directory directory = Directory(p.join(_root.path, batchId));
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (file.existsSync()) {
        await file.delete();
      }
    } on FileSystemException {
      // Best effort by definition; the caller's outcome does not depend on it.
    }
  }
}
