import 'package:connectivity_plus/connectivity_plus.dart';

import '../../domain/ports/connectivity_port.dart';

/// Reads the device's reported link state through `connectivity_plus`.
///
/// Everything this class reports is **advisory**. The package's own
/// documentation says a connection type *"does not guarantee that there is an
/// Internet access"*, and the failure mode the assessment names — low bandwidth
/// — is precisely the one where the link is present and the transfer still
/// fails. Nothing in this app gates an upload on what this class returns
/// (`ADR-F05`, `FLT-SYNC-011`).
class ConnectivityPlusAdapter implements ConnectivityPort {
  /// Creates the adapter, optionally over an existing [connectivity] instance.
  ConnectivityPlusAdapter({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> hasLink() async {
    final List<ConnectivityResult> results = await _connectivity
        .checkConnectivity();
    return _hasLink(results);
  }

  @override
  Stream<bool> get linkChanges =>
      _connectivity.onConnectivityChanged.map(_hasLink).distinct();

  /// Any transport at all counts as a link.
  ///
  /// The type is deliberately not inspected: preferring Wi-Fi over mobile here
  /// would be the app pretending to know which one can reach a server.
  static bool _hasLink(List<ConnectivityResult> results) =>
      results.any((ConnectivityResult r) => r != ConnectivityResult.none);
}
