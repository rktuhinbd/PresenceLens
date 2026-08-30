import 'package:presence_lens_capture/data/database/upload_queue_dao.dart';
import 'package:presence_lens_capture/domain/entities/camera_capabilities.dart';
import 'package:presence_lens_capture/domain/entities/camera_device.dart';
import 'package:presence_lens_capture/domain/usecases/capture_into_batch.dart';
import 'package:presence_lens_capture/domain/usecases/record_capture.dart';
import 'package:presence_lens_capture/presentation/camera/camera_cubit.dart';

import 'fake_camera.dart';
import 'fakes.dart';
import 'queue_harness.dart';

/// Everything a camera test needs, assembled once.
///
/// The capture path is wired to the **real** DAO over a real SQLite database
/// rather than to a stub queue. That is deliberate: the claims that repeated
/// captures join one draft batch, and that a `DRAFT` capture schedules nothing,
/// are only worth making against the persistence rules that actually ship
/// (`TEST_STRATEGY.md` §2).
class CameraHarness {
  CameraHarness._({
    required this.engine,
    required this.cubit,
    required this.store,
    required this.scheduler,
    required this.clock,
    required this.ids,
    required QueueHarness queue,
  }) : _queue = queue;

  /// Builds a harness. Close it with [dispose].
  static Future<CameraHarness> create({
    List<CameraDevice>? devices,
    CameraCapabilities? capabilities,
  }) async {
    final QueueHarness queue = await QueueHarness.create();
    final UploadQueueDao dao = queue.dao;
    final FakeCaptureStore store = FakeCaptureStore();
    final MutableClock clock = MutableClock(DateTime.utc(2026, 8, 30, 9));
    final SequentialIdGenerator ids = SequentialIdGenerator();
    final RecordingScheduler scheduler = RecordingScheduler();

    final FakeCameraEngine engine = FakeCameraEngine(devices: devices);
    if (capabilities != null) {
      engine.defaultCapabilities = capabilities;
    }

    final CameraCubit cubit = CameraCubit(
      engine: engine,
      captureIntoBatch: CaptureIntoBatch(
        queue: dao,
        recordCapture: RecordCapture(
          queue: dao,
          store: store,
          ids: ids,
          clock: clock,
        ),
        ids: ids,
        clock: clock,
      ),
    );

    return CameraHarness._(
      engine: engine,
      cubit: cubit,
      store: store,
      scheduler: scheduler,
      clock: clock,
      ids: ids,
      queue: queue,
    );
  }

  /// The camera the test drives.
  final FakeCameraEngine engine;

  /// The cubit under test.
  final CameraCubit cubit;

  /// Durable storage, faked so IO failures can be injected.
  final FakeCaptureStore store;

  /// Records scheduling requests.
  ///
  /// It is wired to nothing on purpose. A `DRAFT` capture must not ask for a
  /// drain, and the way to prove that is to hold a scheduler that the capture
  /// path has no route to (`ADR-F21`).
  final RecordingScheduler scheduler;

  /// The clock the capture timestamps come from.
  final MutableClock clock;

  /// Predictable ids, so paths and batch ids can be asserted.
  final SequentialIdGenerator ids;

  final QueueHarness _queue;

  /// The real DAO over real SQLite.
  UploadQueueDao get dao => _queue.dao;

  /// Closes the cubit and the database.
  Future<void> dispose() async {
    await cubit.close();
    await _queue.dispose();
  }
}
