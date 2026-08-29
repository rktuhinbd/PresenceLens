/// Source of the identifiers used for batches and images.
///
/// An interface rather than a direct call because these ids are also the
/// upload's idempotency keys and the on-disk file names, so tests need them to
/// be predictable.
abstract interface class IdGenerator {
  /// A new identifier, unique for practical purposes.
  String newId();
}
