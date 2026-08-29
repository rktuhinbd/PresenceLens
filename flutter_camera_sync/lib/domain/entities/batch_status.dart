/// The lifecycle of a capture batch.
///
/// Specified in `docs/flutter/DATA_MODEL.md` §3. The legal transitions between
/// these values are owned by `BatchPolicy`, not by any caller.
enum BatchStatus {
  /// Open and accepting captures. At most one batch is [draft] at a time
  /// (invariant I3).
  draft('DRAFT'),

  /// Closed by the user and handed to the sync engine. Accepts no further
  /// captures. Being [queued] is a *local durable* fact, not a network one.
  queued('QUEUED'),

  /// Every image in the batch was confirmed uploaded. Terminal.
  completed('COMPLETED');

  const BatchStatus(this.wireName);

  /// The stable string written to the `status` column.
  ///
  /// Deliberately not `Enum.name`: renaming a Dart identifier would otherwise
  /// silently invalidate every row already on a user's device.
  final String wireName;

  /// Resolves a persisted [wireName] back to a value.
  ///
  /// Throws [ArgumentError] for an unknown string rather than defaulting, so a
  /// schema mistake surfaces at the read that caused it.
  static BatchStatus fromWireName(String value) {
    for (final BatchStatus status in BatchStatus.values) {
      if (status.wireName == value) {
        return status;
      }
    }
    throw ArgumentError.value(value, 'value', 'Unknown BatchStatus');
  }
}
