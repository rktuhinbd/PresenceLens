import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presence_lens_capture/data/sync/connectivity_drain_trigger.dart';
import 'package:presence_lens_capture/data/sync/queue_processor.dart';
import 'package:presence_lens_capture/domain/entities/camera_capabilities.dart';
import 'package:presence_lens_capture/domain/entities/camera_device.dart';
import 'package:presence_lens_capture/domain/entities/failure_category.dart';
import 'package:presence_lens_capture/domain/entities/image_status.dart';
import 'package:presence_lens_capture/domain/entities/queued_image.dart';
import 'package:presence_lens_capture/domain/entities/upload_outcome.dart';
import 'package:presence_lens_capture/domain/ports/sync_scheduler.dart';
import 'package:presence_lens_capture/domain/ports/upload_api.dart';
import 'package:presence_lens_capture/domain/usecases/capture_into_batch.dart';
import 'package:presence_lens_capture/domain/usecases/finish_batch.dart';
import 'package:presence_lens_capture/domain/usecases/record_capture.dart';
import 'package:presence_lens_capture/presentation/batch/batch_cubit.dart';
import 'package:presence_lens_capture/presentation/camera/camera_cubit.dart';
import 'package:presence_lens_capture/presentation/camera/camera_preview_screen.dart';
import 'package:presence_lens_capture/presentation/platform/app_settings_launcher.dart';
import 'package:presence_lens_capture/presentation/theme/app_theme.dart';
import 'package:presence_lens_capture/presentation/uploads/sync_bloc.dart';
import 'package:presence_lens_capture/presentation/uploads/sync_event.dart';

import 'fake_camera.dart';
import 'fakes.dart';
import 'in_memory_upload_queue.dart';

/// Records "Open settings" requests instead of leaving the app.
///
/// The recovery path offered after repeated refusals has to be *exercisable*;
/// an untested recovery path is worse than none (`ADR-F22`).
class RecordingSettingsLauncher implements AppSettingsLauncher {
  /// How many times the settings screen was requested.
  int openCount = 0;

  /// What the platform should be said to have answered.
  bool result = true;

  @override
  Future<bool> openAppSettings() async {
    openCount++;
    return result;
  }
}

/// The whole application, assembled for a widget test.
///
/// **Real use cases, real cubits and blocs, real policies — a fake camera, a
/// fake transport, and an in-memory queue.** The queue is the one substitution
/// that is forced rather than chosen: `testWidgets` runs inside a fake-async
/// zone, so the real SQLite engine's file I/O never completes there
/// ([InMemoryUploadQueue] says so at length).
///
/// The consequence is stated rather than glossed: **a widget test in this file
/// proves rendering and wiring, never persistence.** The persistence rules are
/// proven against real SQLite in the `DATA` tier and in
/// `test/integration/`, which run as plain `test()` cases.
///
/// **Nothing here proves camera or background behaviour either.** No widget test
/// in this suite says anything about a real preview, a real focus motor, or
/// whether Android ran a worker; those stay `DEVICE`.
class AppHarness {
  AppHarness._({
    required this.engine,
    required this.store,
    required this.scheduler,
    required this.connectivity,
    required this.clock,
    required this.ids,
    required this.settings,
    required this.cameraCubit,
    required this.batchCubit,
    required this.syncBloc,
    required this.uploadApi,
    required InMemoryUploadQueue queue,
  }) : _queue = queue;

