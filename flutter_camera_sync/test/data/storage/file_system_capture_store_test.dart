// Durable capture storage (FLT-CAM-015, FLT-ERR-005, FLT-ERR-007, I1).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:presence_lens_capture/data/storage/file_system_capture_store.dart';
import 'package:presence_lens_capture/domain/ports/capture_store.dart';

void main() {
  late Directory tempRoot;
  late Directory capturesRoot;
  late FileSystemCaptureStore store;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('presencelens_store_');
    capturesRoot = Directory(p.join(tempRoot.path, 'captures'));
    store = FileSystemCaptureStore(root: capturesRoot);
  });

  tearDown(() async {
    if (tempRoot.existsSync()) {
      await tempRoot.delete(recursive: true);
    }
  });

  Future<File> writeTempCapture(String name, {String bytes = 'jpeg-bytes'}) {
    final File file = File(p.join(tempRoot.path, name));
    return file.writeAsString(bytes);
  }

  group('persisting a capture', () {
    test('returns a deterministic path under the batch directory', () async {
      final File source = await writeTempCapture('shot.jpg');

      final String durable = await store.persist(
        batchId: 'batch-1',
        imageId: 'image-1',
        sourcePath: source.path,
      );

      expect(
        durable,
        p.join(capturesRoot.path, 'batch-1', 'image-1.jpg'),
        reason: 'a reviewer must be able to find the file without guessing',
      );
      expect(durable, store.pathFor(batchId: 'batch-1', imageId: 'image-1'));
    });

    test('creates the batch directory when it does not exist', () async {
      expect(capturesRoot.existsSync(), isFalse);
      final File source = await writeTempCapture('shot.jpg');

      final String durable = await store.persist(
        batchId: 'batch-1',
        imageId: 'image-1',
        sourcePath: source.path,
      );

      expect(File(durable).existsSync(), isTrue);
    });

    test('copies the bytes intact', () async {
      final File source = await writeTempCapture(
        'shot.jpg',
        bytes: 'the actual photo',
      );

      final String durable = await store.persist(
        batchId: 'b',
        imageId: 'i',
        sourcePath: source.path,
      );

      expect(await File(durable).readAsString(), 'the actual photo');
    });

    test('releases the plugin temporary file afterwards', () async {
      final File source = await writeTempCapture('shot.jpg');

      await store.persist(batchId: 'b', imageId: 'i', sourcePath: source.path);

      expect(source.existsSync(), isFalse);
    });

    test('leaves no .part file behind on success', () async {
      // The copy lands on a temporary name and is renamed into place, so the
      // durable path is either absent or complete — never half-written.
      final File source = await writeTempCapture('shot.jpg');

      final String durable = await store.persist(
        batchId: 'b',
        imageId: 'i',
        sourcePath: source.path,
      );

      expect(
        File('$durable${FileSystemCaptureStore.partialSuffix}').existsSync(),
        isFalse,
      );
    });

    test('stores separate batches in separate directories', () async {
      final File first = await writeTempCapture('a.jpg');
      final File second = await writeTempCapture('b.jpg');

      final String one = await store.persist(
        batchId: 'batch-1',
        imageId: 'i',
        sourcePath: first.path,
      );
      final String two = await store.persist(
        batchId: 'batch-2',
        imageId: 'i',
        sourcePath: second.path,
      );

      expect(p.dirname(one), isNot(p.dirname(two)));
      expect(File(one).existsSync(), isTrue);
      expect(File(two).existsSync(), isTrue);
    });

    test('honours a non-default extension', () async {
      final File source = await writeTempCapture('shot.png');

      final String durable = await store.persist(
        batchId: 'b',
        imageId: 'i',
        sourcePath: source.path,
        extension: 'png',
      );

      expect(p.extension(durable), '.png');
    });
  });

  group('failure paths', () {
    test('a missing source is reported, and writes nothing', () async {
      await expectLater(
        store.persist(
          batchId: 'b',
          imageId: 'i',
          sourcePath: p.join(tempRoot.path, 'never-existed.jpg'),
        ),
        throwsA(
          isA<CaptureStoreException>().having(
            (CaptureStoreException e) => e.failure,
            'failure',
            CaptureStoreFailure.sourceMissing,
          ),
        ),
      );

      expect(
        File(store.pathFor(batchId: 'b', imageId: 'i')).existsSync(),
        isFalse,
        reason: 'nothing may claim to be durable after a failed capture',
      );
    });

    test('an unwritable destination is reported as a write failure', () async {
      final File source = await writeTempCapture('shot.jpg');

      // A file where the batch directory needs to be: creating the directory
      // cannot succeed, which is the shape of a storage-full or permission
      // fault without needing to fill the disk.
      await capturesRoot.create(recursive: true);
      await File(p.join(capturesRoot.path, 'blocked')).writeAsString('x');

      await expectLater(
        store.persist(
          batchId: 'blocked',
          imageId: 'i',
          sourcePath: source.path,
        ),
        throwsA(
          isA<CaptureStoreException>().having(
            (CaptureStoreException e) => e.failure,
            'failure',
            CaptureStoreFailure.writeFailed,
          ),
        ),
      );
      expect(
        source.existsSync(),
        isTrue,
        reason: 'a failed persist must not consume the only copy',
      );
    });
  });

  group('existence and deletion', () {
    test('reports a persisted file as present', () async {
      final File source = await writeTempCapture('shot.jpg');
      final String durable = await store.persist(
        batchId: 'b',
        imageId: 'i',
        sourcePath: source.path,
      );

      expect(await store.exists(durable), isTrue);
    });

    test('reports an externally deleted file as missing', () async {
      // The `FLT-ERR-007` scenario: the row survives, the bytes do not.
      final File source = await writeTempCapture('shot.jpg');
      final String durable = await store.persist(
        batchId: 'b',
        imageId: 'i',
        sourcePath: source.path,
      );
      await File(durable).delete();

      expect(await store.exists(durable), isFalse);
    });

    test('deleting returns whether anything was removed', () async {
      final File source = await writeTempCapture('shot.jpg');
      final String durable = await store.persist(
        batchId: 'b',
        imageId: 'i',
        sourcePath: source.path,
      );

      expect(await store.delete(durable), isTrue);
      expect(File(durable).existsSync(), isFalse);
      expect(
        await store.delete(durable),
        isFalse,
        reason: 'deleting twice is harmless, not an error',
      );
    });

    test('removing a batch removes its directory and contents', () async {
      final File source = await writeTempCapture('shot.jpg');
      await store.persist(
        batchId: 'batch-1',
        imageId: 'i',
        sourcePath: source.path,
      );

      await store.deleteBatch('batch-1');

      expect(
        Directory(p.join(capturesRoot.path, 'batch-1')).existsSync(),
        isFalse,
      );
    });

    test('removing a batch that was never written is harmless', () async {
      await expectLater(store.deleteBatch('ghost'), completes);
    });
  });
}
