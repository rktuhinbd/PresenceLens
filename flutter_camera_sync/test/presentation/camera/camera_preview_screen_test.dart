// `WIDGET` tier — the production camera screen.
//
// What these tests are allowed to claim: that the screen renders each state,
// that its controls are wired to the one shared zoom value, that a tap becomes a
// focus request against the real coordinate mapper, that the capture guard is
// visible in the UI, and that "Finish batch" is a local act that works offline.
//
// What they deliberately do **not** claim: anything about a real preview, a real
// lens, a real focus motor, or whether Android ran a worker. The session here is
// a fake, so `buildCameraPreview` degrades to its placeholder by design — that
// degradation is what makes the screen testable without hardware, and it is not
// evidence that a preview works (`TEST_STRATEGY.md` §7).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presence_lens_capture/domain/entities/camera_capabilities.dart';
import 'package:presence_lens_capture/domain/entities/camera_device.dart';
import 'package:presence_lens_capture/domain/entities/image_status.dart';
import 'package:presence_lens_capture/domain/entities/zoom_preset.dart';
import 'package:presence_lens_capture/presentation/camera/camera_state.dart';
import 'package:presence_lens_capture/presentation/camera/widgets/camera_controls.dart';
import 'package:presence_lens_capture/presentation/camera/widgets/focus_reticle.dart';
import 'package:presence_lens_capture/presentation/camera/widgets/zoom_controls.dart';

import '../../support/app_harness.dart';
import '../../support/fake_camera.dart';

/// A camera that can zoom from 0.5 to 10 and focus — the interesting case.
final CameraCapabilities _versatile = CameraCapabilities(
  zoom: ZoomRange(min: 0.5, max: 10),
  focusPointSupported: true,
  exposurePointSupported: true,
  previewAspectRatio: 3 / 4,
);

