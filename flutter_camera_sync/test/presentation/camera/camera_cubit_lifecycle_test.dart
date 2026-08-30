// FLT-CAM-012, RESEARCH FR-02, §33.
//
// The `camera` plugin has not handled lifecycle since 0.5.0, so every one of
// these transitions is the app's own responsibility. The regressions guarded
// here are: holding the hardware while backgrounded, failing to come back, and
// letting a pre-pause operation overwrite the state after a resume.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:presence_lens_capture/domain/entities/batch_status.dart';
import 'package:presence_lens_capture/domain/entities/camera_capabilities.dart';
import 'package:presence_lens_capture/domain/entities/camera_device.dart';
import 'package:presence_lens_capture/domain/entities/camera_error.dart';
import 'package:presence_lens_capture/domain/entities/camera_lifecycle_signal.dart';
import 'package:presence_lens_capture/domain/entities/capture_batch.dart';
import 'package:presence_lens_capture/presentation/camera/camera_state.dart';

import '../../support/camera_harness.dart';
import '../../support/fake_camera.dart';

void main() {
  late CameraHarness harness;

  Future<void> readyCamera({List<CameraDevice>? devices}) async {
    harness = await CameraHarness.create(
      devices: devices ?? <CameraDevice>[FakeCameraEngine.backCamera('0')],
    );
    await harness.cubit.acquire();
  }

  CameraReady ready() => harness.cubit.state as CameraReady;

  tearDown(() => harness.dispose());

  group('release', () {
    test('paused releases the hardware', () async {
      await readyCamera();
      final FakeCameraSession live = harness.engine.sessions.single;

      await harness.cubit.handleLifecycle(CameraLifecycleSignal.paused);

      expect(live.isDisposed, isTrue);
      expect(harness.engine.liveSessions, isEmpty);
      expect(harness.cubit.state, isA<CameraReleased>());
    });

    test('detached releases too', () async {
      await readyCamera();

      await harness.cubit.handleLifecycle(CameraLifecycleSignal.detached);

      expect(harness.engine.liveSessions, isEmpty);
    });

    test('inactive changes NOTHING', () async {
      // Deliberate. `inactive` fires for the system permission dialog, and
      // releasing there tears the preview down during the very prompt that is
      // trying to grant access (`CAMERA_ENGINE.md` §2).
      await readyCamera();
      final CameraState before = harness.cubit.state;

      await harness.cubit.handleLifecycle(CameraLifecycleSignal.inactive);

      expect(harness.cubit.state, same(before));
      expect(harness.engine.liveSessions, hasLength(1));
    });

    test('the released state remembers which camera to reopen', () async {
      await readyCamera(
        devices: <CameraDevice>[
          FakeCameraEngine.backCamera('A'),
          FakeCameraEngine.backCamera('B', ordinal: 1),
        ],
      );
      await harness.cubit.switchTo(ready().backCameras[1]);

      await harness.cubit.handleLifecycle(CameraLifecycleSignal.paused);

      expect((harness.cubit.state as CameraReleased).device?.id, 'B');
    });

    test('releasing twice is safe', () async {
      await readyCamera();

      await harness.cubit.handleLifecycle(CameraLifecycleSignal.paused);
      await harness.cubit.handleLifecycle(CameraLifecycleSignal.paused);

      expect(harness.cubit.state, isA<CameraReleased>());
      expect(harness.engine.liveSessions, isEmpty);
    });
  });

  group('resume', () {
    test('reacquires after a pause', () async {
      await readyCamera();
      await harness.cubit.handleLifecycle(CameraLifecycleSignal.paused);

      await harness.cubit.handleLifecycle(CameraLifecycleSignal.resumed);

      expect(harness.cubit.state, isA<CameraReady>());
      expect(harness.engine.liveSessions, hasLength(1));
    });

    test(
      'restores the camera the user had selected, not the default',
      () async {
        await readyCamera(
          devices: <CameraDevice>[
            FakeCameraEngine.backCamera('A'),
            FakeCameraEngine.backCamera('B', ordinal: 1),
          ],
        );
        await harness.cubit.switchTo(ready().backCameras[1]);
        await harness.cubit.handleLifecycle(CameraLifecycleSignal.paused);

        await harness.cubit.handleLifecycle(CameraLifecycleSignal.resumed);

        expect(ready().device.id, 'B');
      },
    );

    test('a resume while already live does nothing', () async {
      await readyCamera();
      final FakeCameraSession live = harness.engine.sessions.single;

      await harness.cubit.handleLifecycle(CameraLifecycleSignal.resumed);

      expect(harness.engine.sessions, hasLength(1));
      expect(live.isDisposed, isFalse);
    });

    test('a failed resume becomes a recoverable error state', () async {
      await readyCamera();
      await harness.cubit.handleLifecycle(CameraLifecycleSignal.paused);
      harness.engine.openFailure = cameraFailure(
        CameraErrorKind.cameraUnavailable,
      );

      await harness.cubit.handleLifecycle(CameraLifecycleSignal.resumed);

      expect(harness.cubit.state, isA<CameraFailed>());
      expect(harness.engine.liveSessions, isEmpty);
    });

    test(
      'resume retries a permission refusal — the settings round trip',
      () async {
        // What makes "Open settings" work without the user hunting for a retry
        // button when they come back (`CAMERA_ENGINE.md` §7).
        await readyCamera();
        await harness.cubit.handleLifecycle(CameraLifecycleSignal.paused);
        harness.engine.openFailureOnce = cameraFailure(
          CameraErrorKind.permissionDenied,
        );
        await harness.cubit.handleLifecycle(CameraLifecycleSignal.resumed);
        expect(harness.cubit.state, isA<CameraPermissionDenied>());

        await harness.cubit.handleLifecycle(CameraLifecycleSignal.resumed);

        expect(harness.cubit.state, isA<CameraReady>());
      },
    );

    test('resume does NOT re-enumerate on a device with no camera', () async {
      // A fact that cannot change between one resume and the next; retrying it
      // would be a loop against the hardware.
      harness = await CameraHarness.create(devices: <CameraDevice>[]);
      await harness.cubit.acquire();
      final int enumerations = harness.engine.enumerationCount;

      await harness.cubit.handleLifecycle(CameraLifecycleSignal.resumed);

      expect(harness.engine.enumerationCount, enumerations);
      expect(harness.cubit.state, isA<CameraUnavailable>());
    });

    test('zoom is re-applied to the restored session', () async {
      harness = await CameraHarness.create(
        devices: <CameraDevice>[FakeCameraEngine.backCamera('0')],
        capabilities: CameraCapabilities(
          zoom: ZoomRange(min: 0.5, max: 8),
          focusPointSupported: true,
          exposurePointSupported: false,
        ),
      );
      await harness.cubit.acquire();
      await harness.cubit.handleLifecycle(CameraLifecycleSignal.paused);

      await harness.cubit.handleLifecycle(CameraLifecycleSignal.resumed);

      expect(ready().currentZoom, 1);
      expect(harness.engine.liveSessions.single.appliedZoom, <double>[1]);
    });
  });

  group('captures survive the lifecycle', () {
    test('a pause does not touch already-captured images', () async {
      // The one thing that must never be sacrificed to hardware management.
      await readyCamera();
      await harness.cubit.capture();
      await harness.cubit.capture();
      final CaptureBatch before = (await harness.dao.openDraftBatch())!;

      await harness.cubit.handleLifecycle(CameraLifecycleSignal.paused);

      final CaptureBatch after = (await harness.dao.openDraftBatch())!;
      expect(after.id, before.id);
      expect(after.imageCount, 2);
      expect(after.status, BatchStatus.draft);
      expect(harness.store.files, hasLength(2));
    });

    test(
      'a resumed camera keeps capturing into the same draft batch',
      () async {
        await readyCamera();
        await harness.cubit.capture();
        final String batchId = (await harness.dao.openDraftBatch())!.id;

        await harness.cubit.handleLifecycle(CameraLifecycleSignal.paused);
        await harness.cubit.handleLifecycle(CameraLifecycleSignal.resumed);
        await harness.cubit.capture();

        final CaptureBatch batch = (await harness.dao.openDraftBatch())!;
        expect(batch.id, batchId);
        expect(batch.imageCount, 2);
      },
    );
  });

  group('stale completions across the lifecycle (§33)', () {
    test(
      'a pre-pause initialisation cannot overwrite the resumed state',
      () async {
        // The nastiest ordering: an acquire is still in flight when the app is
        // backgrounded and then foregrounded. The first one must lose.
        harness = await CameraHarness.create(
          devices: <CameraDevice>[FakeCameraEngine.backCamera('0')],
        );
        harness.engine.holdOpen('0');
        final Future<void> firstAcquire = harness.cubit.acquire();

        await harness.cubit.handleLifecycle(CameraLifecycleSignal.paused);
        harness.engine.releaseOpen('0');
        await firstAcquire;

        expect(
          harness.cubit.state,
          isA<CameraReleased>(),
          reason: 'the in-flight acquire belonged to a generation that is gone',
        );
        expect(
          harness.engine.liveSessions,
          isEmpty,
          reason: 'the session it built must be disposed, not leaked',
        );
      },
    );

    test('a resume after that stale completion still works', () async {
      harness = await CameraHarness.create(
        devices: <CameraDevice>[FakeCameraEngine.backCamera('0')],
      );
      harness.engine.holdOpen('0');
      final Future<void> firstAcquire = harness.cubit.acquire();
      await harness.cubit.handleLifecycle(CameraLifecycleSignal.paused);
      harness.engine.releaseOpen('0');
      await firstAcquire;

      await harness.cubit.handleLifecycle(CameraLifecycleSignal.resumed);

      expect(harness.cubit.state, isA<CameraReady>());
      expect(harness.engine.liveSessions, hasLength(1));
    });
  });

  group('disposal (§33)', () {
    test('closing the cubit releases the hardware', () async {
      await readyCamera();
      final FakeCameraSession live = harness.engine.sessions.single;

      await harness.cubit.close();

      expect(live.isDisposed, isTrue);
    });

    test(
      'a session is disposed exactly once, even after a double release',
      () async {
        await readyCamera();
        final FakeCameraSession live = harness.engine.sessions.single;

        await harness.cubit.release();
        await harness.cubit.release();
        await harness.cubit.close();

        expect(live.isDisposed, isTrue);
        expect(
          live.disposeCount,
          1,
          reason: 'the cubit drops its reference on the first release',
        );
      },
    );

    test(
      'an operation completing after close emits nothing and does not throw',
      () async {
        await readyCamera();
        final FakeCameraSession live = harness.engine.sessions.single;
        final Completer<void> gate = Completer<void>();
        live.zoomGate = gate;

        final Future<void> zooming = harness.cubit.setZoom(3);
        await harness.cubit.close();
        gate.complete();

        await expectLater(zooming, completes);
      },
    );

    test('a capture completing after close writes no state', () async {
      await readyCamera();
      final Completer<void> shutter = Completer<void>();
      harness.engine.sessions.single.captureGate = shutter;

      final Future<void> capturing = harness.cubit.capture();
      await harness.cubit.close();
      shutter.complete();

      await expectLater(capturing, completes);
    });
  });
}
