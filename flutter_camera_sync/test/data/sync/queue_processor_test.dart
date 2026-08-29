// The drain loop, over the REAL DAO and the REAL SQLite engine.
//
// Only the transport and the filesystem are faked, because those are the two
// things a host cannot supply honestly. Everything the processor actually
// depends on — the atomic claim, the transactions, the batch aggregate — is the
// production code.
//
// Covers FLT-SYNC-003, FLT-SYNC-004, FLT-SYNC-006, FLT-SYNC-013, FLT-SYNC-016,
// FLT-ERR-007 and invariants I6, I7, I10.

import 'package:flutter_test/flutter_test.dart';
import 'package:presence_lens_capture/data/database/upload_queue_dao.dart';
import 'package:presence_lens_capture/data/sync/drain_outcome.dart';
import 'package:presence_lens_capture/data/sync/queue_processor.dart';
import 'package:presence_lens_capture/domain/entities/batch_status.dart';
import 'package:presence_lens_capture/domain/entities/failure_category.dart';
import 'package:presence_lens_capture/domain/entities/image_status.dart';
import 'package:presence_lens_capture/domain/entities/queued_image.dart';
import 'package:presence_lens_capture/domain/entities/upload_outcome.dart';
import 'package:presence_lens_capture/domain/policies/retention_policy.dart';
import 'package:presence_lens_capture/domain/policies/stale_claim_policy.dart';
import 'package:sqflite/sqflite.dart';

import '../../support/fakes.dart';
import '../../support/queue_harness.dart';

