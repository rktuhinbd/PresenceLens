import 'package:flutter/widgets.dart';

/// The camera route's control palette, fixed dark and independent of the system
/// theme (`UX_SPEC.md` §2.2, `ADR-F07`).
///
/// A light-mode camera UI would be unreadable outdoors and would wash out the
/// preview, so this is the one surface in the app that does not derive its
/// colour from the Material scheme. The values are literals *because* they are
/// deliberately not scheme roles — deriving them would reintroduce exactly the
/// theme-following behaviour the decision rejected.
abstract final class CameraPalette {
  /// Gradient scrim colour, top and bottom.
  static const Color scrim = Color(0xFF000000);

  /// Icons and labels over a scrim.
  static const Color control = Color(0xEBFFFFFF);

  /// Circular backing behind a control.
  static const Color controlBackground = Color(0x73000000);

  /// Text of the selected zoom preset.
  static const Color controlActive = Color(0xFF00E5A8);

  /// Backing of the selected zoom preset.
  static const Color controlActiveBackground = Color(0x9E000000);

  /// The shutter's ring and fill.
  static const Color shutter = Color(0xFFFFFFFF);

  /// The connective accent: focus reticle, batch count badge.
  ///
  /// The seed colour lifted for a dark surface. It has exactly one meaning on
  /// this screen — *this is the current value* — which is what lets the eye
  /// follow it from where the user aimed to where the capture was stored
  /// (`UX_SPEC.md` §7.1).
  static const Color accent = Color(0xFF00E5A8);

  /// The offline hint.
  static const Color warning = Color(0xFFFFB74D);

  /// Panel background for a state with no live preview behind it.
  static const Color panel = Color(0xFF101416);

  /// The top scrim gradient.
  static const LinearGradient topScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xB3000000), Color(0x00000000)],
  );

  /// The bottom scrim gradient.
  ///
  /// Stronger than the top one — it reaches 88% black — because every control
  /// under it may sit over a bright document in daylight.
  static const LinearGradient bottomScrim = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: <Color>[Color(0xE0000000), Color(0x00000000)],
  );
}
