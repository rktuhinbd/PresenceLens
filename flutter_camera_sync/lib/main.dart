/// Application entry point for PresenceLens Capture.
///
/// Task 2 of the Intelligent Machines Senior App Developer assessment: a custom
/// camera screen and a resilient upload queue.
///
/// The production UI (`CameraPreviewScreen` and the Pending Uploads manager) is
/// **not implemented yet**. Its visual direction was approved on 2026-08-29 and
/// is specified in `docs/flutter/UX_SPEC.md`, with the approved static
/// prototypes in `docs/flutter/design/`; building it is gates F3 and F5 of
/// `docs/flutter/EXECUTION_PLAN.md`. What ships here is the minimum shell needed
/// to keep `flutter analyze`, `flutter test` and `flutter build apk` meaningful
/// gates until then — plus the background-sync bootstrap, which has to exist
/// before the UI does because the worker isolate does not depend on it.
library;

import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';

import 'sync_worker_entrypoint.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _bootstrapBackgroundSync();
  runApp(const PresenceLensCaptureApp());
}

/// Registers the WorkManager callback dispatcher for this process.
///
/// Registration only — nothing is scheduled here. A drain is requested when
/// there is something to drain (on finishing a batch, on resume, on regaining a
/// link); scheduling one unconditionally at launch would ask the OS to wake a
/// worker for an empty queue.
///
/// A failure is swallowed on purpose. If the plugin cannot initialise, the app
/// must still start and must still be able to capture: images are made durable
/// by the filesystem and the database, not by the scheduler, and a foreground
/// drain still works.
Future<void> _bootstrapBackgroundSync() async {
  try {
    await Workmanager().initialize(syncCallbackDispatcher);
  } catch (_) {
    // Left to the next launch. Captures already queued are unaffected.
  }
}

/// Root widget. Owns the theme and the (currently placeholder) home route.
class PresenceLensCaptureApp extends StatelessWidget {
  /// Creates the application root.
  const PresenceLensCaptureApp({super.key});

  /// Seed colour for the Material 3 scheme.
  ///
  /// Shared with the native attendance app so the two read as one product
  /// family. The full token set is specified in `docs/flutter/UX_SPEC.md` and
  /// is applied when the production UI is unlocked.
  static const Color seedColor = Color(0xFF00A884);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PresenceLens Capture',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: seedColor)),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
      ),
      home: const _PlaceholderHomeScreen(),
    );
  }
}

/// Placeholder home route shown until the production UI is built.
///
/// This exists so the app builds and launches before the feature gates. It is
/// replaced wholesale by `CameraPreviewScreen` and is not a design artefact —
/// the approved design lives in `docs/flutter/design/`.
class _PlaceholderHomeScreen extends StatelessWidget {
  const _PlaceholderHomeScreen();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.photo_camera_outlined,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'PresenceLens Capture',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Camera and sync UI not implemented yet.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
