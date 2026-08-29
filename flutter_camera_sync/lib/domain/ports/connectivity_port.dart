/// An **advisory** view of whether the device has a network link.
///
/// It is never proof that anything is reachable. `connectivity_plus` says so
/// itself, and the case the assessment names — low bandwidth — is exactly the
/// case where a link is present and the transfer still fails. This port may
/// influence *when the app bothers trying* and *what the user is told*; the
/// upload attempt alone decides whether an upload succeeded (`ADR-F05`,
/// `FLT-SYNC-011`).
abstract interface class ConnectivityPort {
  /// Whether the device currently reports any network link at all.
  Future<bool> hasLink();

  /// Emits whenever the reported link state changes.
  Stream<bool> get linkChanges;
}
