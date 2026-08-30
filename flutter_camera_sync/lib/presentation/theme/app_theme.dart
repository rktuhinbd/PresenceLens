import 'package:flutter/material.dart';

/// The Material 3 themes every non-camera surface renders with.
///
/// One seed, both brightnesses (`UX_SPEC.md` §2.1). Colour is expressed through
/// M3 *roles* rather than literals so light and dark are one definition rather
/// than two palettes that drift apart — which is also what makes `FLT-UX-008`
/// checkable by a test instead of by eye.
///
/// The camera route deliberately does **not** use these. It has a fixed dark
/// control palette that ignores the system theme, because the content behind
/// its controls is always a live image ([CameraPalette], `ADR-F07`).
abstract final class AppTheme {
  /// Seed colour, shared with the native attendance app so the two read as one
  /// product family.
  static const Color seedColor = Color(0xFF00A884);

  /// The light theme.
  static ThemeData light() => _build(Brightness.light);

  /// The dark theme.
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      // Tonal elevation, not shadow: the Upload Manager is a work queue, and a
      // stack of drop shadows over a dense list reads as clutter
      // (`UX_SPEC.md` §2.4).
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: scheme.surfaceTint,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    );
  }
}
