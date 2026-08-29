import '../entities/image_status.dart';

/// Decides whether a durable local file may be removed after its upload was
/// confirmed (`FLT-SYNC-016`, a BONUS row).
///
/// Deletion is **off by default**. The approved Upload Manager design renders a
/// thumbnail on every queue row including synced ones (`UX_SPEC.md` §3.3), and
/// deleting the file would leave those rows with nothing to show. The mechanism
/// and its ordering are implemented and tested here so the switch is a one-line
/// decision at gate F6 rather than a redesign; the conflict itself is recorded
/// in `ADR-F16`.
///
/// Whatever the setting, deletion is **housekeeping, never delivery**: it
/// happens only after `UPLOADED` is durably persisted, and a failed deletion
/// never returns an item to the queue (`SYNC_ENGINE.md` §5).
class RetentionPolicy {
  /// Creates the policy.
  const RetentionPolicy({this.deleteAfterUpload = false});

  /// Whether a confirmed-uploaded image's file should be removed from disk.
  final bool deleteAfterUpload;

  /// Whether the file behind an image in [status] may now be deleted.
  bool shouldDeleteLocalFile(ImageStatus status) =>
      deleteAfterUpload && status == ImageStatus.uploaded;
}
