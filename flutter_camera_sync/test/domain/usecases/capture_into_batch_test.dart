// FLT-BAT-001, FLT-BAT-004, FLT-CAM-015, FLT-ERR-005, ADR-F21.
//
// The batch boundary, isolated from the camera. `camera_cubit_capture_test`
// proves the same rules reach the database through the shutter; this proves the
// rule itself, including the ordering guarantees it inherits from
// `RecordCapture` rather than reimplementing.

import 'package:flutter_test/flutter_test.dart';
import 'package:presence_lens_capture/domain/entities/batch_status.dart';
import 'package:presence_lens_capture/domain/entities/capture_batch.dart';
import 'package:presence_lens_capture/domain/entities/image_status.dart';
import 'package:presence_lens_capture/domain/entities/queued_image.dart';
import 'package:presence_lens_capture/domain/ports/capture_store.dart';
import 'package:presence_lens_capture/domain/usecases/capture_into_batch.dart';
import 'package:presence_lens_capture/domain/usecases/record_capture.dart';

import '../../support/fakes.dart';
import '../../support/queue_harness.dart';

void main() {
  late QueueHarness harness;
  late FakeCaptureStore store;
  late MutableClock clock;
  late SequentialIdGenerator ids;
  late CaptureIntoBatch captureIntoBatch;

  setUp(() async {
    harness = await QueueHarness.create();
    store = FakeCaptureStore();
    clock = MutableClock(DateTime.utc(2026, 8, 30, 9));
    ids = SequentialIdGenerator();
    captureIntoBatch = CaptureIntoBatch(
      queue: harness.dao,
      recordCapture: RecordCapture(
        queue: harness.dao,
        store: store,
        ids: ids,
        clock: clock,
      ),
      ids: ids,
      clock: clock,
    );
  });

  tearDown(() => harness.dispose());

  test('the first capture opens a batch and says so', () async {
    final CaptureResult result = await captureIntoBatch(
      temporaryPath: 'tmp/shot.jpg',
    );

    expect(result.openedBatch, isTrue);
    expect(result.imageCount, 1);
    expect(result.batch.status, BatchStatus.draft);
    expect(result.image.status, ImageStatus.draft);
  });

  test('the second capture joins the batch rather than opening one', () async {
    final CaptureResult first = await captureIntoBatch(
      temporaryPath: 'tmp/a.jpg',
    );
    final CaptureResult second = await captureIntoBatch(
      temporaryPath: 'tmp/b.jpg',
    );

    expect(second.openedBatch, isFalse);
    expect(second.batch.id, first.batch.id);
    expect(second.imageCount, 2);
    expect(await harness.dao.allBatches(), hasLength(1));
  });

  test(
    'the count comes from the database, not from a local increment',
    () async {
      // The count is denormalised and advanced inside the insert's transaction,
      // so the database is the only thing that knows the true value.
      for (int i = 0; i < 5; i++) {
        await captureIntoBatch(temporaryPath: 'tmp/$i.jpg');
      }

      final CaptureBatch batch = (await harness.dao.openDraftBatch())!;
      expect(batch.imageCount, 5);
      expect(await harness.dao.imagesInBatch(batch.id), hasLength(5));
    },
  );

  test('finishing a batch means the next capture opens a new one', () async {
    final CaptureResult first = await captureIntoBatch(
      temporaryPath: 'tmp/a.jpg',
    );
    await harness.dao.enqueueBatch(
      first.batch.id,
      queuedAt: DateTime.utc(2026, 8, 30, 10),
    );

    final CaptureResult second = await captureIntoBatch(
      temporaryPath: 'tmp/b.jpg',
    );

    expect(second.openedBatch, isTrue);
    expect(second.batch.id, isNot(first.batch.id));
    expect(await harness.dao.allBatches(), hasLength(2));
  });

  test('bytes are durable before the row that promises them exists', () async {
    final CaptureResult result = await captureIntoBatch(
      temporaryPath: 'tmp/a.jpg',
    );

    final QueuedImage stored = (await harness.dao.imagesInBatch(
      result.batch.id,
    )).single;
    expect(store.files, contains(stored.localPath));
    expect(stored.localPath, isNot('tmp/a.jpg'));
  });

  test('a storage failure writes no image row at all', () async {
    store.persistFailure = const CaptureStoreException(
      CaptureStoreFailure.writeFailed,
    );

    await expectLater(
      captureIntoBatch(temporaryPath: 'tmp/a.jpg'),
      throwsA(isA<CaptureStoreException>()),
    );

    final CaptureBatch? batch = await harness.dao.openDraftBatch();
    expect(batch, isNotNull);
    expect(await harness.dao.imagesInBatch(batch!.id), isEmpty);
    expect(batch.imageCount, 0);
  });

  test('the empty draft left behind is reused, never duplicated', () async {
    // Stated as a decision rather than compensated: the next shutter press
    // joins it, and an empty draft is refused at enqueue anyway, so it can
    // neither be uploaded nor shown as work.
    store.persistFailure = const CaptureStoreException(
      CaptureStoreFailure.writeFailed,
    );
    await expectLater(
      captureIntoBatch(temporaryPath: 'tmp/a.jpg'),
      throwsA(isA<CaptureStoreException>()),
    );
    final String batchId = (await harness.dao.openDraftBatch())!.id;

    store.persistFailure = null;
    final CaptureResult result = await captureIntoBatch(
      temporaryPath: 'tmp/b.jpg',
    );

    expect(result.batch.id, batchId);
    expect(result.openedBatch, isFalse);
    expect(await harness.dao.allBatches(), hasLength(1));
  });

  test('capture timestamps come from the injected clock', () async {
    clock.now = DateTime.utc(2026, 8, 30, 11, 30);

    final CaptureResult result = await captureIntoBatch(
      temporaryPath: 'tmp/a.jpg',
    );

    expect(result.image.capturedAt, DateTime.utc(2026, 8, 30, 11, 30));
  });

  test('each capture gets its own identifier', () async {
    final CaptureResult a = await captureIntoBatch(temporaryPath: 'tmp/a.jpg');
    final CaptureResult b = await captureIntoBatch(temporaryPath: 'tmp/b.jpg');

    expect(a.image.id, isNot(b.image.id));
    expect(a.image.localPath, isNot(b.image.localPath));
  });

  test('a custom extension reaches the durable path', () async {
    final CaptureResult result = await captureIntoBatch(
      temporaryPath: 'tmp/a.png',
      extension: 'png',
    );

    expect(result.image.localPath, endsWith('.png'));
  });
}
