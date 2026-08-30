// FLT-CAM-013, RF-04, RF-05.
//
// The crash class. A camera switch is two asynchronous operations racing each
// other, and the failure — a disposed controller still attached to the preview
// — is a hard crash on device and completely invisible on a host unless the
// ordering is forced. These tests force it.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:presence_lens_capture/domain/entities/camera_device.dart';
import 'package:presence_lens_capture/domain/entities/camera_error.dart';
import 'package:presence_lens_capture/presentation/camera/camera_state.dart';

import '../../support/camera_harness.dart';
import '../../support/fake_camera.dart';

void main() {
  late CameraHarness harness;

  Future<void> withThreeBackCameras() async {
    harness = await CameraHarness.create(
      devices: <CameraDevice>[
        FakeCameraEngine.backCamera('A'),
        FakeCameraEngine.backCamera('B', ordinal: 1),
        FakeCameraEngine.backCamera('C', ordinal: 2),
      ],
    );
  }

  CameraReady ready() => harness.cubit.state as CameraReady;

  /// The back camera at [index] in the current ready state.
  CameraDevice camera(int index) => ready().backCameras[index];

  /// Lets the event loop turn until [condition] holds.
  ///
  /// Needed because the interesting race is not "two calls issued together" but
  /// "the second call issued *after* the first has already reached the
  /// platform" — and that has to be waited for, not assumed.
  Future<void> pumpUntil(bool Function() condition) async {
    for (int i = 0; i < 100 && !condition(); i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// Starts A→B, waits until B's open is genuinely in flight, then supersedes
  /// it with A→C and completes **B last**.
  ///
  /// This is the ordering that breaks a naive implementation: B's session is
  /// real and open by the time it arrives, and attaching it would put the user
  /// on a camera they left two taps ago.
  Future<void> raceBSupersededByC() async {
    final List<CameraDevice> cameras = ready().backCameras;
    harness.engine.holdOpen('B');
    final Future<void> toB = harness.cubit.switchTo(cameras[1]);
    await pumpUntil(() => harness.engine.openCalls.contains('B'));

    harness.engine.holdOpen('C');
    final Future<void> toC = harness.cubit.switchTo(cameras[2]);
    await pumpUntil(() => harness.engine.openCalls.contains('C'));

    harness.engine.releaseOpen('C');
    harness.engine.releaseOpen('B');
    await Future.wait(<Future<void>>[toB, toC]);
  }

  tearDown(() => harness.dispose());

  group('switching', () {
    test('moves to the requested camera', () async {
      await withThreeBackCameras();
      await harness.cubit.acquire();

      await harness.cubit.switchTo(camera(1));

      expect(ready().device.id, 'B');
    });

    test('the superseded session is disposed, never merely dropped', () async {
      await withThreeBackCameras();
      await harness.cubit.acquire();
      final FakeCameraSession first = harness.engine.sessions.single;

      await harness.cubit.switchTo(camera(1));

      expect(first.isDisposed, isTrue);
      expect(harness.engine.liveSessions, hasLength(1));
      expect(harness.engine.liveSessions.single.device.id, 'B');
    });

    test('cycling wraps back to the first camera', () async {
      await withThreeBackCameras();
      await harness.cubit.acquire();

      await harness.cubit.switchToNextCamera();
      expect(ready().device.id, 'B');
      await harness.cubit.switchToNextCamera();
      expect(ready().device.id, 'C');
      await harness.cubit.switchToNextCamera();
      expect(ready().device.id, 'A');
    });

    test('switching to the camera already open does nothing at all', () async {
      await withThreeBackCameras();
      await harness.cubit.acquire();
      final int opensBefore = harness.engine.openCalls.length;

      await harness.cubit.switchTo(ready().device);

      expect(harness.engine.openCalls.length, opensBefore);
      expect(harness.engine.liveSessions, hasLength(1));
    });

    test('a single-camera device has nothing to cycle to', () async {
      harness = await CameraHarness.create(
        devices: <CameraDevice>[FakeCameraEngine.backCamera('A')],
      );
      await harness.cubit.acquire();
      final int opensBefore = harness.engine.openCalls.length;

      await harness.cubit.switchToNextCamera();

      expect(harness.engine.openCalls.length, opensBefore);
    });

    test(
      'a failed switch leaves a recoverable state, not a dead preview',
      () async {
        await withThreeBackCameras();
        await harness.cubit.acquire();
        harness.engine.openFailure = cameraFailure(
          CameraErrorKind.initializationFailed,
        );

        await harness.cubit.switchTo(camera(1));

        expect(harness.cubit.state, isA<CameraFailed>());
        expect(
          harness.engine.liveSessions,
          isEmpty,
          reason:
              'the old session was released before the new one was asked '
              'for, so a failure cannot leave two',
        );

        harness.engine.openFailure = null;
        await harness.cubit.retry();
        expect(harness.cubit.state, isA<CameraReady>());
      },
    );

    test(
      'the new camera opens at its own baseline, not the previous zoom',
      () async {
        await withThreeBackCameras();
        await harness.cubit.acquire();
        await harness.cubit.setZoom(1);
        expect(ready().currentZoom, 1);

        await harness.cubit.switchTo(camera(1));

        expect(ready().currentZoom, 1);
        expect(harness.engine.liveSessions.single.appliedZoom, <double>[1]);
      },
    );
  });

  group('the stale-async race', () {
    test('A→B→C ends on C, however late B completes', () async {
      await withThreeBackCameras();
      await harness.cubit.acquire();

      await raceBSupersededByC();

      expect(harness.cubit.state, isA<CameraReady>());
      expect(ready().device.id, 'C');
    });

    test('a supersede before the open starts never opens that camera', () async {
      // The cheaper half of the guard: two switches issued back to back, before
      // the first has reached the platform. The generation check fires *before*
      // `openSession`, so the middle camera is never acquired at all — no
      // session to leak, and one fewer hardware acquisition than a queue-based
      // implementation would perform.
      await withThreeBackCameras();
      await harness.cubit.acquire();
      final List<CameraDevice> cameras = ready().backCameras;
      final int opensBefore = harness.engine.openCalls.length;

      final Future<void> toB = harness.cubit.switchTo(cameras[1]);
      final Future<void> toC = harness.cubit.switchTo(cameras[2]);
      await Future.wait(<Future<void>>[toB, toC]);

      expect(harness.engine.openCalls.skip(opensBefore), <String>[
        'C',
      ], reason: 'B was superseded before it was ever asked for');
      expect(ready().device.id, 'C');
      expect(harness.engine.liveSessions, hasLength(1));
    });

    test('the late session is disposed rather than attached', () async {
      await withThreeBackCameras();
      await harness.cubit.acquire();

      await raceBSupersededByC();

      final Iterable<FakeCameraSession> forB = harness.engine.sessions.where(
        (FakeCameraSession s) => s.device.id == 'B',
      );
      expect(forB, hasLength(1));
      expect(
        forB.single.isDisposed,
        isTrue,
        reason: 'B opened after it had been superseded and must be released',
      );
      expect(harness.engine.liveSessions, hasLength(1));
      expect(harness.engine.liveSessions.single.device.id, 'C');
    });

    test('no state is ever emitted for a superseded camera', () async {
      await withThreeBackCameras();
      await harness.cubit.acquire();

      final List<String> readyCameras = <String>[];
      final StreamSubscription<CameraState> subscription = harness.cubit.stream
          .listen((CameraState s) {
            if (s is CameraReady) {
              readyCameras.add(s.device.id);
            }
          });

      await raceBSupersededByC();
      await subscription.cancel();

      expect(readyCameras, <String>[
        'C',
      ], reason: 'the user must never see the camera they moved away from');
    });

    test('rapid repeated taps leak no controllers', () async {
      await withThreeBackCameras();
      await harness.cubit.acquire();

      for (int i = 0; i < 8; i++) {
        await harness.cubit.switchToNextCamera();
      }

      expect(harness.engine.liveSessions, hasLength(1));
    });

    test(
      'a switch that lands after a release does not resurrect the camera',
      () async {
        await withThreeBackCameras();
        await harness.cubit.acquire();

        harness.engine.holdOpen('B');
        final Future<void> switching = harness.cubit.switchTo(camera(1));
        await harness.cubit.release();
        harness.engine.releaseOpen('B');
        await switching;

        expect(harness.cubit.state, isA<CameraReleased>());
        expect(harness.engine.liveSessions, isEmpty);
      },
    );
  });

  group('switching during capture', () {
    test('is refused while a photograph is in flight', () async {
      await withThreeBackCameras();
      await harness.cubit.acquire();
      final FakeCameraSession session = harness.engine.sessions.single;
      final Completer<void> shutter = Completer<void>();
      session.captureGate = shutter;

      final Future<void> capturing = harness.cubit.capture();
      expect(ready().isCapturing, isTrue);
      final int opensBefore = harness.engine.openCalls.length;

      await harness.cubit.switchTo(camera(1));

      expect(
        harness.engine.openCalls.length,
        opensBefore,
        reason: 'disposing the controller mid-shutter would lose the photo',
      );
      expect(ready().device.id, 'A');

      shutter.complete();
      await capturing;
    });

    test('is allowed again as soon as the capture completes', () async {
      await withThreeBackCameras();
      await harness.cubit.acquire();

      await harness.cubit.capture();
      expect(ready().isCapturing, isFalse);

      await harness.cubit.switchTo(camera(1));
      expect(ready().device.id, 'B');
    });
  });
}