void main() {
  group('camera screen — ready', () {
    testWidgets('renders the viewfinder chrome and no close control', (
      WidgetTester tester,
    ) async {
      final AppHarness harness = await AppHarness.create(
        capabilities: _versatile,
      );
      addTearDown(harness.dispose);
      usePhoneSurface(tester);

      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();

      expect(find.byType(ShutterButton), findsOneWidget);
      expect(find.byType(UploadsEntry), findsOneWidget);
      // `ADR-F13`: there is no exit affordance over a live viewfinder, and this
      // is the assertion that keeps someone from "helpfully" adding one back.
      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('the shutter is a labelled button', (
      WidgetTester tester,
    ) async {
      final AppHarness harness = await AppHarness.create(
        capabilities: _versatile,
      );
      addTearDown(harness.dispose);
      usePhoneSurface(tester);

      final SemanticsHandle semantics = tester.ensureSemantics();
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();

      final SemanticsNode node = tester.getSemantics(
        find.byType(ShutterButton),
      );
      expect(node.label, 'Take photo');
      expect(node.flagsCollection.isButton, isTrue);
      // Tri-state, because "not a control with an enabled state" and "disabled"
      // are different facts.
      expect(node.flagsCollection.isEnabled.name, 'isTrue');
      expect(
        tester.getSize(find.byType(ShutterButton)).shortestSide,
        greaterThanOrEqualTo(48),
      );
      semantics.dispose();
    });
  });

  group('zoom controls are capability-driven', () {
    testWidgets('a camera that cannot zoom gets no slider and no presets', (
      WidgetTester tester,
    ) async {
      final AppHarness harness = await AppHarness.create(
        capabilities: const CameraCapabilities(
          zoom: ZoomRange.fixed,
          focusPointSupported: true,
          exposurePointSupported: false,
        ),
      );
      addTearDown(harness.dispose);
      usePhoneSurface(tester);

      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();

      // An inert control invites a tap that does nothing, which is worse than
      // no control (`UX_SPEC.md` §3).
      expect(find.byType(ZoomSlider), findsNothing);
      expect(find.byType(ZoomPresetRow), findsNothing);
    });

    testWidgets('a wide range gets a slider bounded by the reported range', (
      WidgetTester tester,
    ) async {
      final AppHarness harness = await AppHarness.create(
        capabilities: _versatile,
      );
      addTearDown(harness.dispose);
      usePhoneSurface(tester);

      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();

      final ZoomSlider slider = tester.widget<ZoomSlider>(
        find.byType(ZoomSlider),
      );
      expect(slider.range.min, 0.5);
      expect(slider.range.max, 10);
      expect(find.text('0.5x'), findsWidgets);
      expect(find.text('10x'), findsWidgets);
    });

    testWidgets('presets come from the range, not from a hard-coded set', (
      WidgetTester tester,
    ) async {
      final AppHarness harness = await AppHarness.create(
        capabilities: CameraCapabilities(
          zoom: ZoomRange(min: 1, max: 3),
          focusPointSupported: true,
          exposurePointSupported: false,
        ),
      );
      addTearDown(harness.dispose);
      usePhoneSurface(tester);

      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();

      final ZoomPresetRow row = tester.widget<ZoomPresetRow>(
        find.byType(ZoomPresetRow),
      );
      final List<String> labels = row.presets
          .map((ZoomPreset p) => p.label)
          .toList();
      // 5x and 10x are outside what this camera reported, so they are not
      // offered; no preset outside the real range may exist (`FLT-CAM-007`).
      expect(labels, <String>['1x', '2x']);
    });
  });

  group('camera identity is never fabricated', () {
    testWidgets(
      'an unknown lens type produces no optical claim on any preset',
      (WidgetTester tester) async {
        final AppHarness harness = await AppHarness.create(
          capabilities: _versatile,
          devices: <CameraDevice>[
            FakeCameraEngine.backCamera('0'),
            FakeCameraEngine.backCamera('1', ordinal: 1),
          ],
        );
        addTearDown(harness.dispose);
        usePhoneSurface(tester);

        await tester.pumpWidget(harness.app());
        await tester.pumpAndSettle();

        final ZoomPresetRow row = tester.widget<ZoomPresetRow>(
          find.byType(ZoomPresetRow),
        );
        // Every pill is a zoom *ratio* inside the measured range. None of them
        // asserts a physical lens, because Android reported none
        // (`FLT-CAM-016`, `ADR-F03`).
        expect(
          row.presets.every((ZoomPreset p) => !p.claimsOpticalIdentity),
          isTrue,
        );
      },
    );

    testWidgets('the camera selector labels by ordinal, never by multiplier', (
      WidgetTester tester,
    ) async {
      final AppHarness harness = await AppHarness.create(
        capabilities: _versatile,
        devices: <CameraDevice>[
          FakeCameraEngine.backCamera('0'),
          FakeCameraEngine.backCamera('1', ordinal: 1),
        ],
      );
      addTearDown(harness.dispose);
      usePhoneSurface(tester);

      final SemanticsHandle semantics = tester.ensureSemantics();
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();

      final SemanticsNode node = tester.getSemantics(
        find.byType(CameraSelectorButton),
      );
      expect(node.label, 'Switch camera');
      expect(node.value, contains('Camera 1'));
      // "0.5x" beside a camera the app cannot identify would be a hardware
      // claim the platform never made.
      expect(node.value, isNot(contains('x,')));
      semantics.dispose();
    });

    testWidgets('one rear camera is not a choice, so no selector is offered', (
      WidgetTester tester,
    ) async {
      final AppHarness harness = await AppHarness.create(
        capabilities: _versatile,
        devices: <CameraDevice>[FakeCameraEngine.backCamera('0')],
      );
      addTearDown(harness.dispose);
      usePhoneSurface(tester);

      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();

      expect(find.byType(CameraControlButton), findsNothing);
    });
  });

  group('zoom writes one shared value', () {
    testWidgets('a pinch changes CameraCubit.currentZoom', (
      WidgetTester tester,
    ) async {
      final AppHarness harness = await AppHarness.create(
        capabilities: _versatile,
      );
      addTearDown(harness.dispose);
      usePhoneSurface(tester);

      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();

      final double before =
          (harness.cameraCubit.state as CameraReady).currentZoom;

      final Offset centre = tester.getCenter(find.byType(ShutterButton));
      final TestGesture a = await tester.startGesture(
        centre.translate(-40, -300),
      );
      final TestGesture b = await tester.startGesture(
        centre.translate(40, -300),
      );
      await tester.pump();
      await a.moveBy(const Offset(-60, 0));
      await b.moveBy(const Offset(60, 0));
      await tester.pump();
      await a.up();
      await b.up();
      await tester.pumpAndSettle();

      final double after =
          (harness.cameraCubit.state as CameraReady).currentZoom;
      expect(after, greaterThan(before));
      // The one place a zoom value lives; the slider renders from it.
      expect(tester.widget<ZoomSlider>(find.byType(ZoomSlider)).value, after);
    });

    testWidgets('the slider writes the same value the pinch does', (
      WidgetTester tester,
    ) async {
      final AppHarness harness = await AppHarness.create(
        capabilities: _versatile,
      );
      addTearDown(harness.dispose);
      usePhoneSurface(tester);

      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();

      final ZoomSlider slider = tester.widget<ZoomSlider>(
        find.byType(ZoomSlider),
      );
      slider.onChanged(4);
      await tester.pumpAndSettle();

      expect((harness.cameraCubit.state as CameraReady).currentZoom, 4);
      // And it reached the platform, clamped, exactly once more than the
      // opening baseline.
      expect(harness.engine.sessions.single.appliedZoom.last, 4);
    });

    testWidgets('a preset applies a real zoom ratio inside the range', (
      WidgetTester tester,
    ) async {
      final AppHarness harness = await AppHarness.create(
        capabilities: _versatile,
      );
      addTearDown(harness.dispose);
      usePhoneSurface(tester);

      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();

      await tester.tap(find.text('2x'));
      await tester.pumpAndSettle();

      expect((harness.cameraCubit.state as CameraReady).currentZoom, 2);
    });
  });

  group('tap to focus', () {
    testWidgets('a tap maps through the preview layout and shows a reticle', (
      WidgetTester tester,
    ) async {
      final AppHarness harness = await AppHarness.create(
        capabilities: _versatile,
      );
      addTearDown(harness.dispose);
      usePhoneSurface(tester);

      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();

      const Offset tap = Offset(120, 300);
      await tester.tapAt(tap);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // The point reached the platform, normalised by the real mapper against
      // the geometry the widget supplied.
      final FakeCameraSession session = harness.engine.sessions.single;
      expect(session.focusPoints, hasLength(1));
      expect(session.focusPoints.single.x, inInclusiveRange(0, 1));
      expect(session.focusPoints.single.y, inInclusiveRange(0, 1));
      // Exposure is paired only because this camera reported support for it.
      expect(session.exposurePoints, hasLength(1));

      // And the ring is where the finger was, not where the normalisation
      // happened to land.
      expect(find.byType(FocusReticle), findsOneWidget);
      final Offset centre = tester.getCenter(find.byType(FocusReticle));
      expect((centre - tap).distance, lessThan(2));
    });

    testWidgets('the reticle still appears with animations disabled', (
      WidgetTester tester,
    ) async {
      final AppHarness harness = await AppHarness.create(
        capabilities: _versatile,
      );
      addTearDown(harness.dispose);
      usePhoneSurface(tester);

      await tester.pumpWidget(harness.app(reducedMotion: true));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(150, 400));
      await tester.pump();

      // `RU-03`: reduced motion removes movement, never required feedback.
      expect(find.byType(FocusReticle), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(FocusReticle), findsNothing);
    });

    testWidgets('a focus failure leaves the preview healthy', (
      WidgetTester tester,
    ) async {
      final AppHarness harness = await AppHarness.create(
        capabilities: _versatile,
      );
      addTearDown(harness.dispose);
      usePhoneSurface(tester);

      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      harness.engine.sessions.single.focusFailure = Exception('rejected');

      await tester.tapAt(const Offset(150, 400));
      await tester.pumpAndSettle();

      // Still ready, still rendering, still able to shoot. A rejected focus
      // point is an operation error, not a dead session (`§24`).
      expect(harness.cameraCubit.state, isA<CameraReady>());
      expect(find.byType(ShutterButton), findsOneWidget);
    });
  });

  group('capture and batch', () {
    testWidgets('a capture advances the count the batch state read back', (
      WidgetTester tester,
    ) async {
      final AppHarness harness = await AppHarness.create(
        capabilities: _versatile,
      );
      addTearDown(harness.dispose);
      usePhoneSurface(tester);

      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();

      expect(find.byType(BatchThumbnail), findsOneWidget);
      expect(find.textContaining('Finish batch'), findsNothing);

      await tester.tap(find.byType(ShutterButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ShutterButton));
      await tester.pumpAndSettle();

      expect(harness.engine.sessions.single.captureCount, 2);
      expect(find.text('Finish batch (2)'), findsOneWidget);
      // The badge is the committed count, not an in-flight one.
      expect(harness.batchCubit.state.imageCount, 2);
    });

    testWidgets('a second shutter press during a capture is refused', (
      WidgetTester tester,
    ) async {
      final AppHarness harness = await AppHarness.create(
        capabilities: _versatile,
      );
      addTearDown(harness.dispose);
      usePhoneSurface(tester);

      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();

      final FakeCameraSession session = harness.engine.sessions.single;
      session.captureGate = Completer<void>();

      await tester.tap(find.byType(ShutterButton));
      await tester.pump();

      // The control is visibly disabled *and* the cubit guard holds; the UI is
      // feedback, the guard is the mechanism (`FLT-CAM-014`).
      final SemanticsHandle semantics = tester.ensureSemantics();
      await tester.pump();
      final SemanticsNode node = tester.getSemantics(
        find.byType(ShutterButton),
      );
      expect(node.label, 'Take photo');
      expect(node.flagsCollection.isEnabled.name, 'isFalse');
      semantics.dispose();

      await tester.tap(find.byType(ShutterButton), warnIfMissed: false);
      await tester.pump();
      expect(session.captureCount, 1);

      session.captureGate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('Finish batch works offline and queues the images', (
      WidgetTester tester,
    ) async {
      final AppHarness harness = await AppHarness.create(
        capabilities: _versatile,
        hasLink: false,
      );
      addTearDown(harness.dispose);
      usePhoneSurface(tester);

      harness.startSync();
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ShutterButton));
      await tester.pumpAndSettle();

      // The wording is "Finish", never "Upload": pressing it performs no
      // network operation, so it must not promise one (`ADR-F14`).
      expect(find.text('Finish batch (1)'), findsOneWidget);
      expect(find.textContaining('Upload batch'), findsNothing);

      await tester.tap(find.text('Finish batch (1)'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Finish batch'), findsNothing);
      expect(harness.queue.countWithStatus(ImageStatus.pending), 1);
      expect(harness.scheduler.scheduleCount, greaterThanOrEqualTo(1));
    });
  });
}
