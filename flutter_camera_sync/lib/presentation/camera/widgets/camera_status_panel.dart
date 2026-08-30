import 'package:flutter/material.dart';

import '../../theme/camera_palette.dart';

/// The panel shown wherever there is no live preview to show.
///
/// **A designed state, not a blank screen** (`FLT-ERR-001` … `FLT-ERR-004`).
/// Every one of them explains what happened in the user's terms, offers whatever
/// recovery is genuinely available, and — crucially — leaves the Pending Uploads
/// entry in the bar above it, because captures already taken must never be
/// trapped behind a camera that will not open.
class CameraStatusPanel extends StatelessWidget {
  /// Creates a panel.
  const CameraStatusPanel({
    required this.icon,
    required this.title,
    required this.message,
    this.reassurance,
    this.primaryAction,
    this.secondaryAction,
    this.isBusy = false,
    super.key,
  });

  /// The glyph above the title.
  final IconData icon;

  /// One short line naming what happened.
  final String title;

  /// What it means and what the user can do.
  final String message;

  /// The sentence about the photographs that already exist, when there are any.
  final String? reassurance;

  /// The action most likely to help.
  final Widget? primaryAction;

  /// A second, lesser action.
  final Widget? secondaryAction;

  /// Whether to show progress instead of an icon.
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: CameraPalette.panel,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(32, 96, 32, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (isBusy)
                    const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: CameraPalette.accent,
                      ),
                    )
                  else
                    Icon(icon, size: 44, color: CameraPalette.control),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: CameraPalette.control,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: CameraPalette.control.withValues(alpha: 0.72),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  if (primaryAction != null) ...<Widget>[
                    const SizedBox(height: 24),
                    primaryAction!,
                  ],
                  if (secondaryAction != null) ...<Widget>[
                    const SizedBox(height: 8),
                    secondaryAction!,
                  ],
                  if (reassurance != null) ...<Widget>[
                    const SizedBox(height: 32),
                    Text(
                      reassurance!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: CameraPalette.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A filled action styled for the camera's fixed dark palette.
class CameraPanelAction extends StatelessWidget {
  /// Creates a primary action.
  const CameraPanelAction({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  }) : _secondary = false;

  /// Creates a lower-emphasis action.
  const CameraPanelAction.secondary({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  }) : _secondary = true;

  /// The button's words.
  final String label;

  /// Called on press.
  final VoidCallback onPressed;

  /// An optional leading glyph.
  final IconData? icon;

  final bool _secondary;

  @override
  Widget build(BuildContext context) {
    final ButtonStyle style = ButtonStyle(
      minimumSize: WidgetStateProperty.all(const Size(0, 48)),
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 24),
      ),
    );
    if (_secondary) {
      return TextButton(
        onPressed: onPressed,
        style: style.copyWith(
          foregroundColor: WidgetStateProperty.all(CameraPalette.control),
        ),
        child: Text(label),
      );
    }
    return FilledButton.icon(
      onPressed: onPressed,
      icon: icon == null ? null : Icon(icon),
      label: Text(label),
      style: style.copyWith(
        backgroundColor: WidgetStateProperty.all(CameraPalette.accent),
        foregroundColor: WidgetStateProperty.all(const Color(0xFF06231B)),
      ),
    );
  }
}
