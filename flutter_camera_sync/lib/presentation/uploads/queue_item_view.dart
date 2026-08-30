import 'package:equatable/equatable.dart';

import '../../domain/entities/failure_category.dart';
import '../../domain/entities/image_status.dart';
import '../../domain/entities/queued_image.dart';

/// The six things a queue row is allowed to say about itself.
///
/// A closed set, because the alternative is a widget printing whatever an
/// exception happened to contain. No transport message, no platform code and no
/// stack trace ever reaches the screen (`UX_SPEC.md` §5).
enum QueueItemTone {
  /// Waiting its turn; nothing has been attempted.
  queued,

  /// Waiting for a link, having failed for the lack of one.
  awaitingLink,

  /// Claimed and in flight.
  uploading,

  /// Failed at least once and will be tried again.
  retrying,

  /// Confirmed by the server.
  synced,

  /// Unprocessable — it has left the work set.
  failed,
}

/// One queue row's words, resolved from the durable row.
///
/// **Pure, and separate from the widget on purpose.** Every honesty rule the
/// Upload Manager has to keep is a rule about *what it says* — no fabricated
/// attempt ceiling, no "retrying" before anything has failed, no colour-only
/// state — so the rules live where they can be asserted directly rather than
/// through a rendered tree (`FLT-UX-005`, `FLT-UX-009`, `FLT-UX-011`).
class QueueItemView extends Equatable {
  /// Creates a view.
  const QueueItemView({
    required this.image,
    required this.tone,
    required this.status,
    required this.detail,
  });

  /// Resolves the view for [image], given the advisory link signal.
  ///
  /// [hasLink] only ever changes *wording*: an item that failed for want of a
  /// connection reads as waiting rather than as retrying while there is still no
  /// connection to retry over. It never changes what the queue will do.
  factory QueueItemView.of(QueuedImage image, {required bool hasLink}) {
    switch (image.status) {
      case ImageStatus.uploaded:
        return QueueItemView(
          image: image,
          tone: QueueItemTone.synced,
          status: 'Synced',
          detail: null,
        );

      case ImageStatus.uploading:
        // Not "Uploading now". The row is claimed and being attempted, which is
        // all the app knows and all it may say.
        return QueueItemView(
          image: image,
          tone: QueueItemTone.uploading,
          status: 'Uploading',
          detail: null,
        );

      case ImageStatus.failedPermanent:
        return QueueItemView(
          image: image,
          tone: QueueItemTone.failed,
          status: "Can't upload",
          detail: _permanentReason(image.lastFailure),
        );

      case ImageStatus.draft:
        // A draft is not a pending upload and does not normally reach this
        // screen; if one does, it is queued behind its batch being finished.
        return QueueItemView(
          image: image,
          tone: QueueItemTone.queued,
          status: 'In queue',
          detail: null,
        );

      case ImageStatus.pending:
        if (image.attemptCount == 0) {
          // **Nothing has failed yet.** Saying "retrying" here would invent a
          // problem the user does not have (`UX_SPEC.md` §4.1).
          return QueueItemView(
            image: image,
            tone: QueueItemTone.queued,
            status: 'In queue',
            detail: null,
          );
        }
        if (image.lastFailure == FailureCategory.offline && !hasLink) {
          return QueueItemView(
            image: image,
            tone: QueueItemTone.awaitingLink,
            status: 'Waiting for connection',
            detail: null,
          );
        }
        return QueueItemView(
          image: image,
          tone: QueueItemTone.retrying,
          status: 'Retrying',
          // **No denominator.** There is no attempt cap, so "3 of 5" would
          // promise an abandonment that never comes (`ADR-F12`, `FLT-UX-009`).
          detail: 'attempt ${image.attemptCount}',
        );
    }
  }

  /// The row this view describes.
  final QueuedImage image;

  /// Which of the six states it is in.
  final QueueItemTone tone;

  /// The state in words. Never a colour alone (`FLT-UX-005`).
  final String status;

  /// A qualifier — an attempt count, a reason — or `null`.
  final String? detail;

  /// The file's own name, which is what the user recognises.
  String get fileName {
    final int slash = image.localPath.lastIndexOf(RegExp(r'[/\\]'));
    return slash < 0 ? image.localPath : image.localPath.substring(slash + 1);
  }

  /// The full status line: the state, plus its qualifier when there is one.
  String get statusLine => detail == null ? status : '$status · $detail';

  /// One screen-reader sentence for the whole row.
  ///
  /// One label, not four nodes: a queue row read out as "thumbnail, IMG_0033,
  /// refresh, attempt 3" is four fragments the listener has to reassemble
  /// (`UX_SPEC.md` §6).
  String get semanticLabel => '$fileName, ${statusLine.toLowerCase()}';

  static String? _permanentReason(FailureCategory? category) {
    switch (category) {
      case FailureCategory.missingLocalFile:
        return 'file missing';
      case FailureCategory.serverRejected:
        return 'rejected by the server';
      case FailureCategory.offline:
      case FailureCategory.timeout:
      case FailureCategory.serverTransient:
      case FailureCategory.unexpected:
      case null:
        // Everything else is retryable and cannot reach this branch. No reason
        // is better than a manufactured one.
        return null;
    }
  }

  @override
  List<Object?> get props => <Object?>[image, tone, status, detail];
}
