// FLT-CAM-003, FLT-CAM-006, FLT-CAM-007.
//
// The pure arithmetic is proven in `zoom_policy_test`. What is proven here is
// the thing a policy test cannot reach: that pinch, slider and presets are
// three inputs to **one** value, and that a flood of gesture callbacks does not
// become a flood of platform calls.

import 'dart:async';

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

  Future<void> withZoomRange(double min, double max) async {
    harness = await CameraHarness.create(
      devices: <CameraDevice>[FakeCameraEngine.backCamera('0')],
      capabilities: CameraCapabilities(
        zoom: ZoomRange(min: min, max: max),
        focusPointSupported: true,
        exposurePointSupported: false,
      ),
    );
    await harness.cubit.acquire();
  }

  CameraReady ready() => harness.cubit.state as CameraReady;
  FakeCameraSession session() => harness.engine.sessions.last;

  tearDown(() => harness.dispose());

  group('one value, three controls (FLT-CAM-006)', () {
    test('a slider write and a preset write land on the same field', () async {
      await withZoomRange(0.5, 8);

      await harness.cubit.setZoom(3.5);
      expect(ready().currentZoom, 3.5);

      await harness.cubit.applyPreset(
        const ZoomPreset(
          value: 2,
          label: '2x',
          provenance: ZoomPresetProvenance.deviceReportedRange,
        ),
      );
      expect(ready().currentZoom, 2);
    });

    test(
      'a pinch and a preset cannot disagree, because there is one value',
      () async {
        await withZoomRange(0.5, 8);

        harness.cubit.beginPinch();
        await harness.cubit.updatePinch(4);
        harness.cubit.endPinch();
        expect(ready().currentZoom, 4);

        await harness.cubit.applyPreset(
          const ZoomPreset(
            value: 1,
            label: '1x',
            provenance: ZoomPresetProvenance.baseline,
          ),
        );
        expect(ready().currentZoom, 1);

        // And the next pinch starts from where the preset put it.
        harness.cubit.beginPinch();
        await harness.cubit.updatePinch(2);
        expect(ready().currentZoom, 2);
      },
    );

    test('the state moves before the platform call resolves', () async {
      // The slider has to track the finger, not the IPC round trip.
      await withZoomRange(0.5, 8);
      final Completer<void> gate = Completer<void>();
      session().zoomGate = gate;

      final Future<void> pending = harness.cubit.setZoom(6);
      expect(ready().currentZoom, 6);
      expect(session().appliedZoom, isNot(contains(6)));

      gate.complete();
      await pending;
      expect(session().appliedZoom.last, 6);
    });
  });

  group('clamping (FLT-CAM-007)', () {
    test('a request above the maximum is clamped, not rejected', () async {
      await withZoomRange(1, 4);

      await harness.cubit.setZoom(100);

      expect(ready().currentZoom, 4);
      expect(session().appliedZoom.last, 4);
    });

    test('a request below a non-1.0 minimum clamps to that minimum', () async {
      await withZoomRange(0.6, 8);

      await harness.cubit.setZoom(0.1);

      expect(ready().currentZoom, 0.6);
      expect(session().appliedZoom.last, 0.6);
    });

    test('a camera that cannot zoom stays at its single value', () async {
      await withZoomRange(1, 1);

      await harness.cubit.setZoom(5);

      expect(ready().currentZoom, 1);
      expect(ready().zoomRange.isAdjustable, isFalse);
    });

    test('a pinch cannot drive past either end', () async {
      await withZoomRange(0.5, 4);

      harness.cubit.beginPinch();
      await harness.cubit.updatePinch(50);
      expect(ready().currentZoom, 4);
      await harness.cubit.updatePinch(0.001);
      expect(ready().currentZoom, 0.5);
      harness.cubit.endPinch();
    });
  });

  group('pinch anchoring', () {
    test(
      'a gesture returning to scale 1 returns the zoom to its start',
      () async {
        await withZoomRange(0.5, 8);
        await harness.cubit.setZoom(2);

        harness.cubit.beginPinch();
        await harness.cubit.updatePinch(1.5);
        await harness.cubit.updatePinch(2);
        await harness.cubit.updatePinch(1);
        harness.cubit.endPinch();

        expect(
          ready().currentZoom,
          2,
          reason: 'anchored to the gesture start, so it cannot drift',
        );
      },
    );

    test('a pinch update outside a gesture is ignored', () async {
      await withZoomRange(0.5, 8);
      await harness.cubit.setZoom(2);

      await harness.cubit.updatePinch(4);

      expect(ready().currentZoom, 2);
    });

    test('a stale baseline does not survive endPinch', () async {
      await withZoomRange(0.5, 8);

      harness.cubit.beginPinch();
      await harness.cubit.updatePinch(3);
      harness.cubit.endPinch();
      final double afterGesture = ready().currentZoom;

      await harness.cubit.updatePinch(0.5);

      expect(ready().currentZoom, afterGesture);
    });
  });

  group('coalescing (§19)', () {
    test(
      'a burst of requests does not become a burst of platform calls',
      () async {
        await withZoomRange(1, 8);
        final Completer<void> gate = Completer<void>();
        session().zoomGate = gate;
        final int callsBefore = session().appliedZoom.length;

        // Fire twenty updates while one call is in flight, the way a pinch does.
        final List<Future<void>> requests = <Future<void>>[];
        for (int i = 1; i <= 20; i++) {
          requests.add(harness.cubit.setZoom(1 + i * 0.3));
        }
        gate.complete();
        session().zoomGate = null;
        await Future.wait(requests);

        final int newCalls = session().appliedZoom.length - callsBefore;
        expect(
          newCalls,
          lessThan(20),
          reason: 'superseded values must be dropped, not queued',
        );
        expect(newCalls, greaterThan(0));
      },
    );

    test('the LAST requested value is the one finally applied', () async {
      // The property that matters. Coalescing is only safe if nothing is lost
      // at the end of the burst.
      await withZoomRange(1, 8);
      final Completer<void> gate = Completer<void>();
      session().zoomGate = gate;

      final List<Future<void>> requests = <Future<void>>[
        harness.cubit.setZoom(2),
        harness.cubit.setZoom(3),
        harness.cubit.setZoom(4),
        harness.cubit.setZoom(7.5),
      ];
      gate.complete();
      session().zoomGate = null;
      await Future.wait(requests);

      expect(session().appliedZoom.last, 7.5);
      expect(ready().currentZoom, 7.5);
    });

    test(
      'the state reflects every request even when the calls are coalesced',
      () async {
        await withZoomRange(1, 8);
        final List<double> zooms = <double>[];
        final StreamSubscription<CameraState> subscription = harness
            .cubit
            .stream
            .listen((CameraState s) {
              if (s is CameraReady) {
                zooms.add(s.currentZoom);
              }
            });

        final Completer<void> gate = Completer<void>();
        session().zoomGate = gate;
        final List<Future<void>> requests = <Future<void>>[
          harness.cubit.setZoom(2),
          harness.cubit.setZoom(3),
          harness.cubit.setZoom(4),
        ];
        gate.complete();
        session().zoomGate = null;
        await Future.wait(requests);
        // A superseded request completes as soon as it is *recorded*, so the last
        // state emission can still be in the microtask queue when `Future.wait`
        // returns. Drain it before unsubscribing.
        await Future<void>.delayed(Duration.zero);
        await subscription.cancel();

        expect(
          zooms,
          containsAllInOrder(<double>[2, 3, 4]),
          reason: 'the UI stays smooth even while the device is not flooded',
        );
      },
    );
  });

  group('failure', () {
    test('a rejected zoom does not tear down the camera', () async {
      await withZoomRange(1, 8);
      session().zoomFailure = cameraFailure(CameraErrorKind.zoomFailed);

      await harness.cubit.setZoom(4);

      expect(
        harness.cubit.state,
        isA<CameraReady>(),
        reason: 'a zoom rejection is a local operation failure, not a fault',
      );
      expect(ready().lastOperationError?.kind, CameraErrorKind.zoomFailed);
    });

    test('the camera stays usable after a zoom failure', () async {
      await withZoomRange(1, 8);
      session().zoomFailure = cameraFailure(CameraErrorKind.zoomFailed);
      await harness.cubit.setZoom(4);

      session().zoomFailure = null;
      await harness.cubit.setZoom(2);

      expect(session().appliedZoom.last, 2);
      expect(ready().lastOperationError, isNull);
    });

    test('a zoom landing after a release publishes nothing', () async {
      await withZoomRange(1, 8);
      final FakeCameraSession live = session();
      final Completer<void> gate = Completer<void>();
      live.zoomGate = gate;

      final Future<void> zooming = harness.cubit.setZoom(5);
      await harness.cubit.release();
      gate.complete();
      await zooming;

      expect(harness.cubit.state, isA<CameraReleased>());
    });
  });
}
