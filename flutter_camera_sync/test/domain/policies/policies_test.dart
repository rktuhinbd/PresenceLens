// UNIT tier — the remaining pure policies.
//
// Covers FLT-SYNC-006, FLT-SYNC-009, FLT-SYNC-016, FLT-BAT-004, FLT-BAT-006,
// FLT-ERR-008.

import 'package:flutter_test/flutter_test.dart';
import 'package:presence_lens_capture/domain/entities/batch_status.dart';
import 'package:presence_lens_capture/domain/entities/capture_batch.dart';
import 'package:presence_lens_capture/domain/entities/failure_category.dart';
import 'package:presence_lens_capture/domain/entities/image_status.dart';
import 'package:presence_lens_capture/domain/policies/batch_policy.dart';
import 'package:presence_lens_capture/domain/policies/failure_classifier.dart';
import 'package:presence_lens_capture/domain/policies/retention_policy.dart';
import 'package:presence_lens_capture/domain/policies/stale_claim_policy.dart';

void main() {
  group('StaleClaimPolicy', () {
    const StaleClaimPolicy policy = StaleClaimPolicy();
    final DateTime now = DateTime.utc(2026, 8, 29, 12);

    test('the lease is ten minutes', () {
      expect(StaleClaimPolicy.defaultLeasePeriod, const Duration(minutes: 10));
    });

    test('a claim inside the lease is not expired', () {
      expect(
        policy.isExpired(
          claimedAt: now.subtract(const Duration(minutes: 9, seconds: 59)),
          now: now,
        ),
        isFalse,
      );
    });

    test('a claim exactly at the cutoff is not expired', () {
      // Deliberately matches the strict `<` in the SQL claim, so the Dart rule
      // and the database rule cannot disagree at the boundary.
      expect(
        policy.isExpired(
          claimedAt: now.subtract(const Duration(minutes: 10)),
          now: now,
        ),
        isFalse,
      );
    });

    test('a claim one millisecond past the cutoff is expired', () {
      expect(
        policy.isExpired(
          claimedAt: now.subtract(const Duration(minutes: 10, milliseconds: 1)),
          now: now,
        ),
        isTrue,
      );
    });

    test('a claim stamped in the future is never expired', () {
      // A device clock that jumped backwards must not make the app rob live
      // claims from a processor that is still working.
      expect(
        policy.isExpired(
          claimedAt: now.add(const Duration(hours: 3)),
          now: now,
        ),
        isFalse,
      );
    });

    test('the cutoff is the lease period behind now', () {
      expect(
        policy.cutoffFrom(now),
        now.subtract(StaleClaimPolicy.defaultLeasePeriod),
      );
    });

    test('the lease period is overridable for tests', () {
      const StaleClaimPolicy short = StaleClaimPolicy(
        leasePeriod: Duration(seconds: 30),
      );
      expect(
        short.isExpired(
          claimedAt: now.subtract(const Duration(minutes: 1)),
          now: now,
        ),
        isTrue,
      );
    });
  });

  group('FailureClassifier', () {
    const FailureClassifier classifier = FailureClassifier();

    test('transport and server faults are retryable', () {
      for (final FailureCategory category in <FailureCategory>[
        FailureCategory.offline,
        FailureCategory.timeout,
        FailureCategory.serverTransient,
      ]) {
        expect(
          classifier.classify(category),
          FailureDisposition.retryable,
          reason: '${category.name} can succeed on a later attempt',
        );
      }
    });

    test('a timeout is retryable, distinctly from a rejection', () {
      // FLT-ERR-008: reading a timeout as a rejection would discard an image
      // that the server never actually refused.
      expect(
        classifier.classify(FailureCategory.timeout),
        FailureDisposition.retryable,
      );
      expect(
        classifier.classify(FailureCategory.serverRejected),
        FailureDisposition.permanent,
      );
    });

    test('a missing local file is permanent', () {
      expect(
        classifier.classify(FailureCategory.missingLocalFile),
        FailureDisposition.permanent,
        reason: 'no number of retries can recreate deleted bytes',
      );
    });

    test('an unclassified fault fails open, toward retrying', () {
      expect(
        classifier.classify(FailureCategory.unexpected),
        FailureDisposition.retryable,
        reason: 'keeping a photo is cheaper than discarding one',
      );
    });

    test('every category has a verdict', () {
      for (final FailureCategory category in FailureCategory.values) {
        expect(classifier.classify(category), isNotNull);
      }
    });

    test('categories round-trip through their stored strings', () {
      for (final FailureCategory category in FailureCategory.values) {
        expect(FailureCategory.fromWireName(category.wireName), category);
      }
      expect(() => FailureCategory.fromWireName('NOPE'), throwsArgumentError);
    });
  });

  group('BatchPolicy', () {
    const BatchPolicy policy = BatchPolicy();

    CaptureBatch batch(BatchStatus status, int imageCount) => CaptureBatch(
      id: 'b',
      createdAt: DateTime.utc(2026, 8, 29),
      status: status,
      imageCount: imageCount,
    );

    test('a batch opens only when none is already open', () {
      expect(policy.canOpenBatch(hasOpenDraft: false), isTrue);
      expect(policy.canOpenBatch(hasOpenDraft: true), isFalse);
    });

    test('a non-empty draft may be finished', () {
      expect(policy.refuseEnqueue(batch(BatchStatus.draft, 3)), isNull);
    });

    test('an empty batch is refused with a reason (FLT-BAT-006)', () {
      expect(
        policy.refuseEnqueue(batch(BatchStatus.draft, 0)),
        EnqueueRefusal.noImages,
      );
    });

    test('an already-finished batch is refused', () {
      expect(
        policy.refuseEnqueue(batch(BatchStatus.queued, 2)),
        EnqueueRefusal.notADraft,
      );
      expect(
        policy.refuseEnqueue(batch(BatchStatus.completed, 2)),
        EnqueueRefusal.notADraft,
      );
    });

    test('every refusal carries a message a user could read', () {
      for (final EnqueueRefusal refusal in EnqueueRefusal.values) {
        expect(refusal.message, isNotEmpty);
      }
    });

    test('batch transitions are draft to queued to completed only', () {
      expect(
        policy.isLegalTransition(BatchStatus.draft, BatchStatus.queued),
        isTrue,
      );
      expect(
        policy.isLegalTransition(BatchStatus.queued, BatchStatus.completed),
        isTrue,
      );
      expect(
        policy.isLegalTransition(BatchStatus.draft, BatchStatus.completed),
        isFalse,
        reason: 'a batch cannot complete without being finished first',
      );
      expect(
        policy.isLegalTransition(BatchStatus.completed, BatchStatus.queued),
        isFalse,
      );
      expect(
        policy.isLegalTransition(BatchStatus.queued, BatchStatus.draft),
        isFalse,
      );
    });

    test('completion needs every image uploaded (I8)', () {
      expect(policy.isComplete(imageCount: 3, uploadedCount: 3), isTrue);
      expect(policy.isComplete(imageCount: 3, uploadedCount: 2), isFalse);
    });

    test('an empty batch is never complete', () {
      expect(
        policy.isComplete(imageCount: 0, uploadedCount: 0),
        isFalse,
        reason: 'a batch that received nothing did not succeed at anything',
      );
    });

    test('batch statuses round-trip through their stored strings', () {
      for (final BatchStatus status in BatchStatus.values) {
        expect(BatchStatus.fromWireName(status.wireName), status);
      }
      expect(() => BatchStatus.fromWireName('OPEN'), throwsArgumentError);
    });
  });

  group('RetentionPolicy', () {
    test('deletion is off by default (ADR-F16)', () {
      const RetentionPolicy policy = RetentionPolicy();
      expect(policy.deleteAfterUpload, isFalse);
      expect(policy.shouldDeleteLocalFile(ImageStatus.uploaded), isFalse);
    });

    test('when enabled, only a confirmed upload releases the file', () {
      const RetentionPolicy policy = RetentionPolicy(deleteAfterUpload: true);
      expect(policy.shouldDeleteLocalFile(ImageStatus.uploaded), isTrue);
      for (final ImageStatus status in <ImageStatus>[
        ImageStatus.draft,
        ImageStatus.pending,
        ImageStatus.uploading,
        ImageStatus.failedPermanent,
      ]) {
        expect(
          policy.shouldDeleteLocalFile(status),
          isFalse,
          reason: 'deleting a ${status.name} image would lose a capture',
        );
      }
    });
  });
}
