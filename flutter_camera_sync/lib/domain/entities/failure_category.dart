/// Why an upload attempt did not succeed.
///
/// This is the app's own taxonomy, not a passthrough of whatever a plugin or a
/// transport happened to throw: the queue's behaviour must be decided from a
/// closed set that can be reasoned about and tested. The mapping from a
/// category to "retry it" or "stop retrying it" belongs to `FailureClassifier`
/// — the category itself carries no verdict.
enum FailureCategory {
  /// No usable link at the moment of the attempt.
  offline('OFFLINE'),

  /// The attempt was made but did not complete in time.
  timeout('TIMEOUT'),

  /// The server answered, but with a fault of its own (a 5xx equivalent).
  serverTransient('SERVER_TRANSIENT'),

  /// The server answered and rejected the payload (a 4xx equivalent).
  serverRejected('SERVER_REJECTED'),

  /// The durable file this row points at is gone.
  missingLocalFile('MISSING_LOCAL_FILE'),

  /// Something not otherwise classified. Treated as retryable: keeping a photo
  /// is cheaper than discarding one.
  unexpected('UNEXPECTED');

  const FailureCategory(this.wireName);

  /// The stable string written to the `last_failure` column.
  final String wireName;

  /// Resolves a persisted [wireName] back to a value.
  static FailureCategory fromWireName(String value) {
    for (final FailureCategory category in FailureCategory.values) {
      if (category.wireName == value) {
        return category;
      }
    }
    throw ArgumentError.value(value, 'value', 'Unknown FailureCategory');
  }
}

/// What the queue should do about a [FailureCategory].
enum FailureDisposition {
  /// Return the item to the queue and try again later.
  retryable,

  /// Remove the item from the work set; retrying cannot help.
  permanent,
}
