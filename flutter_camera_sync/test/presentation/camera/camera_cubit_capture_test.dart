// FLT-CAM-014, FLT-CAM-015, FLT-BAT-001, FLT-BAT-004, FLT-ERR-005, ADR-F21.
//
// The capture path runs against the **real** DAO over real SQLite, because the
// claims being made here are about durability, and a stubbed queue would prove
// nothing about the rules that actually ship.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:presence_lens_capture/domain/entities/batch_status.dart';
import 'package:presence_lens_capture/domain/entities/camera_device.dart';
import 'package:presence_lens_capture/domain/entities/camera_error.dart';
import 'package:presence_lens_capture/domain/entities/capture_batch.dart';
import 'package:presence_lens_capture/domain/entities/image_status.dart';
import 'package:presence_lens_capture/domain/entities/queued_image.dart';
import 'package:presence_lens_capture/domain/ports/capture_store.dart';
import 'package:presence_lens_capture/presentation/camera/camera_state.dart';

import '../../support/camera_harness.dart';
import '../../support/fake_camera.dart';

void main() {
  late CameraHarness harness;

  Future<void> readyCamera() async {
    harness = await CameraHarness.create(
      devices: <CameraDevice>[FakeCameraEngine.backCamera('0')],
    );
    await harness.cubit.acquire();
  }

  CameraReady ready() => harness.cubit.state as CameraReady;
  FakeCameraSession session() => harness.engine.sessions.last;

  tearDown(() => harness.dispose());

  group('a single capture', () {
    test('produces a durable file and a queue row', () async {
      await readyCamera();

      await harness.cubit.capture();

      final CaptureBatch batch = (await harness.dao.openDraftBatch())!;
      final List<QueuedImage> images = await harness.dao.imagesInBatch(
        batch.id,
      );
      expect(images, hasLength(1));
      expect(
        harness.store.files,
        contains(images.single.localPath),
        reason: 'the row may only exist because the bytes already do',
      );
      expect(ready().lastCaptureImageId, images.single.id);
    });

    test('the temporary path from the plugin is what gets persisted', () async {
      await readyCamera();

      await harness.cubit.capture();

      // The fake session hands back `tmp/<camera>-<n>.jpg`; the durable path
      // must be somewhere else entirely, because the plugin's directory is one
      // the OS may reclaim (`FLT-CAM-015`).
      final CaptureBatch batch = (await harness.dao.openDraftBatch())!;
      final QueuedImage image = (await harness.dao.imagesInBatch(
        batch.id,
      )).single;
      expect(image.localPath, isNot(startsWith('tmp/')));
      expect(image.localPath, startsWith('durable/'));
    });

    test('the capture lands as DRAFT, so it is not yet uploadable', () async {
      await readyCamera();

      await harness.cubit.capture();

      final CaptureBatch batch = (await harness.dao.openDraftBatch())!;
      expect(batch.status, BatchStatus.draft);
      final QueuedImage image = (await harness.dao.imagesInBatch(
        batch.id,
      )).single;
      expect(image.status, ImageStatus.draft);
    });

    test('NO drain is scheduled for a draft capture', () async {
      // Twenty photographs must produce zero drain requests; the single request
      // happens when the user finishes the batch (`ADR-F21`).
      await readyCamera();

      await harness.cubit.capture();
      await harness.cubit.capture();
      await harness.cubit.capture();

      expect(harness.scheduler.scheduleCount, 0);
      expect(harness.scheduler.continuationCount, 0);
    });

    test('the busy flag is set during, and cleared after', () async {
      await readyCamera();
      final Completer<void> shutter = Completer<void>();
      session().captureGate = shutter;

      final Future<void> capturing = harness.cubit.capture();
      expect(ready().isCapturing, isTrue);

      shutter.complete();
      await capturing;
      expect(ready().isCapturing, isFalse);
    });
  });

  group('the double-shutter guard (FLT-CAM-014)', () {
    test(
      'two simultaneous presses produce exactly ONE platform capture',
      () async {
        await readyCamera();
        final Completer<void> shutter = Completer<void>();
        session().captureGate = shutter;

        final Future<void> first = harness.cubit.capture();
        final Future<void> second = harness.cubit.capture();
        shutter.complete();
        await Future.wait(<Future<void>>[first, second]);

        expect(session().captureCount, 1);
      },
    );

    test('and exactly one image row', () async {
      await readyCamera();
      final Completer<void> shutter = Completer<void>();
      session().captureGate = shutter;

      final Future<void> first = harness.cubit.capture();
      final Future<void> second = harness.cubit.capture();
      shutter.complete();
      await Future.wait(<Future<void>>[first, second]);

      final CaptureBatch batch = (await harness.dao.openDraftBatch())!;
      expect(batch.imageCount, 1);
      expect(await harness.dao.imagesInBatch(batch.id), hasLength(1));
    });

    test('a five-way race still produces one capture', () async {
      await readyCamera();
      final Completer<void> shutter = Completer<void>();
      session().captureGate = shutter;

      final List<Future<void>> presses = <Future<void>>[
        for (int i = 0; i < 5; i++) harness.cubit.capture(),
      ];
      shutter.complete();
      await Future.wait(presses);

      expect(session().captureCount, 1);
    });

    test('the guard releases, so the next press works', () async {
      await readyCamera();

      await harness.cubit.capture();
      await harness.cubit.capture();

      expect(session().captureCount, 2);
      expect((await harness.dao.openDraftBatch())!.imageCount, 2);
    });
  });

  group('batch behaviour (FLT-BAT-001, FLT-BAT-004)', () {
    test('the first capture opens a draft batch', () async {
      await readyCamera();
      expect(await harness.dao.openDraftBatch(), isNull);

      await harness.cubit.capture();

      expect(await harness.dao.openDraftBatch(), isNotNull);
      expect(ready().batchImageCount, 1);
    });

    test('subsequent captures join the SAME batch', () async {
      await readyCamera();

      await harness.cubit.capture();
      final String batchId = (await harness.dao.openDraftBatch())!.id;
      await harness.cubit.capture();
      await harness.cubit.capture();

      final CaptureBatch batch = (await harness.dao.openDraftBatch())!;
      expect(batch.id, batchId);
      expect(batch.imageCount, 3);
      expect(ready().batchImageCount, 3);
    });

    test('a new batch opens after the previous one is finished', () async {
      // The other half of FLT-BAT-004, and the reason multiple batches work.
      await readyCamera();
      await harness.cubit.capture();
      final String first = (await harness.dao.openDraftBatch())!.id;
      await harness.dao.enqueueBatch(
        first,
        queuedAt: DateTime.utc(2026, 8, 30, 10),
      );
      expect(await harness.dao.openDraftBatch(), isNull);

      await harness.cubit.capture();

      final CaptureBatch second = (await harness.dao.openDraftBatch())!;
      expect(second.id, isNot(first));
      expect(second.imageCount, 1);
      expect(await harness.dao.allBatches(), hasLength(2));
    });

    test(
      'the count in the state matches the database, not a local tally',
      () async {
        await readyCamera();

        for (int i = 0; i < 4; i++) {
          await harness.cubit.capture();
        }

        final CaptureBatch batch = (await harness.dao.openDraftBatch())!;
        expect(ready().batchImageCount, batch.imageCount);
        expect(batch.imageCount, 4);
      },
    );
  });

  group('failure ordering (§27, FLT-ERR-005)', () {
    test('a failed photograph writes NO file and NO row', () async {
      await readyCamera();
      session().captureFailure = cameraFailure(CameraErrorKind.captureFailed);

      await harness.cubit.capture();

      expect(await harness.dao.openDraftBatch(), isNull);
      expect(harness.store.files, isEmpty);
    });

    test(
      'a failed photograph clears the busy flag and keeps the camera',
      () async {
        await readyCamera();
        session().captureFailure = cameraFailure(CameraErrorKind.captureFailed);

        await harness.cubit.capture();

        expect(harness.cubit.state, isA<CameraReady>());
        expect(ready().isCapturing, isFalse);
        expect(ready().lastOperationError?.kind, CameraErrorKind.captureFailed);
      },
    );

    test('the camera still works after a failed photograph', () async {
      await readyCamera();
      session().captureFailure = cameraFailure(CameraErrorKind.captureFailed);
      await harness.cubit.capture();

      session().captureFailure = null;
      await harness.cubit.capture();

      expect(ready().lastOperationError, isNull);
      expect((await harness.dao.openDraftBatch())!.imageCount, 1);
    });

    test('a storage failure aborts the capture and writes no row', () async {
      await readyCamera();
      harness.store.persistFailure = const CaptureStoreException(
        CaptureStoreFailure.writeFailed,
      );

      await harness.cubit.capture();

      final CaptureBatch? batch = await harness.dao.openDraftBatch();
      expect(batch, isNotNull, reason: 'the batch was opened before the write');
      expect(await harness.dao.imagesInBatch(batch!.id), isEmpty);
      expect(batch.imageCount, 0);
    });

    test('a storage failure is surfaced with its cause preserved', () async {
      await readyCamera();
      harness.store.persistFailure = const CaptureStoreException(
        CaptureStoreFailure.writeFailed,
      );

      await harness.cubit.capture();

      expect(ready().isCapturing, isFalse);
      expect(ready().lastOperationError?.kind, CameraErrorKind.captureFailed);
      expect(
        ready().lastOperationError?.cause,
        isA<CaptureStoreException>(),
        reason: 'so the UI can say "storage is full", not "camera error"',
      );
    });

    test(
      'an empty batch left by a failed capture still accepts the next one',
      () async {
        await readyCamera();
        harness.store.persistFailure = const CaptureStoreException(
          CaptureStoreFailure.writeFailed,
        );
        await harness.cubit.capture();
        final String batchId = (await harness.dao.openDraftBatch())!.id;

        harness.store.persistFailure = null;
        await harness.cubit.capture();

        final CaptureBatch batch = (await harness.dao.openDraftBatch())!;
        expect(
          batch.id,
          batchId,
          reason: 'the draft is reused, not duplicated',
        );
        expect(batch.imageCount, 1);
      },
    );
  });

  group('capture across a teardown', () {
    test('a capture landing after a release publishes no state', () async {
      await readyCamera();
      final FakeCameraSession live = session();
      final Completer<void> shutter = Completer<void>();
      live.captureGate = shutter;

      final Future<void> capturing = harness.cubit.capture();
      await harness.cubit.release();
      shutter.complete();
      await capturing;

      expect(harness.cubit.state, isA<CameraReleased>());
    });

    test('a capture landing after a release writes no row either', () async {
      await readyCamera();
      final Completer<void> shutter = Completer<void>();
      session().captureGate = shutter;

      final Future<void> capturing = harness.cubit.capture();
      await harness.cubit.release();
      shutter.complete();
      await capturing;

      expect(
        await harness.dao.openDraftBatch(),
        isNull,
        reason: 'the photograph belonged to a camera the app has let go',
      );
    });

    test('capturing with no camera does nothing', () async {
      harness = await CameraHarness.create(
        devices: <CameraDevice>[FakeCameraEngine.backCamera('0')],
      );

      await harness.cubit.capture();

      expect(harness.cubit.state, isA<CameraInitial>());
      expect(await harness.dao.openDraftBatch(), isNull);
    });
  });
}
