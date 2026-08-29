// File-then-row ordering and its compensation (FLT-CAM-015, FLT-ERR-005,
// invariant I1).
//
// Run against the real filesystem and the real SQLite engine, because the
// behaviour under test *is* the interaction between the two.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:presence_lens_capture/data/storage/file_system_capture_store.dart';
import 'package:presence_lens_capture/domain/entities/capture_batch.dart';
import 'package:presence_lens_capture/domain/entities/image_status.dart';
import 'package:presence_lens_capture/domain/entities/queued_image.dart';
import 'package:presence_lens_capture/domain/ports/capture_store.dart';
import 'package:presence_lens_capture/domain/usecases/record_capture.dart';

import '../../support/fakes.dart';
import '../../support/queue_harness.dart';

void main() {
  late QueueHarness harness;
  late Directory capturesRoot;
  late FileSystemCaptureStore store;
  late SequentialIdGenerator ids;
  late MutableClock clock;
  late RecordCapture recordCapture;

  final DateTime now = DateTime.utc(2026, 8, 29, 11);

  setUp(() async {
    harness = await QueueHarness.create();
    capturesRoot = Directory(p.join(harness.directory.path, 'captures'));
    store = FileSystemCaptureStore(root: capturesRoot);
    ids = SequentialIdGenerator(prefix: 'img');
    clock = MutableClock(now);
    recordCapture = RecordCapture(
      queue: harness.dao,
      store: store,
      ids: ids,
      clock: clock,
    );
  });

  tearDown(() async {
    await harness.dispose();
  });

  Future<File> tempCapture(String name) =>
      File(p.join(harness.directory.path, name)).writeAsString('bytes');

  test('persists the file, then records the row', () async {
    await harness.dao.createDraftBatch(id: 'b1', createdAt: now);
    final File source = await tempCapture('shot.jpg');

    final QueuedImage recorded = await recordCapture(
      batchId: 'b1',
      sourcePath: source.path,
    );

    expect(recorded.id, 'img-0');
    expect(recorded.status, ImageStatus.draft);
    expect(recorded.capturedAt, now);
    expect(File(recorded.localPath).existsSync(), isTrue);

    final QueuedImage stored = (await harness.dao.imageById('img-0'))!;
    expect(stored.localPath, recorded.localPath);
    expect((await harness.dao.batchById('b1'))!.imageCount, 1);
  });

  test('the image id is also the file name and the idempotency key', () async {
    await harness.dao.createDraftBatch(id: 'b1', createdAt: now);
    final File source = await tempCapture('shot.jpg');

    final QueuedImage recorded = await recordCapture(
      batchId: 'b1',
      sourcePath: source.path,
    );

    expect(p.basenameWithoutExtension(recorded.localPath), recorded.id);
  });

  test('several captures join the same batch', () async {
    await harness.dao.createDraftBatch(id: 'b1', createdAt: now);
    for (int i = 0; i < 3; i++) {
      clock.advance(const Duration(seconds: 5));
      await recordCapture(
        batchId: 'b1',
        sourcePath: (await tempCapture('shot-$i.jpg')).path,
      );
    }

    expect(await harness.dao.imagesInBatch('b1'), hasLength(3));
    expect((await harness.dao.batchById('b1'))!.imageCount, 3);
  });

  test('a storage failure creates no row at all (I1)', () async {
    await harness.dao.createDraftBatch(id: 'b1', createdAt: now);

    await expectLater(
      recordCapture(
        batchId: 'b1',
        sourcePath: p.join(harness.directory.path, 'never-existed.jpg'),
      ),
      throwsA(isA<CaptureStoreException>()),
    );

    expect(
      await harness.dao.imagesInBatch('b1'),
      isEmpty,
      reason: 'no queue row may promise a file that was never written',
    );
    expect((await harness.dao.batchById('b1'))!.imageCount, 0);
  });

  test('a row failure removes the file it just wrote', () async {
    // The compensation path. The batch does not exist, so the insert violates
    // the foreign key — a real database failure, not a simulated one.
    final File source = await tempCapture('shot.jpg');

    await expectLater(
      recordCapture(batchId: 'no-such-batch', sourcePath: source.path),
      throwsA(isA<Object>()),
    );

    final String orphanPath = store.pathFor(
      batchId: 'no-such-batch',
      imageId: 'img-0',
    );
    expect(
      File(orphanPath).existsSync(),
      isFalse,
      reason: 'the normal flow must not leave an orphan behind',
    );
    expect(await harness.dao.imageById('img-0'), isNull);
  });

  test('compensation touches only the file this capture wrote', () async {
    await harness.dao.createDraftBatch(id: 'b1', createdAt: now);

    // An earlier, successful capture in the same directory.
    final QueuedImage survivor = await recordCapture(
      batchId: 'b1',
      sourcePath: (await tempCapture('first.jpg')).path,
    );

    // A second capture whose row cannot be written.
    await expectLater(
      recordCapture(
        batchId: 'no-such-batch',
        sourcePath: (await tempCapture('second.jpg')).path,
      ),
      throwsA(isA<Object>()),
    );

    expect(
      File(survivor.localPath).existsSync(),
      isTrue,
      reason:
          'compensation is scoped to a freshly generated id, so it can '
          'never reach an existing capture',
    );
  });

  test(
    'finishing the batch afterwards moves every capture to pending',
    () async {
      await harness.dao.createDraftBatch(id: 'b1', createdAt: now);
      await recordCapture(
        batchId: 'b1',
        sourcePath: (await tempCapture('a.jpg')).path,
      );
      clock.advance(const Duration(seconds: 1));
      await recordCapture(
        batchId: 'b1',
        sourcePath: (await tempCapture('b.jpg')).path,
      );

      final CaptureBatch queued = await harness.dao.enqueueBatch(
        'b1',
        queuedAt: clock.nowUtc(),
      );

      expect(queued.imageCount, 2);
      for (final QueuedImage image in await harness.dao.imagesInBatch('b1')) {
        expect(image.status, ImageStatus.pending);
        expect(File(image.localPath).existsSync(), isTrue);
      }
    },
  );
}
