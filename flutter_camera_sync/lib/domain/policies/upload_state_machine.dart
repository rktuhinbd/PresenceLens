import '../entities/image_status.dart';

/// Raised when a caller asks for a transition the lifecycle does not allow.
class IllegalStateTransition implements Exception {
  /// Creates the exception for a rejected [from] to [to] move.
  const IllegalStateTransition(this.from, this.to);

  /// The status the item was in.
  final ImageStatus from;

  /// The status the caller asked for.
  final ImageStatus to;

  @override
  String toString() =>
      'IllegalStateTransition: ${from.wireName} -> ${to.wireName}';
}

/// The single definition of which image transitions are legal.
///
/// It lives here, in pure Dart, so the rule is testable without a database and
/// so no call site can invent its own version of it (`FLT-SYNC-001`). The DAO
/// enforces the same rule a second time in SQL, because a rule that only exists
/// in Dart cannot constrain a second isolate.
class UploadStateMachine {
  /// Creates the state machine. It carries no state of its own.
  const UploadStateMachine();

  static const Map<ImageStatus, Set<ImageStatus>> _legal =
      <ImageStatus, Set<ImageStatus>>{
        ImageStatus.draft: <ImageStatus>{ImageStatus.pending},
        ImageStatus.pending: <ImageStatus>{ImageStatus.uploading},
        ImageStatus.uploading: <ImageStatus>{
          // Success.
          ImageStatus.uploaded,
          // A retryable failure returns the item to the queue; it does not get
          // a resting state of its own.
          ImageStatus.pending,
          // A permanent failure leaves the work set.
          ImageStatus.failedPermanent,
          // Lease reclaim: a claim abandoned by process death is taken over by
          // the next processor, which re-stamps it. Listed explicitly because
          // it is a real transition, not an accident (`FLT-SYNC-009`).
          ImageStatus.uploading,
        },
        ImageStatus.uploaded: <ImageStatus>{},
        ImageStatus.failedPermanent: <ImageStatus>{},
      };

  /// Statuses from which nothing further may happen.
  static const Set<ImageStatus> terminalStatuses = <ImageStatus>{
    ImageStatus.uploaded,
    ImageStatus.failedPermanent,
  };

  /// Whether moving [from] to [to] is allowed.
  bool isLegal(ImageStatus from, ImageStatus to) =>
      _legal[from]?.contains(to) ?? false;

  /// Throws [IllegalStateTransition] unless the move is allowed.
  void requireLegal(ImageStatus from, ImageStatus to) {
    if (!isLegal(from, to)) {
      throw IllegalStateTransition(from, to);
    }
  }

  /// The statuses reachable from [from].
  Set<ImageStatus> transitionsFrom(ImageStatus from) =>
      Set<ImageStatus>.unmodifiable(_legal[from] ?? const <ImageStatus>{});

  /// Whether [status] is terminal.
  bool isTerminal(ImageStatus status) => terminalStatuses.contains(status);
}
