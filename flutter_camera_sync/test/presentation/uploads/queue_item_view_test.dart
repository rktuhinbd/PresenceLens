// `UNIT` tier — the honesty rules of the Upload Manager's status vocabulary.
//
// Every rule here is a rule about *what the app is allowed to say*, so it is
// asserted directly against the pure mapping rather than through a rendered
// tree. A regression in this file is a regression in the product's credibility,
// not in its layout.

import 'package:flutter_test/flutter_test.dart';
import 'package:presence_lens_capture/domain/entities/failure_category.dart';
import 'package:presence_lens_capture/domain/entities/image_status.dart';
import 'package:presence_lens_capture/domain/entities/queued_image.dart';
import 'package:presence_lens_capture/presentation/uploads/queue_item_view.dart';

QueuedImage _image({
  required ImageStatus status,
  int attemptCount = 0,
  FailureCategory? lastFailure,
  String path = '/data/captures/b1/IMG_0031.jpg',
}) {
  return QueuedImage(
    id: 'IMG_0031',
    batchId: 'b1',
    localPath: path,
    capturedAt: DateTime.utc(2026, 8, 30, 9),
    status: status,
    attemptCount: attemptCount,
    lastFailure: lastFailure,
  );
}

void main() {
  test('a first attempt is "In queue", never "Retrying"', () {
    final QueueItemView view = QueueItemView.of(
      _image(status: ImageStatus.pending),
      hasLink: true,
    );

    // Retry is what follows a failure. Nothing has failed, and saying
    // "retrying" would invent a problem the user does not have
    // (`UX_SPEC.md` §4.1).
    expect(view.tone, QueueItemTone.queued);
    expect(view.status, 'In queue');
    expect(view.detail, isNull);
  });

  test('a claimed item says "Uploading", not "Uploading now"', () {
    final QueueItemView view = QueueItemView.of(
      _image(status: ImageStatus.uploading),
      hasLink: true,
    );

    expect(view.tone, QueueItemTone.uploading);
    expect(view.statusLine, 'Uploading');
    // The OS owns the schedule, so no wording may promise a moment.
    expect(view.statusLine, isNot(contains('now')));
  });

  test('a retrying item shows its attempt count and no denominator', () {
    final QueueItemView view = QueueItemView.of(
      _image(
        status: ImageStatus.pending,
        attemptCount: 3,
        lastFailure: FailureCategory.serverTransient,
      ),
      hasLink: true,
    );

    expect(view.tone, QueueItemTone.retrying);
    expect(view.statusLine, 'Retrying · attempt 3');
    // There is no attempt cap, so "3 of 5" would promise an abandonment that
    // never comes (`ADR-F12`, `FLT-UX-009`).
    expect(view.statusLine, isNot(contains('/')));
    expect(view.statusLine, isNot(contains(' of ')));
  });

  test('an offline failure with no link reads as waiting, not retrying', () {
    final QueueItemView view = QueueItemView.of(
      _image(
        status: ImageStatus.pending,
        attemptCount: 2,
        lastFailure: FailureCategory.offline,
      ),
      hasLink: false,
    );

    expect(view.tone, QueueItemTone.awaitingLink);
    expect(view.status, 'Waiting for connection');
  });

  test('the same row reads as retrying once a link is reported', () {
    final QueueItemView view = QueueItemView.of(
      _image(
        status: ImageStatus.pending,
        attemptCount: 2,
        lastFailure: FailureCategory.offline,
      ),
      hasLink: true,
    );

    // The link signal changes wording only. The durable row, and what the queue
    // will do about it, are identical either way (`FLT-SYNC-011`).
    expect(view.tone, QueueItemTone.retrying);
    expect(view.statusLine, 'Retrying · attempt 2');
  });

  test('a permanent failure names a reason only when it has one', () {
    final QueueItemView missing = QueueItemView.of(
      _image(
        status: ImageStatus.failedPermanent,
        attemptCount: 1,
        lastFailure: FailureCategory.missingLocalFile,
      ),
      hasLink: true,
    );
    expect(missing.statusLine, "Can't upload · file missing");

    final QueueItemView unlabelled = QueueItemView.of(
      _image(status: ImageStatus.failedPermanent, attemptCount: 1),
      hasLink: true,
    );
    // No reason is better than a manufactured one.
    expect(unlabelled.statusLine, "Can't upload");
  });

  test('a confirmed upload says "Synced"', () {
    final QueueItemView view = QueueItemView.of(
      _image(status: ImageStatus.uploaded),
      hasLink: true,
    );
    expect(view.tone, QueueItemTone.synced);
    expect(view.statusLine, 'Synced');
  });

  test('no status is ever an exception message or an error code', () {
    for (final ImageStatus status in ImageStatus.values) {
      for (final FailureCategory? failure in <FailureCategory?>[
        null,
        ...FailureCategory.values,
      ]) {
        final QueueItemView view = QueueItemView.of(
          _image(status: status, attemptCount: 1, lastFailure: failure),
          hasLink: false,
        );
        expect(view.status, isNotEmpty);
        expect(view.statusLine, isNot(contains('Exception')));
        expect(view.statusLine, isNot(matches(RegExp(r'\b[45]\d\d\b'))));
      }
    }
  });

  test('the row is named by its file, and reads as one sentence', () {
    final QueueItemView view = QueueItemView.of(
      _image(
        status: ImageStatus.pending,
        attemptCount: 3,
        lastFailure: FailureCategory.serverTransient,
        path: r'C:\app\captures\b1\IMG_0033.jpg',
      ),
      hasLink: true,
    );

    // Both separators, because the durable path is produced by the host's own
    // filesystem and the app runs on two of them.
    expect(view.fileName, 'IMG_0033.jpg');
    // One label, not four nodes (`UX_SPEC.md` §6).
    expect(view.semanticLabel, 'IMG_0033.jpg, retrying · attempt 3');
  });
}
