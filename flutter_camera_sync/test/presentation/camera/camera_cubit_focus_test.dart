// FLT-CAM-008, FLT-CAM-018.
//
// The mapping arithmetic is proven in `focus_point_mapper_test`. Proven here is
// what happens around it: that an unsupported camera is not treated as a broken
// one, that a failed focus does not destroy a working viewfinder, and that the
// exposure bonus can fail without taking the mandatory operation down with it.

import 'package:flutter_test/flutter_test.dart';
import 'package:presence_lens_capture/domain/entities/camera_capabilities.dart';
import 'package:presence_lens_capture/domain/entities/camera_device.dart';
import 'package:presence_lens_capture/domain/entities/camera_error.dart';
import 'package:presence_lens_capture/domain/entities/camera_geometry.dart';
import 'package:presence_lens_capture/domain/entities/focus_request.dart';
import 'package:presence_lens_capture/presentation/camera/camera_state.dart';

import '../../support/camera_harness.dart';
import '../../support/fake_camera.dart';

void main() {
  late CameraHarness harness;

  /// A full-bleed 4:3 preview in a 400×800 box — the production geometry.
  const PreviewLayout coverLayout = PreviewLayout(
    widgetWidth: 400,
    widgetHeight: 800,
    previewAspectRatio: 4 / 3,
  );

  const PreviewLayout containLayout = PreviewLayout(
    widgetWidth: 400,
    widgetHeight: 800,
    previewAspectRatio: 4 / 3,
    fit: PreviewFit.contain,
  );

  Future<void> withFocus({required bool focus, required bool exposure}) async {
    harness = await CameraHarness.create(
      devices: <CameraDevice>[FakeCameraEngine.backCamera('0')],
      capabilities: CameraCapabilities(
        zoom: ZoomRange(min: 1, max: 4),
        focusPointSupported: focus,
        exposurePointSupported: exposure,
        previewAspectRatio: 4 / 3,
      ),
    );
    await harness.cubit.acquire();
  }

  CameraReady ready() => harness.cubit.state as CameraReady;
  FakeCameraSession session() => harness.engine.sessions.last;

  tearDown(() => harness.dispose());

  group('supported focus', () {
    test('a tap reaches the platform as a normalised point', () async {
      await withFocus(focus: true, exposure: false);

      await harness.cubit.focusAt(tapX: 200, tapY: 400, layout: coverLayout);

      expect(session().focusPoints, hasLength(1));
      expect(session().focusPoints.single, NormalizedPoint(0.5, 0.5));
      expect(ready().focusRequest!.outcome, FocusOutcome.applied);
    });

    test('the request records where the user actually tapped', () async {
      // What the reticle is rendered from, so it has to be the tap and not a
      // rounded-off approximation of it.
      await withFocus(focus: true, exposure: false);

      await harness.cubit.focusAt(tapX: 200, tapY: 0, layout: coverLayout);

      final FocusRequest request = ready().focusRequest!;
      expect(request.point.x, closeTo(0.5, 1e-6));
      expect(request.point.y, closeTo(0, 1e-6));
    });

    test('a pending state is published before the platform answers', () async {
      await withFocus(focus: true, exposure: false);
      final List<FocusOutcome> outcomes = <FocusOutcome>[];
      final subscription = harness.cubit.stream.listen((CameraState s) {
        if (s is CameraReady && s.focusRequest != null) {
          outcomes.add(s.focusRequest!.outcome);
        }
      });

      await harness.cubit.focusAt(tapX: 100, tapY: 300, layout: coverLayout);
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(
        outcomes,
        containsAllInOrder(<FocusOutcome>[
          FocusOutcome.pending,
          FocusOutcome.applied,
        ]),
        reason: 'the reticle appears immediately, then settles',
      );
    });

    test('two taps at the same point are distinguishable', () async {
      // Without a sequence number the states compare equal, `BlocBuilder`
      // suppresses the rebuild, and the reticle silently fails to reappear.
      await withFocus(focus: true, exposure: false);

      await harness.cubit.focusAt(tapX: 200, tapY: 400, layout: coverLayout);
      final FocusRequest first = ready().focusRequest!;
      await harness.cubit.focusAt(tapX: 200, tapY: 400, layout: coverLayout);
      final FocusRequest second = ready().focusRequest!;

      expect(second.point, first.point);
      expect(second.sequence, greaterThan(first.sequence));
      expect(second, isNot(first));
    });
  });

  group('taps that map to nothing', () {
    test('a tap on a letterbox band is ignored entirely', () async {
      await withFocus(focus: true, exposure: false);

      await harness.cubit.focusAt(tapX: 200, tapY: 50, layout: containLayout);

      expect(session().focusPoints, isEmpty);
      expect(ready().focusRequest, isNull);
    });

    test('a tap outside the widget is ignored', () async {
      await withFocus(focus: true, exposure: false);

      await harness.cubit.focusAt(tapX: 900, tapY: 400, layout: coverLayout);

      expect(session().focusPoints, isEmpty);
    });

    test('focusing before the camera is ready does nothing', () async {
      harness = await CameraHarness.create(
        devices: <CameraDevice>[FakeCameraEngine.backCamera('0')],
      );

      await harness.cubit.focusAt(tapX: 200, tapY: 400, layout: coverLayout);

      expect(harness.cubit.state, isA<CameraInitial>());
    });
  });

  group('unsupported focus', () {
    test('is reported as unsupported, not as a failure', () async {
      await withFocus(focus: false, exposure: false);

      await harness.cubit.focusAt(tapX: 200, tapY: 400, layout: coverLayout);

      expect(ready().canFocus, isFalse);
      expect(ready().focusRequest!.outcome, FocusOutcome.unsupported);
      expect(
        ready().lastOperationError,
        isNull,
        reason: 'the hardware cannot do it — nothing is broken',
      );
    });

    test('no unsupported call is issued to the platform', () async {
      await withFocus(focus: false, exposure: false);

      await harness.cubit.focusAt(tapX: 200, tapY: 400, layout: coverLayout);

      expect(session().focusPoints, isEmpty);
    });
  });

  group('focus failure', () {
    test('does not tear down a camera that is still usable', () async {
      await withFocus(focus: true, exposure: false);
      session().focusFailure = cameraFailure(CameraErrorKind.focusFailed);

      await harness.cubit.focusAt(tapX: 200, tapY: 400, layout: coverLayout);

      expect(harness.cubit.state, isA<CameraReady>());
      expect(ready().focusRequest!.outcome, FocusOutcome.failed);
      expect(ready().lastOperationError?.kind, CameraErrorKind.focusFailed);
    });

    test('the camera keeps working afterwards', () async {
      await withFocus(focus: true, exposure: false);
      session().focusFailure = cameraFailure(CameraErrorKind.focusFailed);
      await harness.cubit.focusAt(tapX: 200, tapY: 400, layout: coverLayout);

      session().focusFailure = null;
      await harness.cubit.focusAt(tapX: 100, tapY: 200, layout: coverLayout);

      expect(ready().focusRequest!.outcome, FocusOutcome.applied);
      expect(ready().lastOperationError, isNull);
    });

    test('a focus landing after a release publishes nothing', () async {
      await withFocus(focus: true, exposure: false);

      await harness.cubit.release();
      await harness.cubit.focusAt(tapX: 200, tapY: 400, layout: coverLayout);

      expect(harness.cubit.state, isA<CameraReleased>());
    });
  });

  group('exposure pairing (FLT-CAM-018)', () {
    test('is set to the same point when the platform supports it', () async {
      await withFocus(focus: true, exposure: true);

      await harness.cubit.focusAt(tapX: 200, tapY: 400, layout: coverLayout);

      expect(session().exposurePoints, hasLength(1));
      expect(session().exposurePoints.single, session().focusPoints.single);
      expect(ready().focusRequest!.exposurePaired, isTrue);
    });

    test('is not attempted when the platform does not support it', () async {
      await withFocus(focus: true, exposure: false);

      await harness.cubit.focusAt(tapX: 200, tapY: 400, layout: coverLayout);

      expect(session().exposurePoints, isEmpty);
      expect(ready().focusRequest!.exposurePaired, isFalse);
      expect(ready().focusRequest!.outcome, FocusOutcome.applied);
    });

    test('a failed exposure does NOT erase the successful focus', () async {
      // The rule for a bonus: it may not damage the mandatory behaviour it sits
      // beside. The user's tap did what they asked; only the extra failed.
      await withFocus(focus: true, exposure: true);
      session().exposureFailure = cameraFailure(CameraErrorKind.exposureFailed);

      await harness.cubit.focusAt(tapX: 200, tapY: 400, layout: coverLayout);

      final FocusRequest request = ready().focusRequest!;
      expect(request.outcome, FocusOutcome.applied);
      expect(request.exposureFailed, isTrue);
      expect(request.exposurePaired, isFalse);
      expect(session().focusPoints, hasLength(1));
      expect(
        ready().lastOperationError,
        isNull,
        reason: 'a failed bonus is not an error the user needs told about',
      );
    });

    test('exposure is skipped when focus itself failed', () async {
      await withFocus(focus: true, exposure: true);
      session().focusFailure = cameraFailure(CameraErrorKind.focusFailed);

      await harness.cubit.focusAt(tapX: 200, tapY: 400, layout: coverLayout);

      expect(session().exposurePoints, isEmpty);
    });
  });
}
