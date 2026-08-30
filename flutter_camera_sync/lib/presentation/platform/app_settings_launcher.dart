import 'package:flutter/services.dart';

/// Opens this application's own entry in the OS settings.
///
/// A port with one method, and it exists for one reason: the camera permission
/// panel offers "Open settings" after repeated refusals (`ADR-F22`), and that
/// offer has to be testable without a platform channel. A widget test supplies
/// a recording implementation; the app supplies [MethodChannelAppSettingsLauncher].
///
/// **What the offer means.** It is a *recovery route*, not a verdict. The app
/// never claims the OS permanently denied anything — on Android it cannot know
/// that (`RESEARCH.md` `FR-12`) — it simply offers the one action that always
/// works when asking again has stopped helping.
abstract interface class AppSettingsLauncher {
  /// Asks the platform to show this app's settings page.
  ///
  /// Returns whether the platform accepted the request. Never throws: failing to
  /// open a settings screen is a disappointment, not a crash, and the panel
  /// still offers "Try again" beside it.
  Future<bool> openAppSettings();
}

/// The Android implementation, over this app's own `MainActivity`.
///
/// Deliberately **not** `permission_handler`. A second permission library for
/// one intent was rejected twice on the evidence (`RESEARCH.md` §2, `ADR-F22`);
/// what is actually needed is fifteen lines of Kotlin firing
/// `ACTION_APPLICATION_DETAILS_SETTINGS`, and that is what this calls.
class MethodChannelAppSettingsLauncher implements AppSettingsLauncher {
  /// Creates the launcher, optionally over an injected [channel].
  const MethodChannelAppSettingsLauncher({MethodChannel? channel})
    : _channel = channel ?? _defaultChannel;

  static const MethodChannel _defaultChannel = MethodChannel(
    'io.github.rktuhinbd.presencelens.capture/app_settings',
  );

  /// The method invoked on the host.
  static const String openMethod = 'openAppSettings';

  final MethodChannel _channel;

  @override
  Future<bool> openAppSettings() async {
    try {
      final bool? opened = await _channel.invokeMethod<bool>(openMethod);
      return opened ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      // The host has no handler — an iOS build, or a unit-test binding. Neither
      // is a reason to fail a screen the user is looking at.
      return false;
    }
  }
}
