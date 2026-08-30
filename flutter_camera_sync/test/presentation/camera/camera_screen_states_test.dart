// `WIDGET` tier — the camera screen's designed failure states.
//
// The claim every one of these makes, and the reason they exist as a group:
// **the queue is never trapped behind a broken camera.** A user whose camera
// will not open must still be able to reach the photographs they already took,
// and the Pending Uploads entry is therefore asserted in each state rather than
// once (`UX_SPEC.md` §3, `FLT-ERR-001` … `FLT-ERR-004`).

import 'package:flutter_test/flutter_test.dart';
import 'package:presence_lens_capture/domain/entities/camera_device.dart';
import 'package:presence_lens_capture/domain/entities/camera_error.dart';
import 'package:presence_lens_capture/presentation/camera/camera_state.dart';
import 'package:presence_lens_capture/presentation/camera/widgets/camera_controls.dart';
import 'package:presence_lens_capture/presentation/camera/widgets/camera_status_panel.dart';

import '../../support/app_harness.dart';
import '../../support/fake_camera.dart';

void main() {
  group('permission refused', () {
    testWidgets('offers to ask again, and keeps the queue reachable', (
      WidgetTester tester,
    ) async {
      final AppHarness harness = await AppHarness.create();
      addTearDown(harness.dispose);
      usePhoneSurface(tester);
      harness.engine.openFailure = cameraFailure(
        CameraErrorKind.permissionDenied,
      );

      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();

      expect(harness.cameraCubit.state, isA<CameraPermissionDenied>());
      expect(find.text('Camera access is off'), findsOneWidget);
      expect(find.text('Allow camera'), findsOneWidget);
      // The single most important detail on this screen.
      expect(find.byType(UploadsEntry), findsOneWidget);
    });

    testWidgets('a first refusal does not offer settings', (
      WidgetTester tester,
    ) async {
      final AppHarness harness = await AppHarness.create();
      addTearDown(harness.dispose);
      usePhoneSurface(tester);
      harness.engine.openFailure = cameraFailure(
        CameraErrorKind.permissionDenied,
      );

      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();

      // One refusal is not evidence of anything. Offering a settings trip here
      // would imply a verdict the platform never gave (`ADR-F22`).
      expect(find.text('Open settings'), findsNothing);
    });

    testWidgets('repeated refusals widen the offer to include settings', (
      WidgetTester tester,
    ) async {
      final AppHarness harness = await AppHarness.create();
      addTearDown(harness.dispose);
      usePhoneSurface(tester);
      harness.engine.openFailure = cameraFailure(
        CameraErrorKind.permissionDenied,
      );

      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Allow camera'));
      await tester.pumpAndSettle();

      // An escalation of what is *offered*, never a claim about the OS verdict.
      // The copy must still not assert permanence.
      expect(find.text('Open settings'), findsOneWidget);
      expect(find.textContaining('permanently'), findsNothing);
      expect(
        (harness.cameraCubit.state as CameraPermissionDenied)
            .isPermanentPerPlatform,
        isFalse,
      );

      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();
      expect(harness.settings.openCount, 1);
    });

    testWidgets('granting after a refusal recovers without leaving', (
      WidgetTester tester,
    ) async {
      final AppHarness harness = await AppHarness.create();
      addTearDown(harness.dispose);
      usePhoneSurface(tester);
      harness.engine.openFailureOnce = cameraFailure(
        CameraErrorKind.permissionDenied,
      );

      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      expect(find.text('Camera access is off'), findsOneWidget);

      await tester.tap(find.text('Allow camera'));
      await tester.pumpAndSettle();

      expect(harness.cameraCubit.state, isA<CameraReady>());
      expect(find.byType(ShutterButton), findsOneWidget);
    });
  });

  group('hardware states', () {
    testWidgets('a device with no rear camera says so and offers no retry', (
      WidgetTester tester,
    ) async {
      final AppHarness harness = await AppHarness.create(
        devices: <CameraDevice>[FakeCameraEngine.frontCamera('1')],
      );
      addTearDown(harness.dispose);
      usePhoneSurface(tester);

      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();

      expect(find.text('No rear camera'), findsOneWidget);
      // Retrying cannot add hardware, so no retry is offered — an action that
      // cannot work is worse than none.
      expect(find.byType(CameraPanelAction), findsNothing);
      expect(find.byType(UploadsEntry), findsOneWidget);
    });

    testWidgets('an initialisation failure is recoverable in place', (
      WidgetTester tester,
    ) async {
      final AppHarness harness = await AppHarness.create();
      addTearDown(harness.dispose);
      usePhoneSurface(tester);
      harness.engine.openFailureOnce = cameraFailure(
        CameraErrorKind.initializationFailed,
      );

      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();

      expect(find.text("Camera didn't start"), findsOneWidget);
      // The plugin's own exception text is never shown; it is not copy.
      expect(find.textContaining('Exception'), findsNothing);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(harness.cameraCubit.state, isA<CameraReady>());
    });

    testWidgets('an enumeration failure is a named state, not a crash', (
      WidgetTester tester,
    ) async {
      final AppHarness harness = await AppHarness.create();
      addTearDown(harness.dispose);
      usePhoneSurface(tester);
      harness.engine.enumerationFailure = cameraFailure(
        CameraErrorKind.cameraUnavailable,
      );

      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();

      expect(find.text("Camera isn't available"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('queued work is visible from a broken camera', () {
    testWidgets('the reassurance names the queued count', (
      WidgetTester tester,
    ) async {
      final AppHarness harness = await AppHarness.create();
      addTearDown(harness.dispose);
      usePhoneSurface(tester);
      harness.engine.openFailure = cameraFailure(
        CameraErrorKind.permissionDenied,
      );

      // Two photographs captured before access was revoked.
      await harness.queue.createDraftBatch(
        id: 'b1',
        createdAt: DateTime.utc(2026, 8, 30, 8),
      );
      await harness.seedCapture('b1', 'i1');
      await harness.seedCapture('b1', 'i2');
      await harness.queue.enqueueBatch(
        'b1',
        queuedAt: DateTime.utc(2026, 8, 30, 8, 30),
      );

      harness.startSync();
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();

      expect(find.text('Your 2 queued photos are safe'), findsOneWidget);
      final UploadsEntry entry = tester.widget<UploadsEntry>(
        find.byType(UploadsEntry),
      );
      expect(entry.pendingCount, 2);
    });
  });
}
