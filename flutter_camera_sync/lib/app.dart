import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'data/camera/camera_x_adapter.dart';
import 'data/composition/data_layer.dart';
import 'data/sync/connectivity_drain_trigger.dart';
import 'domain/ports/camera_engine.dart';
import 'presentation/batch/batch_cubit.dart';
import 'presentation/camera/camera_cubit.dart';
import 'presentation/camera/camera_preview_screen.dart';
import 'presentation/platform/app_settings_launcher.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/uploads/sync_bloc.dart';
import 'presentation/uploads/sync_event.dart';

/// Rebuilds the application after app-private storage is available.
typedef ApplicationBootstrap = Future<Widget> Function();

/// Receives bootstrap diagnostics without putting them in the production UI.
typedef StartupErrorReporter =
    void Function(Object error, StackTrace stackTrace);

/// Owns the one recoverable boundary before the camera application exists.
///
/// A failed attempt keeps the camera unavailable, reports the original error
/// and stack to the runtime log, and offers a real retry of the same composition
/// root. No durable state is deleted as part of recovery.
class StartupBootstrapApp extends StatefulWidget {
  /// Creates the startup boundary.
  const StartupBootstrapApp({
    required this.bootstrap,
    this.errorReporter,
    super.key,
  });

  /// Builds the complete application over its app-private data layer.
  final ApplicationBootstrap bootstrap;

  /// Optional test seam for observing a failure without changing global logs.
  final StartupErrorReporter? errorReporter;

  @override
  State<StartupBootstrapApp> createState() => _StartupBootstrapAppState();
}

class _StartupBootstrapAppState extends State<StartupBootstrapApp> {
  Widget _child = const _StartupLoadingApp();

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap(showLoading: false));
  }

  Future<void> _bootstrap({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _child = const _StartupLoadingApp();
      });
    }

    try {
      final Widget application = await widget.bootstrap();
      if (!mounted) {
        return;
      }
      setState(() {
        _child = application;
      });
    } catch (error, stackTrace) {
      (widget.errorReporter ?? _reportStartupError)(error, stackTrace);
      if (!mounted) {
        return;
      }
      setState(() {
        _child = StartupFailureApp(
          onRetry: () {
            unawaited(_bootstrap());
          },
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) => _child;
}

void _reportStartupError(Object error, StackTrace stackTrace) {
  assert(() {
    debugPrint('PresenceLens bootstrap failed: $error');
    debugPrintStack(
      label: 'PresenceLens bootstrap stack',
      stackTrace: stackTrace,
    );
    return true;
  }());
  FlutterError.reportError(
    FlutterErrorDetails(
      exception: error,
      stack: stackTrace,
      library: 'PresenceLens bootstrap',
      context: ErrorDescription(
        'while opening app-private storage and assembling the data layer',
      ),
    ),
  );
}

class _StartupLoadingApp extends StatelessWidget {
  const _StartupLoadingApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PresenceLens Capture',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            semanticsLabel: 'Opening local storage',
          ),
        ),
      ),
    );
  }
}

/// The application root: themes, the three state holders, and the camera route.
///
/// **The composition root of the UI isolate.** Every dependency below the
/// presentation layer arrives as one already-assembled [DataLayer], built by the
/// same factory the background isolate uses — which is what stops the two
/// wirings drifting apart into a worker that quietly does something else
/// (`ARCHITECTURE.md` §6).
///
/// The three state holders are provided above the navigator on purpose. The
/// camera's draft batch and the queue's state must survive a trip to Pending
/// Uploads and back; scoping them to a route would discard exactly the thing
/// `UX_SPEC.md` §3.1 promises is never discarded.
class PresenceLensCaptureApp extends StatelessWidget {
  /// Creates the application root over an assembled [dataLayer].
  const PresenceLensCaptureApp({
    required this.dataLayer,
    this.cameraEngine,
    this.settingsLauncher,
    super.key,
  });

  /// Everything below the presentation layer.
  final DataLayer dataLayer;

  /// The camera hardware. Defaults to the real plugin adapter; injected by
  /// widget tests, which have no device.
  final CameraEngine? cameraEngine;

  /// How "Open settings" reaches the OS.
  final AppSettingsLauncher? settingsLauncher;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<CameraCubit>(
          create: (BuildContext context) => CameraCubit(
            engine: cameraEngine ?? CameraXAdapter(),
            captureIntoBatch: dataLayer.captureIntoBatch,
          ),
        ),
        BlocProvider<BatchCubit>(
          create: (BuildContext context) {
            final BatchCubit cubit = BatchCubit(
              queue: dataLayer.queue,
              finishBatch: dataLayer.finishBatch,
            );
            // Picks up a `DRAFT` batch left behind by a previous process, with
            // its true count, so a killed app resumes the batch it was filling.
            unawaited(cubit.start());
            return cubit;
          },
        ),
        BlocProvider<SyncBloc>(
          create: (BuildContext context) {
            final SyncBloc bloc = SyncBloc(
              queue: dataLayer.queue,
              scheduler: dataLayer.scheduler,
              connectivity: dataLayer.connectivity,
              queueProcessor: dataLayer.queueProcessor,
              drainTrigger: ConnectivityDrainTrigger(
                connectivity: dataLayer.connectivity,
                scheduler: dataLayer.scheduler,
              ),
            );
            // Startup reconciliation (`FLT-SYNC-012`, closing `RS-11`): durable
            // work found at launch is rescheduled here rather than waiting for
            // the user to finish another batch.
            bloc.add(const SyncStarted());
            return bloc;
          },
        ),
      ],
      child: MaterialApp(
        title: 'PresenceLens Capture',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: CameraPreviewScreen(settingsLauncher: settingsLauncher),
      ),
    );
  }
}

/// What the user sees if the app cannot assemble its own storage.
///
/// A database or documents directory that will not open must not present as a
/// camera that silently loses photographs. The retry re-runs bootstrap without
/// deleting the database or any queued capture (`GR-4`).
class StartupFailureApp extends StatelessWidget {
  /// Creates the failure shell.
  const StartupFailureApp({required this.onRetry, super.key});

  /// Re-runs the application and data-layer composition root.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PresenceLens Capture',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: Builder(
        builder: (BuildContext context) {
          final ThemeData theme = Theme.of(context);
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.sd_card_alert_outlined,
                      size: 44,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Storage isn't available",
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'PresenceLens could not open its local store, so it '
                      'cannot guarantee a captured photo would be kept. '
                      'The camera will stay unavailable until durable storage '
                      'is ready.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
