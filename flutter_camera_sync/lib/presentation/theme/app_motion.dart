import 'package:flutter/widgets.dart';

/// The motion tokens from `UX_SPEC.md` §2.5, and the one rule that governs all
/// of them.
///
/// **Reduced motion removes movement, never feedback** (`FLT-UX-004`, `RU-03`).
/// Every duration is resolved through [resolve], which collapses to zero when
/// the platform has asked for reduced animation — so an animation disappears
/// while the state change it was explaining still happens, still announces, and
/// still leaves its indicator on screen.
abstract final class AppMotion {
  /// Press feedback.
  static const Duration instant = Duration(milliseconds: 80);

  /// Reticle appearance, preset selection.
  static const Duration quick = Duration(milliseconds: 120);

  /// State cross-fades, list item changes.
  static const Duration standard = Duration(milliseconds: 200);

  /// Route transitions, the capture-to-batch travel.
  static const Duration deliberate = Duration(milliseconds: 320);

  /// How long the focus reticle holds before it fades.
  static const Duration reticleHold = Duration(milliseconds: 600);

  /// How long it holds when animation is disabled.
  ///
  /// Longer, because there is no fade to carry the ending: the indicator has to
  /// stay legible for its whole life and then simply go.
  static const Duration reticleHoldReduced = Duration(milliseconds: 800);

  /// How long a completed batch shows "Synced" before it collapses out.
  static const Duration completionHold = Duration(seconds: 2);

  /// Whether the viewer has asked for reduced motion.
  static bool isReduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [duration], or zero when animation is disabled.
  static Duration resolve(BuildContext context, Duration duration) =>
      isReduced(context) ? Duration.zero : duration;
}
