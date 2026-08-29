/// The lifecycle of one queued image.
///
/// Specified in `docs/flutter/DATA_MODEL.md` §3. There is deliberately **no**
/// `RETRYABLE_FAILURE` state: a retryable failure returns the row to [pending]
/// and increments its attempt count. A second resting state would be a second
/// place for work to get stuck. "Retrying" is derived
/// (`status == pending && attemptCount > 0`), not stored.
enum ImageStatus {
  /// Captured and durably on disk, but its batch is not enqueued yet.
  draft('DRAFT'),

  /// Eligible for upload. The only status a processor may claim outright.
  pending('PENDING'),

  /// Claimed by a processor; `claimedAt` holds the lease stamp.
  uploading('UPLOADING'),

  /// Confirmed by the API. Terminal.
  uploaded('UPLOADED'),

  /// Unprocessable — it will not be retried. Terminal.
  failedPermanent('FAILED_PERMANENT');

  const ImageStatus(this.wireName);

  /// The stable string written to the `status` column.
  final String wireName;

  /// True when the item is still work the sync engine owes the user.
  ///
  /// [uploaded] is done; [failedPermanent] has deliberately left the work set
  /// so one unprocessable item cannot stop the queue draining (I10).
  bool get isOutstanding =>
      this == ImageStatus.draft ||
      this == ImageStatus.pending ||
      this == ImageStatus.uploading;

  /// Resolves a persisted [wireName] back to a value.
  static ImageStatus fromWireName(String value) {
    for (final ImageStatus status in ImageStatus.values) {
      if (status.wireName == value) {
        return status;
      }
    }
    throw ArgumentError.value(value, 'value', 'Unknown ImageStatus');
  }
}