void main() {
  late QueueHarness harness;
  late FakeCaptureStore store;
  late MutableClock clock;

  final DateTime start = DateTime.utc(2026, 8, 29, 12);

  setUp(() async {
    harness = await QueueHarness.create();
    store = FakeCaptureStore();
    clock = MutableClock(start);
  });

  tearDown(() async {
    await harness.dispose();
  });

  /// Seeds a finished batch and tells the fake store its files exist.
  Future<List<QueuedImage>> seed({
    required String batchId,
    required int count,
    DateTime? firstCapturedAt,
  }) async {
    final List<QueuedImage> images = await harness.seedQueuedBatch(
      batchId: batchId,
      count: count,
      firstCapturedAt: firstCapturedAt,
    );
    for (final QueuedImage image in images) {
      store.files.add(image.localPath);
    }
    return images;
  }

  QueueProcessor processorWith(
    ScriptedUploadApi api, {
    RetentionPolicy retention = const RetentionPolicy(),
  }) => QueueProcessor(
    queue: harness.dao,
    api: api,
    store: store,
    clock: clock,
    retentionPolicy: retention,
  );

  ScriptedUploadApi alwaysSucceeds() => ScriptedUploadApi(
    (QueuedImage image, int _) => UploadSucceeded(idempotencyKey: image.id),
  );

  ScriptedUploadApi alwaysFails(FailureCategory category) => ScriptedUploadApi(
    (QueuedImage image, int callIndex) => UploadFailed(category),
  );

  group('draining successfully', () {
    test('an empty queue is idle, and nothing is rescheduled', () async {
      final ScriptedUploadApi api = alwaysSucceeds();

      final DrainOutcome outcome = await processorWith(api).drain();

      expect(outcome, DrainOutcome.idle);
      expect(outcome.disposition, DrainDisposition.idle);
      expect(api.callCount, 0);
    });

    test('drains every item in a batch and completes it', () async {
      await seed(batchId: 'b1', count: 3);
      final ScriptedUploadApi api = alwaysSucceeds();

      final DrainOutcome outcome = await processorWith(api).drain();

      expect(outcome.uploaded, 3);
      expect(outcome.processed, 3);
      expect(outcome.workRemaining, isFalse);
      expect(outcome.disposition, DrainDisposition.drained);
      expect(outcome.stop, DrainStop.queueExhausted);
      expect(
        (await harness.dao.batchById('b1'))!.status,
        BatchStatus.completed,
      );
    });

    test('drains several batches, oldest capture first', () async {
      await seed(
        batchId: 'newer',
        count: 2,
        firstCapturedAt: DateTime.utc(2026, 8, 29, 11),
      );
      await seed(
        batchId: 'older',
        count: 2,
        firstCapturedAt: DateTime.utc(2026, 8, 29, 9),
      );
      final ScriptedUploadApi api = alwaysSucceeds();

      final DrainOutcome outcome = await processorWith(api).drain();

      expect(outcome.uploaded, 4);
      expect(api.calls.map((QueuedImage i) => i.id).toList(), <String>[
        'older-image-0',
        'older-image-1',
        'newer-image-0',
        'newer-image-1',
      ]);
      expect(await harness.dao.outstandingCount(), 0);
    });

    test('does not upload an item twice in one pass', () async {
      await seed(batchId: 'b1', count: 2);
      final ScriptedUploadApi api = alwaysSucceeds();

      await processorWith(api).drain();

      expect(api.callsFor('b1-image-0'), 1);
      expect(api.callsFor('b1-image-1'), 1);
    });

    test('a second drain over a completed queue does nothing', () async {
      await seed(batchId: 'b1', count: 2);
      final ScriptedUploadApi api = alwaysSucceeds();
      final QueueProcessor processor = processorWith(api);

      await processor.drain();
      final DrainOutcome second = await processor.drain();

      expect(second, DrainOutcome.idle);
      expect(
        api.callCount,
        2,
        reason: 'terminal items must never be uploaded again',
      );
    });
  });

  group('retryable failures — the FLT-SYNC-003 behaviour', () {
    test('keeps the row, keeps the file, and asks to come back', () async {
      final List<QueuedImage> images = await seed(batchId: 'b1', count: 1);
      final ScriptedUploadApi api = alwaysFails(FailureCategory.offline);

      final DrainOutcome outcome = await processorWith(api).drain();

      expect(outcome.retryable, 1);
      expect(outcome.uploaded, 0);
      expect(outcome.workRemaining, isTrue);
      expect(
        outcome.disposition,
        DrainDisposition.retryLater,
        reason: 'nothing was delivered, so backing off is the right answer',
      );

      final QueuedImage stored = (await harness.dao.imageById(
        images.first.id,
      ))!;
      expect(stored.status, ImageStatus.pending);
      expect(stored.attemptCount, 1);
      expect(stored.lastFailure, FailureCategory.offline);
      expect(
        store.files,
        contains(images.first.localPath),
        reason: 'the captured image is still on disk',
      );
      expect(store.deleted, isEmpty);
    });

    test('a failed pass claims each item once, then stops', () async {
      // The regression this pins is a drain that re-claims the item it just
      // returned to the queue and spins.
      await seed(batchId: 'b1', count: 2);
      final ScriptedUploadApi api = alwaysFails(FailureCategory.timeout);

      final DrainOutcome outcome = await processorWith(api).drain();

      expect(outcome.retryable, 2);
      expect(api.callCount, 2);
      expect(outcome.stop, DrainStop.queueExhausted);
    });

    test('a later pass recovers the item — automatic retry', () async {
      // FLT-SYNC-004, end to end through the processor: fail, wait, succeed,
      // with no user action anywhere in the path.
      final List<QueuedImage> images = await seed(batchId: 'b1', count: 1);
      final ScriptedUploadApi api = ScriptedUploadApi((
        QueuedImage image,
        int callIndex,
      ) {
        return callIndex == 0
            ? const UploadFailed(FailureCategory.offline)
            : UploadSucceeded(idempotencyKey: image.id);
      });
      final QueueProcessor processor = processorWith(api);

      final DrainOutcome first = await processor.drain();
      expect(first.retryable, 1);

      clock.advance(const Duration(minutes: 20));
      final DrainOutcome second = await processor.drain();

      expect(second.uploaded, 1);
      expect(second.workRemaining, isFalse);
      expect(second.disposition, DrainDisposition.drained);
      final QueuedImage stored = (await harness.dao.imageById(
        images.first.id,
      ))!;
      expect(stored.status, ImageStatus.uploaded);
      expect(
        stored.attemptCount,
        1,
        reason: 'the earlier failure is still recorded as history',
      );
      expect(
        (await harness.dao.batchById('b1'))!.status,
        BatchStatus.completed,
      );
      expect(
        api.calls[1].id,
        api.calls[0].id,
        reason: 'the retry carries the same idempotency key',
      );
    });

    test('an exception from the transport is retryable, not fatal', () async {
      await seed(batchId: 'b1', count: 1);
      final ScriptedUploadApi api = ScriptedUploadApi(
        (QueuedImage image, int callIndex) =>
            throw StateError('socket exploded'),
      );

      final DrainOutcome outcome = await processorWith(api).drain();

      expect(outcome.retryable, 1);
      final QueuedImage stored = (await harness.dao.imageById('b1-image-0'))!;
      expect(stored.status, ImageStatus.pending);
      expect(stored.lastFailure, FailureCategory.unexpected);
    });

    test('a server rejection is permanent, not retried', () async {
      await seed(batchId: 'b1', count: 1);
      final ScriptedUploadApi api = alwaysFails(FailureCategory.serverRejected);

      final DrainOutcome outcome = await processorWith(api).drain();

      expect(outcome.permanentlyFailed, 1);
      expect(outcome.workRemaining, isFalse);
      expect(outcome.disposition, DrainDisposition.drained);
      expect(
        (await harness.dao.imageById('b1-image-0'))!.status,
        ImageStatus.failedPermanent,
      );
    });
  });

  group('a missing local file (FLT-ERR-007, I10)', () {
    test('is permanent, and is never handed to the transport', () async {
      await seed(batchId: 'b1', count: 1);
      store.files.clear(); // the bytes went away; the row did not
      final ScriptedUploadApi api = alwaysSucceeds();

      final DrainOutcome outcome = await processorWith(api).drain();

      expect(outcome.permanentlyFailed, 1);
      expect(
        api.callCount,
        0,
        reason: 'there is nothing to send, so nothing is sent',
      );
      final QueuedImage stored = (await harness.dao.imageById('b1-image-0'))!;
      expect(stored.status, ImageStatus.failedPermanent);
      expect(stored.lastFailure, FailureCategory.missingLocalFile);
    });

    test('does not stop unrelated batches from draining', () async {
      final List<QueuedImage> broken = await seed(
        batchId: 'broken',
        count: 1,
        firstCapturedAt: DateTime.utc(2026, 8, 29, 8),
      );
      await seed(
        batchId: 'fine',
        count: 2,
        firstCapturedAt: DateTime.utc(2026, 8, 29, 10),
      );
      store.files.remove(broken.first.localPath);
      final ScriptedUploadApi api = alwaysSucceeds();

      final DrainOutcome outcome = await processorWith(api).drain();

      expect(outcome.permanentlyFailed, 1);
      expect(outcome.uploaded, 2);
      expect(outcome.workRemaining, isFalse);
      expect(outcome.disposition, DrainDisposition.drained);
      expect(
        (await harness.dao.batchById('fine'))!.status,
        BatchStatus.completed,
      );
    });

    test('does not loop: a second pass finds nothing to do', () async {
      await seed(batchId: 'b1', count: 1);
      store.files.clear();
      final ScriptedUploadApi api = alwaysSucceeds();
      final QueueProcessor processor = processorWith(api);

      await processor.drain();
      final DrainOutcome second = await processor.drain();

      expect(second, DrainOutcome.idle);
    });

    test('a filesystem that cannot answer is not treated as missing', () async {
      // An IO fault is not evidence that a photo is gone, and discarding a
      // capture on one would be the worst possible reading of the situation.
      await seed(batchId: 'b1', count: 1);
      store.failExists = true;
      final ScriptedUploadApi api = alwaysSucceeds();

      final DrainOutcome outcome = await processorWith(api).drain();

      expect(outcome.uploaded, 1);
    });
  });

  group('success and cleanup ordering', () {
    test('the file is kept by default (ADR-F16)', () async {
      final List<QueuedImage> images = await seed(batchId: 'b1', count: 1);
      final ScriptedUploadApi api = alwaysSucceeds();

      await processorWith(api).drain();

      expect(store.deleted, isEmpty);
      expect(store.files, contains(images.first.localPath));
    });

    test('with retention enabled, the file goes after the record', () async {
      final List<QueuedImage> images = await seed(batchId: 'b1', count: 1);
      final ScriptedUploadApi api = alwaysSucceeds();

      await processorWith(
        api,
        retention: const RetentionPolicy(deleteAfterUpload: true),
      ).drain();

      expect(store.deleted, <String>[images.first.localPath]);
      expect(
        (await harness.dao.imageById(images.first.id))!.status,
        ImageStatus.uploaded,
        reason: 'the row is written before the file is touched',
      );
    });

    test('a failed cleanup leaves the item uploaded, not re-queued', () async {
      // Housekeeping is not delivery. The upload happened; a file that will not
      // delete is disk to reclaim, and must never cause a second upload.
      await seed(batchId: 'b1', count: 1);
      store.failDelete = true;
      final ScriptedUploadApi api = alwaysSucceeds();
      final QueueProcessor processor = processorWith(
        api,
        retention: const RetentionPolicy(deleteAfterUpload: true),
      );

      final DrainOutcome outcome = await processor.drain();

      expect(outcome.uploaded, 1);
      expect(
        (await harness.dao.imageById('b1-image-0'))!.status,
        ImageStatus.uploaded,
      );

      final DrainOutcome second = await processor.drain();
      expect(second, DrainOutcome.idle);
      expect(
        api.callCount,
        1,
        reason: 'a cleanup fault must not produce a duplicate upload',
      );
    });
  });

  group('E — the atomic claim is the final duplicate-upload protection', () {
    test('two processors draining concurrently upload nothing twice', () async {
      // The scheduler keeps requests on one serial chain, so two drains should
      // not normally overlap. This asserts what happens if they ever do —
      // because the guarantee that matters must not depend on the scheduler
      // being right. Two processors, two *independent database connections*,
      // one queue, both drains in flight at once.
      final List<QueuedImage> images = await seed(batchId: 'b1', count: 8);

      final ScriptedUploadApi api = alwaysSucceeds();
      final QueueProcessor first = QueueProcessor(
        queue: await harness.independentDao(),
        api: api,
        store: store,
        clock: clock,
      );
      final QueueProcessor second = QueueProcessor(
        queue: await harness.independentDao(),
        api: api,
        store: store,
        clock: clock,
      );

      final List<DrainOutcome> outcomes = await Future.wait<DrainOutcome>(
        <Future<DrainOutcome>>[first.drain(), second.drain()],
      );

      expect(await harness.countWithStatus(ImageStatus.uploaded), 8);
      expect(
        api.callCount,
        8,
        reason: 'eight images, eight upload attempts — never nine',
      );
      for (final QueuedImage image in images) {
        expect(
          api.callsFor(image.id),
          1,
          reason: '${image.id} must be uploaded exactly once',
        );
      }
      expect(
        outcomes
            .map((DrainOutcome o) => o.uploaded)
            .reduce((int a, int b) => a + b),
        8,
        reason: 'the work was split between them, not duplicated',
      );
    });

    test('a scheduling storm cannot produce a duplicate upload', () async {
      // `append` means redundant requests accumulate rather than collapse, so
      // the honest question is what happens if several of them run. The answer
      // is the same as above: extra drains find an empty queue.
      await seed(batchId: 'b1', count: 3);
      final ScriptedUploadApi api = alwaysSucceeds();
      final QueueProcessor processor = processorWith(api);

      for (int i = 0; i < 4; i++) {
        await processor.drain();
      }

      expect(api.callCount, 3);
      expect(await harness.countWithStatus(ImageStatus.uploaded), 3);
    });
  });

  group('a locked database ends the pass instead of escaping', () {
    test('drain completes and reports contention rather than throwing', () async {
      // `drain` promises not to throw for an ordinary condition, and two of the
      // app's own isolates competing for a write lock is ordinary by design.
      // An unclosed exception here would escape the foreground drain too, where
      // there is no WorkManager to catch it.
      await seed(batchId: 'b1', count: 2);

      final Database connection = await harness.openConnection();
      final QueueProcessor processor = QueueProcessor(
        queue: UploadQueueDao(connection),
        api: alwaysSucceeds(),
        store: store,
        clock: clock,
      );
      await connection.close();

      // If this threw, the test would fail here — which is the assertion.
      final DrainOutcome outcome = await processor.drain();

      expect(outcome.stop, DrainStop.databaseBusy);
      expect(
        outcome.disposition,
        DrainDisposition.retryLater,
        reason: 'no progress was made, so ask the platform to come back',
      );
      expect(
        await harness.countWithStatus(ImageStatus.pending),
        2,
        reason: 'nothing was claimed, so nothing is stranded',
      );
    });
  });

  group('retry hammering across chained continuations — audit', () {
    test('a flaky item is attempted once per slice, then backs off', () async {
      // Honest answer to "can chained continuations hammer the transport?".
      //
      // Yes, in a bounded way: while healthy work keeps a slice making
      // progress, the slice also re-attempts the failing item once — the
      // per-invocation `skip` set (`ADR-F18`) only spans one pass. So the item
      // gets one attempt per slice.
      //
      // What bounds it: each attempt is separated by a slice of *real upload
      // work*, and the moment the healthy backlog is exhausted the next slice
      // makes no progress and returns `retryLater`, handing timing back to
      // WorkManager's exponential backoff. The count is therefore bounded by
      // the backlog, not by time, and cannot become a hot loop.
      //
      // Recorded as `RS-12` rather than engineered away: a second scheduler to
      // suppress it would be exactly the complexity `RS-04` warns against.
      final List<QueuedImage> images = await seed(batchId: 'b1', count: 5);
      final String flaky = images.first.id;

      final ScriptedUploadApi api = ScriptedUploadApi((
        QueuedImage image,
        int callIndex,
      ) {
        if (image.id == flaky) {
          return const UploadFailed(FailureCategory.timeout);
        }
        return UploadSucceeded(idempotencyKey: image.id);
      });
      final QueueProcessor processor = processorWith(api);

      // Two items per slice, so the flaky one and one healthy one each pass.
      DrainOutcome outcome = await processor.drain(maxItems: 2);
      int slices = 1;
      while (outcome.disposition == DrainDisposition.continuationRequired) {
        outcome = await processor.drain(maxItems: 2);
        slices++;
        expect(slices, lessThan(20), reason: 'guard against a runaway chain');
      }

      expect(
        outcome.disposition,
        DrainDisposition.retryLater,
        reason: 'once healthy work runs out, backoff takes over',
      );
      expect(
        slices,
        5,
        reason: '4 healthy items at 1 per slice, plus the last',
      );
      expect(
        (await harness.dao.imageById(flaky))!.attemptCount,
        slices,
        reason: 'exactly one attempt per slice — no inner loop',
      );
      expect(
        await harness.countWithStatus(ImageStatus.uploaded),
        4,
        reason: 'every attempt was paced by real upload work',
      );
      expect(
        (await harness.dao.imageById(flaky))!.status,
        ImageStatus.pending,
        reason: 'and the capture is still queued, not discarded',
      );
    });

    test(
      'with no healthy work, a flaky item gets one attempt then backs off',
      () async {
        // The case that would matter most if the bound were wrong: nothing else
        // to do, so nothing to pace the retries. One attempt, then `retryLater`.
        await seed(batchId: 'b1', count: 1);
        final ScriptedUploadApi api = alwaysFails(FailureCategory.timeout);

        final DrainOutcome outcome = await processorWith(api).drain();

        expect(api.callCount, 1);
        expect(outcome.disposition, DrainDisposition.retryLater);
      },
    );
  });

  group('bounding and recovery', () {
    test('stops at the per-invocation bound and asks to come back', () async {
      await seed(batchId: 'b1', count: 5);
      final ScriptedUploadApi api = alwaysSucceeds();

      final DrainOutcome outcome = await processorWith(api).drain(maxItems: 2);

      expect(outcome.uploaded, 2);
      expect(outcome.stop, DrainStop.itemBudget);
      expect(outcome.workRemaining, isTrue);
      expect(
        outcome.disposition,
        DrainDisposition.continuationRequired,
        reason: 'a healthy backlog is not a failed upload',
      );
      expect(await harness.dao.outstandingCount(), 3);
    });

    test('stops on the time budget before the item budget bites', () async {
      // An item count is a poor proxy for a time limit, and time is what
      // Android actually enforces. Each upload here costs three minutes of the
      // clock, so the eight-minute budget ends the pass after three of them —
      // well inside the 25-item bound.
      await seed(batchId: 'b1', count: 5);
      final ScriptedUploadApi api = ScriptedUploadApi((
        QueuedImage image,
        int callIndex,
      ) {
        clock.advance(const Duration(minutes: 3));
        return UploadSucceeded(idempotencyKey: image.id);
      });

      final DrainOutcome outcome = await processorWith(api).drain();

      expect(outcome.uploaded, 3);
      expect(outcome.stop, DrainStop.timeBudget);
      expect(
        outcome.disposition,
        DrainDisposition.continuationRequired,
        reason: 'running out of time is not an upload failure either',
      );
      expect(await harness.dao.outstandingCount(), 2);
    });

    test('a time-budget stop loses nothing; the next pass finishes', () async {
      await seed(batchId: 'b1', count: 5);
      final ScriptedUploadApi api = ScriptedUploadApi((
        QueuedImage image,
        int callIndex,
      ) {
        clock.advance(const Duration(minutes: 3));
        return UploadSucceeded(idempotencyKey: image.id);
      });
      final QueueProcessor processor = processorWith(api);

      await processor.drain();
      final DrainOutcome second = await processor.drain();

      expect(second.uploaded, 2);
      expect(second.disposition, DrainDisposition.drained);
      expect(await harness.countWithStatus(ImageStatus.uploaded), 5);
    });

    test('the budgets are the documented ones', () {
      expect(QueueProcessor.defaultMaxItemsPerDrain, 25);
      expect(
        QueueProcessor.defaultMaxDrainDuration,
        const Duration(minutes: 8),
        reason: 'headroom under the ~10 minutes Android allows a worker',
      );
    });

    test('successive bounded passes eventually drain the queue', () async {
      await seed(batchId: 'b1', count: 5);
      final ScriptedUploadApi api = alwaysSucceeds();
      final QueueProcessor processor = processorWith(api);

      DrainOutcome outcome = await processor.drain(maxItems: 2);
      while (outcome.workRemaining) {
        expect(outcome.disposition, DrainDisposition.continuationRequired);
        outcome = await processor.drain(maxItems: 2);
      }

      expect(await harness.dao.outstandingCount(), 0);
      expect(
        (await harness.dao.batchById('b1'))!.status,
        BatchStatus.completed,
      );
    });

    test('recovers an item stranded by a process death', () async {
      // Simulates the crash directly: an item claimed and then abandoned. The
      // drain picks it up because the lease has lapsed — no startup sweep, no
      // special case (`FLT-SYNC-009`).
      await seed(batchId: 'b1', count: 1);
      await harness.dao.claimNext(
        now: start,
        leaseCutoff: const StaleClaimPolicy().cutoffFrom(start),
      );
      expect(await harness.rawStatusOf('b1-image-0'), 'UPLOADING');

      clock.advance(const Duration(minutes: 11));
      final ScriptedUploadApi api = alwaysSucceeds();
      final DrainOutcome outcome = await processorWith(api).drain();

      expect(outcome.uploaded, 1);
      expect(await harness.rawStatusOf('b1-image-0'), 'UPLOADED');
    });

    test(
      'leaves a freshly claimed item to the processor that holds it',
      () async {
        await seed(batchId: 'b1', count: 1);
        await harness.dao.claimNext(
          now: start,
          leaseCutoff: const StaleClaimPolicy().cutoffFrom(start),
        );

        clock.advance(const Duration(minutes: 2));
        final ScriptedUploadApi api = alwaysSucceeds();
        final DrainOutcome outcome = await processorWith(api).drain();

        expect(outcome.processed, 0);
        expect(api.callCount, 0);
        expect(
          outcome.workRemaining,
          isTrue,
          reason: 'the item is still outstanding, just not ours',
        );
        expect(
          outcome.disposition,
          DrainDisposition.retryLater,
          reason:
              'nothing this pass could do; come back later rather than spin',
        );
      },
    );
  });
}