  /// Assembles the graph.
  ///
  /// [uploadApi] defaults to a transport that is never called, because most
  /// screens are asserted with nothing draining underneath them.
  static Future<AppHarness> create({
    List<CameraDevice>? devices,
    CameraCapabilities? capabilities,
    bool hasLink = true,
    bool withProcessor = false,
    UploadApi? uploadApi,
    SchedulingOutcomeOverride? scheduling,
  }) async {
    final InMemoryUploadQueue queue = InMemoryUploadQueue();
    final FakeCaptureStore store = FakeCaptureStore();
    final MutableClock clock = MutableClock(DateTime.utc(2026, 8, 30, 9));
    final SequentialIdGenerator ids = SequentialIdGenerator();
    final RecordingScheduler scheduler = RecordingScheduler();
    if (scheduling != null) {
      scheduler.drainOutcome = scheduling.drain;
    }
    final FakeConnectivity connectivity = FakeConnectivity(hasLinkNow: hasLink);

    final FakeCameraEngine engine = FakeCameraEngine(devices: devices);
    if (capabilities != null) {
      engine.defaultCapabilities = capabilities;
    }

    final RecordCapture recordCapture = RecordCapture(
      queue: queue,
      store: store,
      ids: ids,
      clock: clock,
    );

    final UploadApi api =
        uploadApi ??
        ScriptedUploadApi(
          (QueuedImage image, int _) =>
              UploadSucceeded(idempotencyKey: image.id),
        );

    final AppHarness harness = AppHarness._(
      engine: engine,
      store: store,
      scheduler: scheduler,
      connectivity: connectivity,
      clock: clock,
      ids: ids,
      uploadApi: api,
      settings: RecordingSettingsLauncher(),
      cameraCubit: CameraCubit(
        engine: engine,
        captureIntoBatch: CaptureIntoBatch(
          queue: queue,
          recordCapture: recordCapture,
          ids: ids,
          clock: clock,
        ),
      ),
      batchCubit: BatchCubit(
        queue: queue,
        finishBatch: FinishBatch(
          queue: queue,
          scheduler: scheduler,
          clock: clock,
        ),
      ),
      syncBloc: SyncBloc(
        queue: queue,
        scheduler: scheduler,
        connectivity: connectivity,
        queueProcessor: withProcessor
            ? QueueProcessor(queue: queue, api: api, store: store, clock: clock)
            : null,
        drainTrigger: ConnectivityDrainTrigger(
          connectivity: connectivity,
          scheduler: scheduler,
        ),
        completionHold: const Duration(milliseconds: 200),
      ),
      queue: queue,
    );
    await harness.batchCubit.start();
    return harness;
  }

  /// The camera the test drives.
  final FakeCameraEngine engine;

  /// Durable storage, faked so IO faults can be injected.
  final FakeCaptureStore store;

  /// Records every scheduling request.
  final RecordingScheduler scheduler;

  /// The advisory link signal, driven by the test.
  final FakeConnectivity connectivity;

  /// The clock every timestamp comes from.
  final MutableClock clock;

  /// Predictable ids, so paths can be asserted.
  final SequentialIdGenerator ids;

  /// The transport.
  final UploadApi uploadApi;

  /// Records "Open settings" requests.
  final RecordingSettingsLauncher settings;

  /// The camera state holder.
  final CameraCubit cameraCubit;

  /// The batch state holder.
  final BatchCubit batchCubit;

  /// The sync state holder.
  final SyncBloc syncBloc;

  final InMemoryUploadQueue _queue;

  /// The queue the screens read from.
  InMemoryUploadQueue get queue => _queue;

  /// Starts the sync presentation, as the app root does.
  void startSync() => syncBloc.add(const SyncStarted());

  /// Puts one already-captured image into [batchId].
  ///
  /// Seeds the state a previous session would have left behind, so a screen can
  /// be asserted without driving the shutter for it.
  Future<QueuedImage> seedCapture(
    String batchId,
    String imageId, {
    ImageStatus status = ImageStatus.draft,
    int attemptCount = 0,
    FailureCategory? lastFailure,
    Duration offset = Duration.zero,
  }) async {
    final QueuedImage image = QueuedImage(
      id: imageId,
      batchId: batchId,
      localPath: 'durable/$batchId/$imageId.jpg',
      capturedAt: clock.nowUtc().add(offset),
      status: status,
      attemptCount: attemptCount,
      lastFailure: lastFailure,
    );
    await queue.addCapture(image);
    return image;
  }

  /// The application tree, rooted at [home] or at the camera.
  Widget app({bool reducedMotion = false, Widget? home}) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<CameraCubit>.value(value: cameraCubit),
        BlocProvider<BatchCubit>.value(value: batchCubit),
        BlocProvider<SyncBloc>.value(value: syncBloc),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        // Applied *inside* the app so it survives the `MediaQuery` the
        // `MaterialApp` inserts from the view.
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reducedMotion),
          child: child ?? const SizedBox.shrink(),
        ),
        home: home ?? CameraPreviewScreen(settingsLauncher: settings),
      ),
    );
  }

  /// Closes everything.
  Future<void> dispose() async {
    await cameraCubit.close();
    await batchCubit.close();
    await syncBloc.close();
    await connectivity.dispose();
    await _queue.close();
  }
}

/// Which scheduling answer the fake platform should give.
class SchedulingOutcomeOverride {
  /// Creates an override.
  const SchedulingOutcomeOverride(this.drain);

  /// What `scheduleDrain` reports.
  final SchedulingOutcome drain;
}

/// Gives the test a phone-shaped surface.
///
/// The default 800×600 test window is a landscape tablet, and asserting a
/// portrait camera layout against it would be testing a geometry the app is
/// never used in.
void usePhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
