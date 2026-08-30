// FLT-CAM-011, FLT-ERR-001, FLT-ERR-003, FLT-ERR-004, FLT-TEST-005.
//
// Every failure state the camera can reach on the way to a live preview, each
// reached the way the device would cause it. "Graceful handling of permission
// and hardware failures" (GR-4) is a mandatory requirement, and a state nobody
// has driven is not evidence of it.

import 'package:flutter_test/flutter_test.dart';
import 'package:presence_lens_capture/domain/entities/camera_capabilities.dart';
import 'package:presence_lens_capture/domain/entities/camera_device.dart';
import 'package:presence_lens_capture/domain/entities/camera_error.dart';
import 'package:presence_lens_capture/domain/entities/zoom_preset.dart';
import 'package:presence_lens_capture/presentation/camera/camera_state.dart';

import '../../support/camera_harness.dart';
import '../../support/fake_camera.dart';

void main() {
  late CameraHarness harness;

  Future<CameraHarness> withCameras(
    List<CameraDevice> devices, {
    CameraCapabilities? capabilities,
  }) async {
    harness = await CameraHarness.create(
      devices: devices,
      capabilities: capabilities,
    );
    return harness;
  }

  tearDown(() => harness.dispose());

  group('enumeration', () {
    test('opens the only back camera and reports it ready', () async {
      await withCameras(<CameraDevice>[FakeCameraEngine.backCamera('0')]);

      await harness.cubit.acquire();

      final CameraState state = harness.cubit.state;
      expect(state, isA<CameraReady>());
      expect((state as CameraReady).device.id, '0');
      expect(state.backCameras, hasLength(1));
      expect(state.canSwitchCamera, isFalse);
    });

    test(
      'a device with no cameras produces a named state, not an exception',
      () async {
        await withCameras(<CameraDevice>[]);

        await harness.cubit.acquire();

        expect(
          harness.cubit.state,
          const CameraUnavailable(CameraUnavailableReason.noCameras),
        );
      },
    );

    test(
      'a front-only device is distinguished from having no camera',
      () async {
        // Both are unusable, but they are different facts and the copy differs.
        await withCameras(<CameraDevice>[FakeCameraEngine.frontCamera('1')]);

        await harness.cubit.acquire();

        expect(
          harness.cubit.state,
          const CameraUnavailable(CameraUnavailableReason.noBackCamera),
        );
        expect(harness.engine.openCalls, isEmpty);
      },
    );

    test(
      'front and external cameras are filtered out of the selection',
      () async {
        await withCameras(<CameraDevice>[
          FakeCameraEngine.frontCamera('1'),
          FakeCameraEngine.backCamera('0'),
          FakeCameraEngine.externalCamera('9'),
          FakeCameraEngine.backCamera('2', ordinal: 1),
        ]);

        await harness.cubit.acquire();

        final CameraReady ready = harness.cubit.state as CameraReady;
        expect(ready.backCameras.map((CameraDevice d) => d.id), <String>[
          '0',
          '2',
        ]);
        expect(ready.canSwitchCamera, isTrue);
      },
    );

    test('enumeration throwing becomes a recoverable failure state', () async {
      await withCameras(<CameraDevice>[FakeCameraEngine.backCamera('0')]);
      harness.engine.enumerationFailure = cameraFailure(
        CameraErrorKind.cameraUnavailable,
      );

      await harness.cubit.acquire();

      expect(harness.cubit.state, isA<CameraFailed>());
      expect(
        (harness.cubit.state as CameraFailed).kind,
        CameraErrorKind.cameraUnavailable,
      );
    });

    test('a non-camera exception is still classified, not rethrown', () async {
      await withCameras(<CameraDevice>[FakeCameraEngine.backCamera('0')]);
      harness.engine.enumerationFailure = StateError('platform channel gone');

      await harness.cubit.acquire();

      expect(harness.cubit.state, isA<CameraFailed>());
    });
  });

  group('camera identity', () {
    test('a reported lens type survives into the state unchanged', () async {
      await withCameras(<CameraDevice>[
        FakeCameraEngine.backCamera('0', lens: CameraLensKind.ultraWide),
        FakeCameraEngine.backCamera('1', ordinal: 1, lens: CameraLensKind.wide),
      ]);

      await harness.cubit.acquire();

      final CameraReady ready = harness.cubit.state as CameraReady;
      expect(ready.backCameras[0].lensKind, CameraLensKind.ultraWide);
      expect(ready.backCameras[1].lensKind, CameraLensKind.wide);
    });

    test(
      'the identified wide lens is opened, not merely the first camera',
      () async {
        await withCameras(<CameraDevice>[
          FakeCameraEngine.backCamera('0', lens: CameraLensKind.ultraWide),
          FakeCameraEngine.backCamera(
            '1',
            ordinal: 1,
            lens: CameraLensKind.wide,
          ),
        ]);

        await harness.cubit.acquire();

        expect((harness.cubit.state as CameraReady).device.id, '1');
      },
    );

    test(
      'unknown lens types produce NO preset claiming an optical identity',
      () async {
        // The Android case, end to end: three rear cameras, none identified.
        await withCameras(
          <CameraDevice>[
            FakeCameraEngine.backCamera('0'),
            FakeCameraEngine.backCamera('1', ordinal: 1),
            FakeCameraEngine.backCamera('2', ordinal: 2),
          ],
          capabilities: CameraCapabilities(
            zoom: ZoomRange(min: 1, max: 8),
            focusPointSupported: true,
            exposurePointSupported: true,
          ),
        );

        await harness.cubit.acquire();

        final CameraReady ready = harness.cubit.state as CameraReady;
        expect(ready.presets, isNotEmpty);
        expect(
          ready.presets.every((ZoomPreset p) => !p.claimsOpticalIdentity),
          isTrue,
        );
        expect(ready.device.id, '0', reason: 'deterministic fallback');
      },
    );
  });

  group('initialisation', () {
    test('capabilities are read from the platform, not assumed', () async {
      await withCameras(
        <CameraDevice>[FakeCameraEngine.backCamera('0')],
        capabilities: CameraCapabilities(
          zoom: ZoomRange(min: 0.6, max: 12),
          focusPointSupported: true,
          exposurePointSupported: true,
          previewAspectRatio: 4 / 3,
        ),
      );

      await harness.cubit.acquire();

      final CameraReady ready = harness.cubit.state as CameraReady;
      expect(ready.zoomRange.min, 0.6);
      expect(ready.zoomRange.max, 12);
      expect(ready.canFocus, isTrue);
      expect(ready.canSetExposurePoint, isTrue);
      expect(ready.capabilities.previewAspectRatio, 4 / 3);
    });

    test(
      'presets come from the reported range, sub-1 included when real',
      () async {
        await withCameras(
          <CameraDevice>[FakeCameraEngine.backCamera('0')],
          capabilities: CameraCapabilities(
            zoom: ZoomRange(min: 0.6, max: 4),
            focusPointSupported: false,
            exposurePointSupported: false,
          ),
        );

        await harness.cubit.acquire();

        expect(
          (harness.cubit.state as CameraReady).presets.map(
            (ZoomPreset p) => p.label,
          ),
          <String>['0.6x', '1x', '2x'],
        );
      },
    );

    test('the camera opens at 1.0 and pushes it to the platform', () async {
      await withCameras(
        <CameraDevice>[FakeCameraEngine.backCamera('0')],
        capabilities: CameraCapabilities(
          zoom: ZoomRange(min: 0.5, max: 8),
          focusPointSupported: false,
          exposurePointSupported: false,
        ),
      );

      await harness.cubit.acquire();

      expect((harness.cubit.state as CameraReady).currentZoom, 1);
      expect(harness.engine.sessions.single.appliedZoom, <double>[1]);
    });

    test(
      'a permission refusal becomes the denied state, not a failure',
      () async {
        await withCameras(<CameraDevice>[FakeCameraEngine.backCamera('0')]);
        harness.engine.openFailure = cameraFailure(
          CameraErrorKind.permissionDenied,
        );

        await harness.cubit.acquire();

        final CameraState state = harness.cubit.state;
        expect(state, isA<CameraPermissionDenied>());
        expect((state as CameraPermissionDenied).canRetry, isTrue);
        expect(state.isPermanentPerPlatform, isFalse);
        expect(state.consecutiveDenials, 1);
      },
    );

    test(
      'only a platform verdict may report permanent denial (Android never does)',
      () async {
        await withCameras(<CameraDevice>[FakeCameraEngine.backCamera('0')]);
        harness.engine.openFailure = cameraFailure(
          CameraErrorKind.permissionPermanentlyDenied,
        );

        await harness.cubit.acquire();

        final CameraPermissionDenied state =
            harness.cubit.state as CameraPermissionDenied;
        expect(state.isPermanentPerPlatform, isTrue);
        expect(state.canRetry, isFalse);
      },
    );

    test(
      'repeated refusals are counted but never promoted to permanent',
      () async {
        // The escalation signal for the later UI. It must stay a *count*: turning
        // it into a permanence claim would assert something Android never said
        // (`ADR-F22`).
        await withCameras(<CameraDevice>[FakeCameraEngine.backCamera('0')]);
        harness.engine.openFailure = cameraFailure(
          CameraErrorKind.permissionDenied,
        );

        await harness.cubit.acquire();
        await harness.cubit.retry();
        await harness.cubit.retry();

        final CameraPermissionDenied state =
            harness.cubit.state as CameraPermissionDenied;
        expect(state.consecutiveDenials, 3);
        expect(state.isPermanentPerPlatform, isFalse);
        expect(state.canRetry, isTrue);
      },
    );

    test('a restricted camera cannot be retried by the user', () async {
      await withCameras(<CameraDevice>[FakeCameraEngine.backCamera('0')]);
      harness.engine.openFailure = cameraFailure(
        CameraErrorKind.permissionRestricted,
      );

      await harness.cubit.acquire();

      final CameraPermissionDenied state =
          harness.cubit.state as CameraPermissionDenied;
      expect(state.isRestricted, isTrue);
      expect(state.canRetry, isFalse);
    });

    test(
      'initialisation failure is recoverable without leaving the screen',
      () async {
        await withCameras(<CameraDevice>[FakeCameraEngine.backCamera('0')]);
        harness.engine.openFailureOnce = cameraFailure(
          CameraErrorKind.initializationFailed,
        );

        await harness.cubit.acquire();
        expect(harness.cubit.state, isA<CameraFailed>());

        await harness.cubit.retry();
        expect(harness.cubit.state, isA<CameraReady>());
      },
    );

    test('a granted retry after a refusal clears the denial count', () async {
      await withCameras(<CameraDevice>[FakeCameraEngine.backCamera('0')]);
      harness.engine.openFailureOnce = cameraFailure(
        CameraErrorKind.permissionDenied,
      );

      await harness.cubit.acquire();
      expect(harness.cubit.state, isA<CameraPermissionDenied>());

      await harness.cubit.retry();
      expect(harness.cubit.state, isA<CameraReady>());

      harness.engine.openFailure = cameraFailure(
        CameraErrorKind.permissionDenied,
      );
      await harness.cubit.retry();
      expect(
        (harness.cubit.state as CameraPermissionDenied).consecutiveDenials,
        1,
        reason: 'the counter measures *consecutive* refusals',
      );
    });

    test('a failed open leaks no session', () async {
      await withCameras(<CameraDevice>[FakeCameraEngine.backCamera('0')]);
      harness.engine.openFailure = cameraFailure(
        CameraErrorKind.initializationFailed,
      );

      await harness.cubit.acquire();

      expect(harness.engine.liveSessions, isEmpty);
    });

    test('preparing states are emitted on the way to ready', () async {
      await withCameras(<CameraDevice>[FakeCameraEngine.backCamera('0')]);
      final List<CameraState> seen = <CameraState>[];
      final subscription = harness.cubit.stream.listen(seen.add);

      await harness.cubit.acquire();
      await subscription.cancel();

      expect(seen.whereType<CameraPreparing>(), isNotEmpty);
      expect(seen.last, isA<CameraReady>());
    });
  });
}
