import 'package:equatable/equatable.dart';

import 'failure_category.dart';
import 'image_status.dart';

/// One captured image and everything the sync engine knows about it.
///
/// The image *bytes* are not here and are not in the database — they live on
/// the filesystem at [localPath] ([root ADR-005], `ADR-F02`). This row is the
/// durable record that the bytes exist and still owe the user an upload.
class QueuedImage extends Equatable {
  /// Creates a queue row.
  const QueuedImage({
    required this.id,
    required this.batchId,
    required this.localPath,
    required this.capturedAt,
    required this.status,
    this.attemptCount = 0,
    this.lastAttemptAt,
    this.claimedAt,
    this.lastFailure,
  });

  /// Client-generated identifier.
  ///
  /// Also the **idempotency key** sent with the upload, so a retry after an
  /// ambiguous failure is recognisable to a real server as the same image
  /// (`FLT-SYNC-010`). Generated once, at capture, and never regenerated.
  final String id;

  /// The batch this image belongs to.
  final String batchId;

  /// Absolute path to the durable file in app-owned storage.
  final String localPath;

  /// When the image was captured. UTC. Drives queue ordering.
  final DateTime capturedAt;

  /// Where the image is in its lifecycle.
  final ImageStatus status;

  /// How many upload attempts have already failed.
  ///
  /// Recorded for display and diagnosis. It is **not** a give-up threshold:
  /// discarding an image after N attempts would violate `FLT-SYNC-003`
  /// (`ADR-F12`).
  final int attemptCount;

  /// When the last attempt was made, or `null` if none has been.
  final DateTime? lastAttemptAt;

  /// The lease stamp of the current claim, or `null` when unclaimed.
  ///
  /// Kept separate from [lastAttemptAt] deliberately: this one is a *lease*,
  /// that one is *history*. Conflating them makes stale-claim recovery
  /// ambiguous.
  final DateTime? claimedAt;

  /// Why the most recent attempt failed, or `null` if none has.
  final FailureCategory? lastFailure;

  /// True when this item failed at least once and is waiting to be tried again.
  ///
  /// Derived rather than stored, which is why there is no `RETRYABLE_FAILURE`
  /// status (`DATA_MODEL.md` §3).
  bool get isRetrying => status == ImageStatus.pending && attemptCount > 0;

  /// A copy with the given fields replaced.
  QueuedImage copyWith({
    ImageStatus? status,
    int? attemptCount,
    DateTime? lastAttemptAt,
    DateTime? claimedAt,
    FailureCategory? lastFailure,
    bool clearClaimedAt = false,
    bool clearLastFailure = false,
  }) {
    return QueuedImage(
      id: id,
      batchId: batchId,
      localPath: localPath,
      capturedAt: capturedAt,
      status: status ?? this.status,
      attemptCount: attemptCount ?? this.attemptCount,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      claimedAt: clearClaimedAt ? null : (claimedAt ?? this.claimedAt),
      lastFailure: clearLastFailure ? null : (lastFailure ?? this.lastFailure),
    );
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    batchId,
    localPath,
    capturedAt,
    status,
    attemptCount,
    lastAttemptAt,
    claimedAt,
    lastFailure,
  ];
}
