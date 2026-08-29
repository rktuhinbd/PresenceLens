// DATA tier — persistence, the finish-batch transaction, outcome transitions
// and aggregate batch completion.
//
// Covers FLT-BAT-001, FLT-BAT-002, FLT-BAT-005, FLT-BAT-006, FLT-SYNC-001,
// FLT-SYNC-003, FLT-SYNC-010, FLT-ERR-006 and invariants I2, I6, I7, I8, I9.

import 'package:flutter_test/flutter_test.dart';
import 'package:presence_lens_capture/data/database/app_database.dart';
import 'package:presence_lens_capture/domain/entities/batch_status.dart';
import 'package:presence_lens_capture/domain/entities/capture_batch.dart';
import 'package:presence_lens_capture/domain/entities/failure_category.dart';
import 'package:presence_lens_capture/domain/entities/image_status.dart';
import 'package:presence_lens_capture/domain/entities/queued_image.dart';
import 'package:presence_lens_capture/domain/policies/stale_claim_policy.dart';
import 'package:sqflite/sqflite.dart';

import '../../support/queue_harness.dart';

void main() {
  late QueueHarness harness;

  const StaleClaimPolicy leases = StaleClaimPolicy();
  final DateTime now = DateTime.utc(2026, 8, 29, 12);
  final DateTime cutoff = leases.cutoffFrom(now);

  setUp(() async {
    harness = await QueueHarness.create();
  });

  tearDown(() async {
    await harness.dispose();
  });

  QueuedImage draftImage(String batchId, String id, DateTime at) => QueuedImage(
    id: id,
    batchId: batchId,
    localPath: '/captures/$batchId/$id.jpg',
    capturedAt: at,
    status: ImageStatus.draft,
  );

  group('batches', () {
    test('a new batch round-trips through SQLite unchanged', () async {
      final DateTime createdAt = DateTime.utc(2026, 8, 29, 9, 30);
      await harness.dao.createDraftBatch(id: 'b1', createdAt: createdAt);

      final CaptureBatch stored = (await harness.dao.batchById('b1'))!;
      expect(stored.id, 'b1');
      expect(stored.createdAt, createdAt);
      expect(stored.status, BatchStatus.draft);
      expect(stored.queuedAt, isNull);
      expect(stored.imageCount, 0);
    });

    test('only one draft batch may be open at a time (I3)', () async {
      // An application-level capture-workflow rule, enforced where batches are
      // created. Not a database constraint, and not claimed to be one: draft
      // batches have a single creator, so there is no cross-isolate race to
      // defend against (`ADR-F20`).
      await harness.dao.createDraftBatch(id: 'b1', createdAt: now);

      await expectLater(
        harness.dao.createDraftBatch(id: 'b2', createdAt: now),
        throwsA(isA<StateError>()),
      );
    });

    test('the one-draft rule is not a database constraint', () async {
      // Asserts the *limit* of the guarantee, so nobody later reads I3 as
      // cross-isolate protection. A direct insert bypasses the policy, which is
      // exactly what a UNIQUE index would have prevented — and exactly the
      // complexity `ADR-F20` declines to buy, because the background worker
      // never creates a batch.
      await harness.dao.createDraftBatch(id: 'b1', createdAt: now);

      await harness.primary.insert(AppDatabase.batchesTable, <String, Object?>{
        'id': 'b2',
        'created_at': now.millisecondsSinceEpoch,
        'status': BatchStatus.draft.wireName,
        'image_count': 0,
      });

      expect(
        (await harness.dao.allBatches())
            .where((CaptureBatch b) => b.status == BatchStatus.draft)
            .length,
        2,
        reason: 'the database permits it; the application flow does not do it',
      );
    });

    test('a new draft may open once the previous one is finished', () async {
      await harness.seedQueuedBatch(batchId: 'b1', count: 1);
      await harness.dao.createDraftBatch(id: 'b2', createdAt: now);

      expect((await harness.dao.openDraftBatch())!.id, 'b2');
      expect(await harness.dao.allBatches(), hasLength(2));
    });

    test('supports multiple independent batches (FLT-BAT-002)', () async {
      await harness.seedQueuedBatch(
        batchId: 'b1',
        count: 2,
        firstCapturedAt: DateTime.utc(2026, 8, 29, 8),
      );
      await harness.seedQueuedBatch(
        batchId: 'b2',
        count: 3,
        firstCapturedAt: DateTime.utc(2026, 8, 29, 10),
      );

      expect(await harness.dao.imagesInBatch('b1'), hasLength(2));
      expect(await harness.dao.imagesInBatch('b2'), hasLength(3));
      expect(await harness.dao.outstandingCount(), 5);
    });

    test('image_count matches the real row count (I9)', () async {
      await harness.dao.createDraftBatch(id: 'b1', createdAt: now);
      for (int i = 0; i < 4; i++) {
        await harness.dao.addCapture(
          draftImage('b1', 'i$i', now.add(Duration(seconds: i))),
        );
      }

      final CaptureBatch stored = (await harness.dao.batchById('b1'))!;
      expect(stored.imageCount, 4);
      expect(stored.imageCount, (await harness.dao.imagesInBatch('b1')).length);
    });

    test('deleting a batch removes its images too', () async {
      await harness.seedQueuedBatch(batchId: 'b1', count: 2);
      await harness.dao.deleteBatch('b1');

      expect(await harness.dao.batchById('b1'), isNull);
      expect(await harness.dao.imagesInBatch('b1'), isEmpty);
    });
  });

  group('finishing a batch (the transaction)', () {
    test('batch and every image move together (I2)', () async {
      await harness.dao.createDraftBatch(id: 'b1', createdAt: now);
      await harness.dao.addCapture(draftImage('b1', 'i0', now));
      await harness.dao.addCapture(
        draftImage('b1', 'i1', now.add(const Duration(seconds: 1))),
      );

      final CaptureBatch queued = await harness.dao.enqueueBatch(
        'b1',
        queuedAt: now,
      );

      expect(queued.status, BatchStatus.queued);
      expect(queued.queuedAt, now);
      for (final QueuedImage image in await harness.dao.imagesInBatch('b1')) {
        expect(image.status, ImageStatus.pending);
      }
    });

    test('needs no network — it is a local durable act', () async {
      // Nothing in this path touches UploadApi or ConnectivityPort. The test
      // constructs neither, so it could not compile if finishing a batch
      // required either (`ADR-F14`).
      await harness.dao.createDraftBatch(id: 'b1', createdAt: now);
      await harness.dao.addCapture(draftImage('b1', 'i0', now));

      await expectLater(
        harness.dao.enqueueBatch('b1', queuedAt: now),
        completes,
      );
    });

    test('refuses an empty batch (FLT-BAT-006)', () async {
      await harness.dao.createDraftBatch(id: 'b1', createdAt: now);

      await expectLater(
        harness.dao.enqueueBatch('b1', queuedAt: now),
        throwsA(isA<StateError>()),
      );
      expect((await harness.dao.batchById('b1'))!.status, BatchStatus.draft);
    });

    test('refuses a batch that was already finished', () async {
      await harness.seedQueuedBatch(batchId: 'b1', count: 1);

      await expectLater(
        harness.dao.enqueueBatch('b1', queuedAt: now),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'a failure inside the transaction moves nothing (I2, FLT-ERR-006)',
      () async {
        await harness.dao.createDraftBatch(id: 'b1', createdAt: now);
        await harness.dao.addCapture(draftImage('b1', 'i0', now));
        await harness.dao.addCapture(
          draftImage('b1', 'i1', now.add(const Duration(seconds: 1))),
        );

        // Force a fault part-way through the same shape of transaction the DAO
        // uses: images updated, then a statement that cannot succeed. If the
        // rollback were not real, the images would be left PENDING under a batch
        // still marked DRAFT — the half-enqueued state invariant I2 forbids.
        await expectLater(
          harness.primary.transaction((Transaction txn) async {
            await txn.update(
              AppDatabase.imagesTable,
              <String, Object?>{'status': ImageStatus.pending.wireName},
              where: 'batch_id = ?',
              whereArgs: <Object?>['b1'],
            );
            await txn.rawUpdate('UPDATE no_such_table SET x = 1');
          }),
          throwsA(isA<Object>()),
        );

        final CaptureBatch batch = (await harness.dao.batchById('b1'))!;
        expect(batch.status, BatchStatus.draft);
        for (final QueuedImage image in await harness.dao.imagesInBatch('b1')) {
          expect(image.status, ImageStatus.draft);
        }
      },
    );
  });

  group('recording a success', () {
    test('marks the image uploaded and clears its lease', () async {
      await harness.seedQueuedBatch(batchId: 'b1', count: 1);
      final QueuedImage claimed = (await harness.dao.claimNext(
        now: now,
        leaseCutoff: cutoff,
      ))!;

      expect(await harness.dao.recordSuccess(claimed.id, now: now), isTrue);

      final QueuedImage stored = (await harness.dao.imageById(claimed.id))!;
      expect(stored.status, ImageStatus.uploaded);
      expect(stored.claimedAt, isNull);
      expect(stored.lastAttemptAt, now);
      expect(stored.lastFailure, isNull);
    });

    test('is idempotent — a repeat changes nothing (I7)', () async {
      await harness.seedQueuedBatch(batchId: 'b1', count: 1);
      final QueuedImage claimed = (await harness.dao.claimNext(
        now: now,
        leaseCutoff: cutoff,
      ))!;

      expect(await harness.dao.recordSuccess(claimed.id, now: now), isTrue);
      expect(
        await harness.dao.recordSuccess(
          claimed.id,
          now: now.add(const Duration(minutes: 1)),
        ),
        isFalse,
      );

      final QueuedImage stored = (await harness.dao.imageById(claimed.id))!;
      expect(stored.status, ImageStatus.uploaded);
      expect(
        stored.lastAttemptAt,
        now,
        reason: 'the second call must not overwrite the first result',
      );
    });

    test('cannot be recorded without holding the claim', () async {
      await harness.seedQueuedBatch(batchId: 'b1', count: 1);

      expect(
        await harness.dao.recordSuccess('b1-image-0', now: now),
        isFalse,
        reason: 'PENDING -> UPLOADED is not a legal transition',
      );
      expect(await harness.rawStatusOf('b1-image-0'), 'PENDING');
    });
  });

  group('batch completion (I8)', () {
    test('a partly uploaded batch is not completed', () async {
      await harness.seedQueuedBatch(batchId: 'b1', count: 2);
      final QueuedImage first = (await harness.dao.claimNext(
        now: now,
        leaseCutoff: cutoff,
      ))!;
      await harness.dao.recordSuccess(first.id, now: now);

      expect((await harness.dao.batchById('b1'))!.status, BatchStatus.queued);
    });

    test('a fully uploaded batch is completed', () async {
      await harness.seedQueuedBatch(batchId: 'b1', count: 2);
      for (int i = 0; i < 2; i++) {
        final QueuedImage claimed = (await harness.dao.claimNext(
          now: now,
          leaseCutoff: cutoff,
        ))!;
        await harness.dao.recordSuccess(claimed.id, now: now);
      }

      expect(
        (await harness.dao.batchById('b1'))!.status,
        BatchStatus.completed,
      );
    });

    test('a batch holding a permanent failure never completes', () async {
      await harness.seedQueuedBatch(batchId: 'b1', count: 2);

      final QueuedImage first = (await harness.dao.claimNext(
        now: now,
        leaseCutoff: cutoff,
      ))!;
      await harness.dao.recordPermanentFailure(
        first.id,
        category: FailureCategory.missingLocalFile,
        now: now,
      );

      final QueuedImage second = (await harness.dao.claimNext(
        now: now,
        leaseCutoff: cutoff,
      ))!;
      await harness.dao.recordSuccess(second.id, now: now);

      expect(
        (await harness.dao.batchById('b1'))!.status,
        BatchStatus.queued,
        reason: 'an undelivered image must not read as a completed batch',
      );
    });

    test('completing one batch leaves another alone', () async {
      await harness.seedQueuedBatch(
        batchId: 'b1',
        count: 1,
        firstCapturedAt: DateTime.utc(2026, 8, 29, 8),
      );
      await harness.seedQueuedBatch(
        batchId: 'b2',
        count: 1,
        firstCapturedAt: DateTime.utc(2026, 8, 29, 10),
      );

      final QueuedImage oldest = (await harness.dao.claimNext(
        now: now,
        leaseCutoff: cutoff,
      ))!;
      await harness.dao.recordSuccess(oldest.id, now: now);

      expect(
        (await harness.dao.batchById('b1'))!.status,
        BatchStatus.completed,
      );
      expect((await harness.dao.batchById('b2'))!.status, BatchStatus.queued);
    });
  });

  group('recording a retryable failure — the FLT-SYNC-003 test', () {
    test('returns the item to the queue, keeping everything (I6)', () async {
      await harness.seedQueuedBatch(batchId: 'b1', count: 1);
      final QueuedImage claimed = (await harness.dao.claimNext(
        now: now,
        leaseCutoff: cutoff,
      ))!;

      expect(
        await harness.dao.recordRetryableFailure(
          claimed.id,
          category: FailureCategory.offline,
          now: now,
        ),
        isTrue,
      );

      final QueuedImage stored = (await harness.dao.imageById(claimed.id))!;
      expect(stored.status, ImageStatus.pending);
      expect(stored.attemptCount, 1);
      expect(stored.lastFailure, FailureCategory.offline);
      expect(stored.claimedAt, isNull);
      expect(
        stored.localPath,
        claimed.localPath,
        reason: 'the row still points at the image; nothing was discarded',
      );
      expect(await harness.dao.outstandingCount(), 1);
    });

    test('is derivable as "retrying" without a state of its own', () async {
      await harness.seedQueuedBatch(batchId: 'b1', count: 1);
      final QueuedImage claimed = (await harness.dao.claimNext(
        now: now,
        leaseCutoff: cutoff,
      ))!;
      await harness.dao.recordRetryableFailure(
        claimed.id,
        category: FailureCategory.timeout,
        now: now,
      );

      expect((await harness.dao.imageById(claimed.id))!.isRetrying, isTrue);
    });

    test(
      'attempts accumulate with no ceiling that discards (ADR-F12)',
      () async {
        await harness.seedQueuedBatch(batchId: 'b1', count: 1);

        for (int attempt = 1; attempt <= 7; attempt++) {
          final QueuedImage claimed = (await harness.dao.claimNext(
            now: now,
            leaseCutoff: cutoff,
          ))!;
          await harness.dao.recordRetryableFailure(
            claimed.id,
            category: FailureCategory.timeout,
            now: now,
          );
          expect(
            (await harness.dao.imageById(claimed.id))!.attemptCount,
            attempt,
          );
        }

        final QueuedImage stored = (await harness.dao.imageById('b1-image-0'))!;
        expect(
          stored.status,
          ImageStatus.pending,
          reason: 'seven failures must not have discarded the capture',
        );
      },
    );

    test('a later attempt can still succeed (FLT-SYNC-004)', () async {
      await harness.seedQueuedBatch(batchId: 'b1', count: 1);

      final QueuedImage first = (await harness.dao.claimNext(
        now: now,
        leaseCutoff: cutoff,
      ))!;
      await harness.dao.recordRetryableFailure(
        first.id,
        category: FailureCategory.offline,
        now: now,
      );

      final QueuedImage second = (await harness.dao.claimNext(
        now: now.add(const Duration(minutes: 20)),
        leaseCutoff: leases.cutoffFrom(now.add(const Duration(minutes: 20))),
      ))!;
      expect(second.attemptCount, 1);
      await harness.dao.recordSuccess(second.id, now: now);

      expect(await harness.rawStatusOf('b1-image-0'), 'UPLOADED');
      expect(
        (await harness.dao.batchById('b1'))!.status,
        BatchStatus.completed,
      );
    });
  });

  group('recording a permanent failure (I10)', () {
    test('leaves the work set and is not claimed again', () async {
      await harness.seedQueuedBatch(batchId: 'b1', count: 1);
      final QueuedImage claimed = (await harness.dao.claimNext(
        now: now,
        leaseCutoff: cutoff,
      ))!;

      await harness.dao.recordPermanentFailure(
        claimed.id,
        category: FailureCategory.missingLocalFile,
        now: now,
      );

      final QueuedImage stored = (await harness.dao.imageById(claimed.id))!;
      expect(stored.status, ImageStatus.failedPermanent);
      expect(stored.lastFailure, FailureCategory.missingLocalFile);
      expect(await harness.dao.outstandingCount(), 0);
      expect(
        await harness.dao.claimNext(
          now: now.add(const Duration(hours: 5)),
          leaseCutoff: leases.cutoffFrom(now.add(const Duration(hours: 5))),
        ),
        isNull,
      );
    });

    test('one bad item does not block unrelated batches', () async {
      await harness.seedQueuedBatch(
        batchId: 'broken',
        count: 1,
        firstCapturedAt: DateTime.utc(2026, 8, 29, 7),
      );
      await harness.seedQueuedBatch(
        batchId: 'fine',
        count: 1,
        firstCapturedAt: DateTime.utc(2026, 8, 29, 9),
      );

      final QueuedImage bad = (await harness.dao.claimNext(
        now: now,
        leaseCutoff: cutoff,
      ))!;
      expect(bad.batchId, 'broken');
      await harness.dao.recordPermanentFailure(
        bad.id,
        category: FailureCategory.missingLocalFile,
        now: now,
      );

      final QueuedImage next = (await harness.dao.claimNext(
        now: now,
        leaseCutoff: cutoff,
      ))!;
      expect(next.batchId, 'fine');
    });
  });

  group('the change stream', () {
    test('emits on a queue mutation', () async {
      final Future<void> firstChange = harness.dao.changes.first;
      await harness.dao.createDraftBatch(id: 'b1', createdAt: now);
      await expectLater(firstChange, completes);
    });
  });
}
