import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/ports/capture_store.dart';
import '../../domain/ports/clock.dart';
import '../../domain/ports/connectivity_port.dart';
import '../../domain/ports/id_generator.dart';
import '../../domain/ports/sync_scheduler.dart';
import '../../domain/ports/upload_api.dart';
import '../../domain/ports/upload_queue.dart';
import '../../domain/usecases/capture_into_batch.dart';
import '../../domain/usecases/finish_batch.dart';
import '../../domain/usecases/record_capture.dart';
import '../api/mock_upload_api.dart';
import '../connectivity/connectivity_plus_adapter.dart';
import '../database/app_database.dart';
import '../database/upload_queue_dao.dart';
import '../identity/uuid_v4_generator.dart';
import '../storage/file_system_capture_store.dart';
import '../sync/queue_processor.dart';
import '../sync/work_manager_sync_scheduler.dart';

/// Everything below the presentation layer, assembled.
///
/// Two isolates build one of these each — the UI isolate at launch, the
/// WorkManager isolate on every background invocation — and they share **no
/// memory**. The only things they have in common are the SQLite file and the
/// captures directory, and both are *derived* in each isolate rather than
/// passed between them (`ARCHITECTURE.md` §6).
class DataLayer {
  /// Wraps an assembled object graph.
  const DataLayer({
    required this.database,
    required this.queue,
    required this.captureStore,
    required this.uploadApi,
    required this.connectivity,
    required this.queueProcessor,
    required this.scheduler,
    required this.recordCapture,
    required this.captureIntoBatch,
    required this.finishBatch,
    required this.clock,
    required this.idGenerator,
    required this.isBackground,
  });

  /// The open database connection owned by this isolate.
  final Database database;

  /// The durable queue.
  final UploadQueue queue;

  /// Durable image storage.
  final CaptureStore captureStore;

  /// The upload seam.
  final UploadApi uploadApi;

  /// Advisory connectivity.
  final ConnectivityPort connectivity;

  /// The drain loop.
  final QueueProcessor queueProcessor;

  /// How a drain — or a continuation — is requested from the platform.
  ///
  /// In the background isolate this is a [BackgroundSyncScheduler]: it forwards
  /// a continuation and suppresses a request for entry work, so a worker cannot
  /// re-register itself against WorkManager's own backoff (`RS-04`).
  final SyncScheduler scheduler;

  /// Capture ingestion: file first, then row. Schedules nothing — a `DRAFT`
  /// image is not uploadable (`ADR-F21`).
  final RecordCapture recordCapture;

  /// The camera's entry point: open-or-join the draft batch, then record.
  ///
  /// Assembled here rather than inside `CameraCubit` so the cubit stays a
  /// sequencer and never learns what a database is (`ARCHITECTURE.md` §5).
  final CaptureIntoBatch captureIntoBatch;

  /// Closing a batch: durable transaction first, then the drain request.
  ///
  /// The app's only user-driven entry-scheduling call site.
  final FinishBatch finishBatch;

  /// The clock every timestamp comes from.
  final Clock clock;

  /// The source of image and batch ids.
  final IdGenerator idGenerator;

  /// Whether this graph was built inside the background isolate.
  final bool isBackground;

  /// Closes the isolate-local resources.
  ///
  /// The background isolate must do this when its task ends: its connection is
  /// torn down with the engine, and leaving it open is a file handle held for
  /// no reason. The UI isolate holds its graph for the process lifetime.
  Future<void> close() async {
    final UploadQueue q = queue;
    if (q is UploadQueueDao) {
      await q.close();
    }
    await database.close();
  }
}

/// Builds the data layer for one isolate.
///
/// This function is the **only** place the object graph is described. Both
/// composition roots call it, which is what stops the UI's wiring and the
/// worker's wiring drifting apart — a drift that would show up as a background
/// task quietly doing something different from the foreground.
///
/// The caller must have initialised the Flutter binding first: `sqflite` and
/// `path_provider` are plugins, and in the background isolate that binding is
/// established by `Workmanager().executeTask`.
Future<DataLayer> buildDataLayer({required bool forBackground}) async {
  final Directory documents = await getApplicationDocumentsDirectory();
  final Directory captures = Directory(p.join(documents.path, 'captures'));

  final String databasePath = p.join(
    await getDatabasesPath(),
    AppDatabase.fileName,
  );
  final Database database = await AppDatabase.open(
    databaseFactory: databaseFactory,
    path: databasePath,
  );

  return assembleDataLayer(
    database: database,
    capturesRoot: captures,
    forBackground: forBackground,
  );
}

/// Assembles the graph over an already-open [database] and [capturesRoot].
///
/// Split out from [buildDataLayer] so integration tests can drive the real
/// graph — real DAO, real processor, real store — against a temporary
/// directory and the host SQLite engine, without needing `path_provider` and
/// therefore without needing a device.
DataLayer assembleDataLayer({
  required Database database,
  required Directory capturesRoot,
  required bool forBackground,
  MockScenario scenario = MockScenario.offlineAware,
  Duration uploadLatency = MockUploadApi.defaultLatency,
  Clock clock = const SystemClock(),
  SyncScheduler? scheduler,
}) {
  final UploadQueueDao queue = UploadQueueDao(database);
  final CaptureStore store = FileSystemCaptureStore(root: capturesRoot);
  final ConnectivityPort connectivity = ConnectivityPlusAdapter();
  final IdGenerator ids = UuidV4Generator();

  final UploadApi api = MockUploadApi(
    scenario: scenario,
    connectivity: connectivity,
    latency: uploadLatency,
  );

  // Shared by both capture use cases: `CaptureIntoBatch` delegates to it rather
  // than reimplementing the file-then-row ordering and its compensation.
  final RecordCapture recordCapture = RecordCapture(
    queue: queue,
    store: store,
    ids: ids,
    clock: clock,
  );

  // The worker may ask for a *continuation* but never for entry work — see
  // `BackgroundSyncScheduler`. Injectable so a host test can drive the
  // scheduling decisions without reaching the plugin.
  final SyncScheduler resolvedScheduler =
      scheduler ??
      (forBackground
          ? BackgroundSyncScheduler(WorkManagerSyncScheduler())
          : WorkManagerSyncScheduler());

  return DataLayer(
    database: database,
    queue: queue,
    captureStore: store,
    uploadApi: api,
    connectivity: connectivity,
    queueProcessor: QueueProcessor(
      queue: queue,
      api: api,
      store: store,
      clock: clock,
    ),
    scheduler: resolvedScheduler,
    recordCapture: recordCapture,
    captureIntoBatch: CaptureIntoBatch(
      queue: queue,
      recordCapture: recordCapture,
      ids: ids,
      clock: clock,
    ),
    finishBatch: FinishBatch(
      queue: queue,
      scheduler: resolvedScheduler,
      clock: clock,
    ),
    clock: clock,
    idGenerator: ids,
    isBackground: forBackground,
  );
}
