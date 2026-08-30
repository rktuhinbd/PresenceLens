// `WIDGET` tier — navigation and accessibility.
//
// Two groups of claims that are easy to assert and expensive to lose:
//
// * navigation is **one-way outward** and never destroys an open batch, which is
//   the invariant `UX_SPEC.md` §3.1 promises in a table;
// * the controls carry the labels and the target sizes a screen-reader or
//   large-target user needs (`FLT-UX-002`, `FLT-UX-003`, `FLT-UX-013`).

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presence_lens_capture/domain/entities/camera_capabilities.dart';
import 'package:presence_lens_capture/domain/entities/camera_device.dart';
import 'package:presence_lens_capture/presentation/camera/camera_preview_screen.dart';
import 'package:presence_lens_capture/presentation/camera/widgets/camera_controls.dart';
import 'package:presence_lens_capture/presentation/camera/widgets/focus_reticle.dart';
import 'package:presence_lens_capture/presentation/camera/widgets/zoom_controls.dart';
import 'package:presence_lens_capture/presentation/uploads/upload_manager_screen.dart';

import '../support/app_harness.dart';
import '../support/fake_camera.dart';

final CameraCapabilities _versatile = CameraCapabilities(
  zoom: ZoomRange(min: 0.5, max: 10),
  focusPointSupported: true,
  exposurePointSupported: true,
  previewAspectRatio: 3 / 4,
);

void main() {
  group('navigation', () {
    testWidgets('camera to uploads and back, with the batch intact', (
      WidgetTester tester,
    ) async {
      final AppHarness harness = await AppHarness.create(
        capabilities: _versatile,
      );
      addTearDown(harness.dispose);
      usePhoneSurface(tester);

      harness.startSync();
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ShutterButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ShutterButton));
      await tester.pumpAndSettle();
      expect(find.text('Finish batch (2)'), findsOneWidget);

      await tester.tap(find.byType(UploadsEntry));
      await tester.pumpAndSettle();
      expect(find.byType(UploadManagerScreen), findsOneWidget);
      expect(find.byType(CameraPreviewScreen), findsNothing);

      await tester.pageBack();
      await tester.pumpAndSettle();

      // The invariant: there is no gesture, control or navigation path that
      // destroys an open batch as a side effect.
      expect(find.byType(CameraPreviewScreen), findsOneWidget);
      expect(find.text('Finish batch (2)'), findsOneWidget);
      expect(harness.batchCubit.state.imageCount, 2);
      expect(harness.queue.images, hasLength(2));
    });

    testWidgets('"Start new batch" returns to the camera', (
      WidgetTester tester,
    ) async {
      final AppHarness harness = await AppHarness.create(
        capabilities: _versatile,
      );
      addTearDown(harness.dispose);
      usePhoneSurface(tester);

      harness.startSync();
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      await tester.tap(find.byType(UploadsEntry));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open camera'));
      await tester.pumpAndSettle();

      expect(find.byType(CameraPreviewScreen), findsOneWidget);
    });

    testWidgets('the camera route is the root, so back leaves the app', (
      WidgetTester tester,
    ) async {
      final AppHarness harness = await AppHarness.create(
        capabilities: _versatile,
      );
      addTearDown(harness.dispose);
      usePhoneSurface(tester);

      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();

      // Deliberate, not accidental: the camera is a launch surface, and there is
      // nothing behind it. Nothing intercepts the system gesture, because there
      // is no unsaved work to guard — every capture is already durable
      // (`UX_SPEC.md` §3.1).
      final NavigatorState navigator = tester.state<NavigatorState>(
        find.byType(Navigator),
      );
      expect(navigator.canPop(), isFalse);
      expect(await navigator.maybePop(), isFalse);
      await tester.pumpAndSettle();
      expect(find.byType(CameraPreviewScreen), findsOneWidget);
    });
  });

  group('accessibility', () {
    testWidgets('every camera control carries a label and its value', (
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
      harness.startSync();
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ShutterButton));
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.byType(ShutterButton)).label,
        'Take photo',
      );
      expect(
        tester.getSemantics(find.byType(CameraSelectorButton)).label,
        'Switch camera',
      );
      expect(
        tester.getSemantics(find.byType(UploadsEntry)).label,
        'Pending uploads',
      );
      // The batch control announces what it will finish, so a screen-reader user
      // is not asked to press a number they cannot see.
      final SemanticsNode finish = tester.getSemantics(
        find.text('Finish batch (1)'),
      );
      expect(finish.label, 'Finish batch');
      expect(finish.value, '1 photo');
      expect(tester.getSemantics(find.byType(BatchThumbnail)).value, '1 photo');
      semantics.dispose();
    });

    testWidgets('zoom is fully operable without a pinch', (
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

      // `FLT-UX-013`: the slider and the presets are equal-status controls, not
      // fallbacks — someone who cannot perform a pinch loses nothing.
      expect(find.byType(ZoomSlider), findsOneWidget);
      expect(find.byType(ZoomPresetRow), findsOneWidget);
      // The value a screen reader reads out is the zoom itself, not a
      // percentage of a range nobody can see.
      final Slider slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.semanticFormatterCallback!(3.4), 'Zoom 3.4x');
      expect(slider.semanticFormatterCallback!(2), 'Zoom 2x');

      // And every preset pill is a labelled, selectable button.
      final SemanticsNode preset = tester.getSemantics(find.text('2x'));
      expect(preset.label, 'Zoom 2x');
      expect(preset.flagsCollection.isButton, isTrue);
      semantics.dispose();
    });

    testWidgets('interactive targets meet the 48 dp minimum', (
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

      harness.startSync();
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ShutterButton));
      await tester.pumpAndSettle();

      for (final Finder finder in <Finder>[
        find.byType(ShutterButton),
        find.byType(CameraSelectorButton),
        find.byType(BatchThumbnail),
        find.byType(UploadsEntry),
        find.byType(ZoomSlider),
      ]) {
        final Size size = tester.getSize(finder);
        expect(
          size.shortestSide,
          greaterThanOrEqualTo(48),
          reason: 'a control is below the 48 dp target minimum',
        );
      }
    });

    testWidgets('camera chrome survives a large text scale', (
      WidgetTester tester,
    ) async {
      final AppHarness harness = await AppHarness.create(
        capabilities: _versatile,
      );
      addTearDown(harness.dispose);
      usePhoneSurface(tester);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: harness.app(),
        ),
      );
      await tester.pumpAndSettle();

      // Labels are capped at 1.3× so a large accessibility setting cannot push
      // the preset row up over the preview (`UX_SPEC.md` §2.3). What matters is
      // that nothing overflows and every control is still there.
      expect(tester.takeException(), isNull);
      expect(find.byType(ShutterButton), findsOneWidget);
      expect(find.byType(ZoomPresetRow), findsOneWidget);
    });

    testWidgets('reduced motion keeps the feedback and drops the movement', (
      WidgetTester tester,
    ) async {
      final AppHarness harness = await AppHarness.create(
        capabilities: _versatile,
      );
      addTearDown(harness.dispose);
      usePhoneSurface(tester);

      await tester.pumpWidget(harness.app(reducedMotion: true));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(160, 380));
      await tester.pump();
      // Required feedback survives (`RU-03`).
      expect(find.byType(FocusReticle), findsOneWidget);

      await tester.tap(find.byType(ShutterButton));
      await tester.pumpAndSettle();

      // The count still increments, and it does so from the committed write —
      // the animation was never what advanced it.
      expect(find.text('Finish batch (1)'), findsOneWidget);
      expect(harness.batchCubit.state.imageCount, 1);
    });
  });
}
