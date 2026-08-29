// DATA tier — the atomic claim (FLT-SYNC-008, FLT-SYNC-009, FLT-SYNC-013).
//
// This is the most important file in the suite. It runs against the real SQLite
// engine through `sqflite_common_ffi`, and the contention cases use **separate
// connections to one database file**, because that — not a Dart lock — is the
// only thing the UI isolate and the WorkManager isolate actually share.
//
// A fake repository could not produce this evidence. Neither could a test
// around an in-process mutex: it would pass against an implementation that is
// not atomic at all, which is precisely the failure this test exists to catch
// (`RD-02`).

import 'package:flutter_test/flutter_test.dart';
import 'package:presence_lens_capture/data/database/upload_queue_dao.dart';
import 'package:presence_lens_capture/domain/entities/image_status.dart';
import 'package:presence_lens_capture/domain/entities/queued_image.dart';
import 'package:presence_lens_capture/domain/policies/stale_claim_policy.dart';

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

  group('claiming a single item', () {
    test('claims the pending row and stamps the lease', () async {
      await harness.seedQueuedBatch(batchId: 'b1', count: 1);

      final QueuedImage? claimed = await harness.dao.claimNext(
        now: now,
        leaseCutoff: cutoff,
      );

      expect(claimed, isNotNull);
      expect(claimed!.status, ImageStatus.uploading);
      expect(claimed.claimedAt, now);
      expect(await harness.rawStatusOf(claimed.id), 'UPLOADING');
    });

    test('returns null when the queue holds nothing claimable', () async {
      expect(
        await harness.dao.claimNext(now: now, leaseCutoff: cutoff),
        isNull,
      );
    });

    test('does not claim images whose batch is still a draft', () async {
      await harness.dao.createDraftBatch(
        id: 'draft',
        createdAt: DateTime.utc(2026, 8, 29, 9),
      );
      await harness.dao.addCapture(
        QueuedImage(
          id: 'draft-0',
          batchId: 'draft',
          localPath: '/tmp/draft-0.jpg',
          capturedAt: DateTime.utc(2026, 8, 29, 9),
          status: ImageStatus.draft,
        ),
      );

      expect(
        await harness.dao.claimNext(now: now, leaseCutoff: cutoff),
        isNull,
        reason: 'a capture is only work once its batch has been finished',
      );
    });

    test('an already-claimed fresh item cannot be claimed again', () async {
      await harness.seedQueuedBatch(batchId: 'b1', count: 1);

      final QueuedImage? first = await harness.dao.claimNext(
        now: now,
        leaseCutoff: cutoff,
      );
      final QueuedImage? second = await harness.dao.claimNext(
        now: now.add(const Duration(seconds: 5)),
        leaseCutoff: leases.cutoffFrom(now.add(const Duration(seconds: 5))),
      );

      expect(first, isNotNull);
      expect(second, isNull, reason: 'a live claim must not be stolen');
      expect(await harness.countWithStatus(ImageStatus.uploading), 1);
    });

    test('a terminal item is never claimed again', () async {
      await harness.seedQueuedBatch(batchId: 'b1', count: 1);
      final QueuedImage claimed = (await harness.dao.claimNext(
        now: now,
        leaseCutoff: cutoff,
      ))!;
      await harness.dao.recordSuccess(claimed.id, now: now);

      expect(
        await harness.dao.claimNext(
          now: now.add(const Duration(hours: 2)),
          leaseCutoff: leases.cutoffFrom(now.add(const Duration(hours: 2))),
        ),
        isNull,
      );
    });
  });

  group('skipping items already attempted in this pass', () {
    test('a skipped id is not handed back', () async {
      // A retryable failure returns a row to PENDING, which makes it
      // immediately claimable again. Without this exclusion the same drain pass
      // would pick it straight back up and retry it in a tight loop, taking
      // over the backoff that belongs to the OS (`RS-04`).
      await harness.seedQueuedBatch(batchId: 'b1', count: 1);

      expect(
        await harness.dao.claimNext(
          now: now,
          leaseCutoff: cutoff,
          skip: <String>{'b1-image-0'},
        ),
        isNull,
      );
      expect(await harness.rawStatusOf('b1-image-0'), 'PENDING');
    });

    test('an unskipped item is still claimed', () async {
      await harness.seedQueuedBatch(batchId: 'b1', count: 2);

      final QueuedImage? claimed = await harness.dao.claimNext(
        now: now,
        leaseCutoff: cutoff,
        skip: <String>{'b1-image-0'},
      );

      expect(claimed!.id, 'b1-image-1');
    });

    test('an empty skip set behaves as if absent', () async {
      // The processor passes its deferred set on every iteration, and on the
      // first one it is empty.
      await harness.seedQueuedBatch(batchId: 'b1', count: 1);
      final Set<String> nothingDeferredYet = <String>{};

      final QueuedImage? claimed = await harness.dao.claimNext(
        now: now,
        leaseCutoff: cutoff,
        skip: nothingDeferredYet,
      );

      expect(claimed, isNotNull);
    });
  });

  group('ordering', () {
    test('drains oldest capture first, across batches', () async {
      // Interleaved deliberately: batch two holds the *oldest* capture, so a
      // per-batch or insertion-order implementation would fail this
      // (`FLT-SYNC-013`).
      await harness.seedQueuedBatch(
        batchId: 'newer',
        count: 2,
        firstCapturedAt: DateTime.utc(2026, 8, 29, 10),
      );
      await harness.seedQueuedBatch(
        batchId: 'older',
        count: 2,
        firstCapturedAt: DateTime.utc(2026, 8, 29, 8),
      );

      final List<String> order = <String>[];
      for (int i = 0; i < 4; i++) {
        final QueuedImage? claimed = await harness.dao.claimNext(
          now: now,
          leaseCutoff: cutoff,
        );
        order.add(claimed!.id);
        await harness.dao.recordSuccess(claimed.id, now: now);
      }

      expect(order, <String>[
        'older-image-0',
        'older-image-1',
        'newer-image-0',
        'newer-image-1',
      ]);
    });
  });

  group('stale-lease recovery (process death)', () {
    test('a lease inside its period is not reclaimable', () async {
      await harness.seedQueuedBatch(batchId: 'b1', count: 1);
      final QueuedImage claimed = (await harness.dao.claimNext(
        now: now,
        leaseCutoff: cutoff,
      ))!;

      // Nine minutes later: still inside the ten-minute lease.
      final DateTime later = now.add(const Duration(minutes: 9));
      final QueuedImage? thief = await harness.dao.claimNext(
        now: later,
        leaseCutoff: leases.cutoffFrom(later),
      );

      expect(thief, isNull);
      final QueuedImage stored = (await harness.dao.imageById(claimed.id))!;
      expect(stored.claimedAt, now, reason: 'the original lease is untouched');
    });

    test('an expired lease is reclaimed, and only once', () async {
      await harness.seedQueuedBatch(batchId: 'b1', count: 1);
      final QueuedImage claimed = (await harness.dao.claimNext(
        now: now,
        leaseCutoff: cutoff,
      ))!;

      // Eleven minutes later the processor that held this claim is assumed
      // dead. Recovery is a property of the claim query, so it needs no startup
      // sweep and no separate code path (`FLT-SYNC-009`).
      final DateTime later = now.add(const Duration(minutes: 11));
      final QueuedImage? reclaimed = await harness.dao.claimNext(
        now: later,
        leaseCutoff: leases.cutoffFrom(later),
      );

      expect(reclaimed, isNotNull);
      expect(reclaimed!.id, claimed.id);
      expect(reclaimed.claimedAt, later);
      expect(await harness.countWithStatus(ImageStatus.uploading), 1);

      // Immediately re-claiming it is refused: the new lease is fresh.
      expect(
        await harness.dao.claimNext(
          now: later,
          leaseCutoff: leases.cutoffFrom(later),
        ),
        isNull,
      );
    });

    test('an item reclaimed after death keeps its file and attempts', () async {
      await harness.seedQueuedBatch(batchId: 'b1', count: 1);
      final QueuedImage first = (await harness.dao.claimNext(
        now: now,
        leaseCutoff: cutoff,
      ))!;

      final DateTime later = now.add(const Duration(minutes: 11));
      final QueuedImage reclaimed = (await harness.dao.claimNext(
        now: later,
        leaseCutoff: leases.cutoffFrom(later),
      ))!;

      expect(reclaimed.localPath, first.localPath);
      expect(
        reclaimed.attemptCount,
        0,
        reason: 'a lost claim is not a failed attempt; nothing was reported',
      );
    });
  });

  group('contention — the FLT-SYNC-008 evidence', () {
    test('two independent connections race one row; exactly one wins', () async {
      await harness.seedQueuedBatch(batchId: 'b1', count: 1);

      // Two DAOs over two separate connections to one file. This is the host's
      // reproduction of the UI isolate and the worker isolate; sqflite's own
      // synchronisation is per instance and does not span them (`FR-08`).
      final UploadQueueDao isolateA = await harness.independentDao();
      final UploadQueueDao isolateB = await harness.independentDao();

      // Both futures are started before either is awaited, so the two claims
      // are genuinely in flight together.
      final Future<QueuedImage?> raceA = isolateA.claimNext(
        now: now,
        leaseCutoff: cutoff,
      );
      final Future<QueuedImage?> raceB = isolateB.claimNext(
        now: now,
        leaseCutoff: cutoff,
      );
      final List<QueuedImage?> results = await Future.wait<QueuedImage?>(
        <Future<QueuedImage?>>[raceA, raceB],
      );

      final Iterable<QueuedImage?> winners = results.where(
        (QueuedImage? r) => r != null,
      );
      expect(
        winners.length,
        1,
        reason: 'the losing claimant must observe zero affected rows',
      );
      expect(await harness.countWithStatus(ImageStatus.uploading), 1);
      expect(await harness.rawStatusOf('b1-image-0'), 'UPLOADING');
    });

    test(
      'eight claimants on one row still produce exactly one winner',
      () async {
        await harness.seedQueuedBatch(batchId: 'b1', count: 1);

        final List<UploadQueueDao> claimants = <UploadQueueDao>[
          for (int i = 0; i < 8; i++) await harness.independentDao(),
        ];

        final List<QueuedImage?> results =
            await Future.wait<QueuedImage?>(<Future<QueuedImage?>>[
              for (final UploadQueueDao dao in claimants)
                dao.claimNext(now: now, leaseCutoff: cutoff),
            ]);

        expect(results.where((QueuedImage? r) => r != null).length, 1);
        expect(await harness.countWithStatus(ImageStatus.uploading), 1);
      },
    );

    test('two claimants on two rows each get a different one', () async {
      // The losing claimant is not sent away empty-handed when other work
      // exists: it looks for the next candidate rather than reporting an
      // drained queue.
      await harness.seedQueuedBatch(batchId: 'b1', count: 2);

      final UploadQueueDao isolateA = await harness.independentDao();
      final UploadQueueDao isolateB = await harness.independentDao();

      final List<QueuedImage?> results =
          await Future.wait<QueuedImage?>(<Future<QueuedImage?>>[
            isolateA.claimNext(now: now, leaseCutoff: cutoff),
            isolateB.claimNext(now: now, leaseCutoff: cutoff),
          ]);

      final Set<String> claimedIds = results
          .whereType<QueuedImage>()
          .map((QueuedImage i) => i.id)
          .toSet();
      expect(claimedIds.length, 2);
      expect(await harness.countWithStatus(ImageStatus.uploading), 2);
    });

    test('two claimants race one STALE row; exactly one wins', () async {
      // The dangerous version of the race: recovery and contention at the same
      // time, which is what happens when a device wakes a worker while the app
      // is also reopening after a crash.
      await harness.seedQueuedBatch(batchId: 'b1', count: 1);
      await harness.dao.claimNext(now: now, leaseCutoff: cutoff);

      final DateTime later = now.add(const Duration(minutes: 11));
      final DateTime staleCutoff = leases.cutoffFrom(later);

      final UploadQueueDao isolateA = await harness.independentDao();
      final UploadQueueDao isolateB = await harness.independentDao();

      final List<QueuedImage?> results =
          await Future.wait<QueuedImage?>(<Future<QueuedImage?>>[
            isolateA.claimNext(now: later, leaseCutoff: staleCutoff),
            isolateB.claimNext(now: later, leaseCutoff: staleCutoff),
          ]);

      expect(results.where((QueuedImage? r) => r != null).length, 1);
      expect(await harness.countWithStatus(ImageStatus.uploading), 1);
      final QueuedImage stored = (await harness.dao.imageById('b1-image-0'))!;
      expect(stored.claimedAt, later);
    });

    test('the loser of a race cannot record an outcome for that item', () async {
      // Losing is not merely "returns null" — the loser holds no claim, so the
      // transitions that require one are refused by the database as well.
      await harness.seedQueuedBatch(batchId: 'b1', count: 1);

      final UploadQueueDao isolateA = await harness.independentDao();
      final UploadQueueDao isolateB = await harness.independentDao();

      final List<QueuedImage?> results =
          await Future.wait<QueuedImage?>(<Future<QueuedImage?>>[
            isolateA.claimNext(now: now, leaseCutoff: cutoff),
            isolateB.claimNext(now: now, leaseCutoff: cutoff),
          ]);
      final int winnerIndex = results.indexWhere((QueuedImage? r) => r != null);
      final UploadQueueDao loser = winnerIndex == 0 ? isolateB : isolateA;

      // The winner completes it.
      final UploadQueueDao winner = winnerIndex == 0 ? isolateA : isolateB;
      expect(await winner.recordSuccess('b1-image-0', now: now), isTrue);

      // The loser's late attempts change nothing.
      expect(await loser.recordSuccess('b1-image-0', now: now), isFalse);
      expect(await harness.rawStatusOf('b1-image-0'), 'UPLOADED');
    });
  });
}
