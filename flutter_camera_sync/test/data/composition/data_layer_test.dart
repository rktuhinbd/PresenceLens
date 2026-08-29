// The shared composition root, and the worker's result mapping
// (FLT-SYNC-002, FLT-SYNC-004, ARCHITECTURE §6/§7).
//
// `buildDataLayer` itself needs `path_provider`, which needs a device, so what
// is exercised here is `assembleDataLayer` — the part that actually describes
// the object graph, and the part both composition roots share. The split exists
// so this test is possible without pretending a plugin ran.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:presence_lens_capture/data/api/mock_upload_api.dart';
import 'package:presence_lens_capture/data/composition/data_layer.dart';
import 'package:presence_lens_capture/data/sync/drain_outcome.dart';
import 'package:presence_lens_capture/data/sync/work_manager_sync_scheduler.dart';
import 'package:presence_lens_capture/domain/entities/batch_status.dart';
import 'package:presence_lens_capture/domain/entities/image_status.dart';
import 'package:presence_lens_capture/domain/entities/queued_image.dart';
import 'package:presence_lens_capture/domain/ports/sync_scheduler.dart';

import '../../support/fakes.dart';
import '../../support/queue_harness.dart';

void main() {
  late QueueHarness harness;
  late Directory capturesRoot;
  late MutableClock clock;

  final DateTime now = DateTime.utc(2026, 8, 29, 12);

  setUp(() async {
    harness = await QueueHarness.create();
    capturesRoot = Directory(p.join(harness.directory.path, 'captures'));
    clock = MutableClock(now);
  });

  tearDown(() async {
    await harness.dispose();
  });

  DataLayer build({required bool forBackground, MockScenario? scenario}) =>
      assembleDataLayer(
        database: harness.primary,
        capturesRoot: capturesRoot,
        forBackground: forBackground,
        scenario: scenario ?? MockScenario.alwaysSucceed,
        uploadLatency: Duration.zero,
        clock: clock,
      );

  test('the foreground graph can request a background drain', () {
    final DataLayer layer = build(forBackground: false);

    expect(layer.isBackground, isFalse);
    expect(layer.scheduler, isA<WorkManagerSyncScheduler>());
  });

  test('the worker graph cannot request entry work, only a continuation', () {
    // Re-registering entry work from inside a worker would put a second
    // scheduler against WorkManager's own backoff (`RS-04`). Asking for a
    // continuation is a different statement, and is allowed (`ADR-F19`).
    final DataLayer layer = build(forBackground: true);

    expect(layer.isBackground, isTrue);
    expect(layer.scheduler, isA<BackgroundSyncScheduler>());
  });

  test(
    'the background scheduler suppresses drains, forwards continuations',
    () async {
      final RecordingScheduler delegate = RecordingScheduler();
      final BackgroundSyncScheduler background = BackgroundSyncScheduler(
        delegate,
      );

      expect(await background.scheduleDrain(), SchedulingOutcome.suppressed);
      expect(
        delegate.scheduleCount,
        0,
        reason: 'the request must not reach the platform at all',
      );

      expect(
        await background.scheduleContinuation(),
        SchedulingOutcome.requested,
      );
      expect(delegate.continuationCount, 1);
    },
  );

  test('both roots describe the same object graph otherwise', () {
    // The two composition roots share one factory precisely so a background
    // task cannot quietly behave differently from the foreground.
    final DataLayer foreground = build(forBackground: false);
    final DataLayer background = build(forBackground: true);

    expect(background.queue.runtimeType, foreground.queue.runtimeType);
    expect(
      background.captureStore.runtimeType,
      foreground.captureStore.runtimeType,
    );
    expect(background.uploadApi.runtimeType, foreground.uploadApi.runtimeType);
    expect(
      background.queueProcessor.runtimeType,
      foreground.queueProcessor.runtimeType,
    );
  });

  test('the assembled graph drains a real queue end to end', () async {
    // Capture through the real use case, finish the batch, then drain — the
    // whole F1 pipeline, wired the way the app wires it.
    final DataLayer layer = build(forBackground: true);

    final File source = await File(
      p.join(harness.directory.path, 'shot.jpg'),
    ).writeAsString('bytes');

    await layer.queue.createDraftBatch(id: 'b1', createdAt: now);
    final QueuedImage captured = await layer.recordCapture(
      batchId: 'b1',
      sourcePath: source.path,
    );
    expect(File(captured.localPath).existsSync(), isTrue);

    await layer.queue.enqueueBatch('b1', queuedAt: now);
    final DrainOutcome outcome = await layer.queueProcessor.drain();

    expect(outcome.uploaded, 1);
    expect(outcome.disposition, DrainDisposition.drained);
    expect(
      (await layer.queue.imageById(captured.id))!.status,
      ImageStatus.uploaded,
    );
    expect((await layer.queue.batchById('b1'))!.status, BatchStatus.completed);
  });

  test('an undeliverable queue asks the platform to come back', () async {
    final DataLayer layer = build(
      forBackground: true,
      scenario: MockScenario.alwaysFailRetryable,
    );
    final List<QueuedImage> images = await harness.seedQueuedBatch(
      batchId: 'b1',
      count: 2,
    );
    for (final QueuedImage image in images) {
      await Directory(p.dirname(image.localPath)).create(recursive: true);
      await File(image.localPath).writeAsString('bytes');
    }

    final DrainOutcome outcome = await layer.queueProcessor.drain();

    expect(outcome.retryable, 2);
    expect(
      outcome.disposition,
      DrainDisposition.retryLater,
      reason: 'nothing was delivered, so the worker maps this to a retry',
    );
    expect(await layer.queue.outstandingCount(), 2);
  });
}
