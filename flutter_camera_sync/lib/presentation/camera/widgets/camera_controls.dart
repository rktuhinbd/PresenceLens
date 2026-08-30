import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/entities/camera_device.dart';
import '../../../domain/policies/zoom_preset_policy.dart';
import '../../theme/app_motion.dart';
import '../../theme/camera_palette.dart';

/// The shutter (`FLT-CAM-014`).
///
/// 72 dp and centred low, because it is the one control that must be findable
/// without looking. Pressing it while a capture is already in flight is refused
/// **and shown to be refused** — the guard that makes exactly one photograph
/// happen lives in the cubit, and this only stops the user pressing into a wall.
class ShutterButton extends StatelessWidget {
  /// Creates a shutter.
  const ShutterButton({
    required this.onPressed,
    required this.isCapturing,
    super.key,
  });

  /// Called on press. `null` when the camera cannot take a photograph.
  final VoidCallback? onPressed;

  /// Whether a capture is in flight.
  final bool isCapturing;

  /// The control's diameter.
  static const double diameter = 72;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null && !isCapturing;
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Take photo',
      hint: isCapturing ? 'Capturing' : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled
            ? () {
                // Fires on the press, before any asynchronous work resolves.
                // Retained under reduced motion: a haptic is not motion
                // (`UX_SPEC.md` §7.1).
                unawaited(HapticFeedback.mediumImpact());
                onPressed!();
              }
            : null,
        child: AnimatedScale(
          // 4% compression, no bounce.
          scale: isCapturing ? 0.96 : 1,
          duration: AppMotion.resolve(context, AppMotion.instant),
          child: SizedBox(
            width: diameter,
            height: diameter,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: CameraPalette.shutter.withValues(
                        alpha: enabled ? 1 : 0.4,
                      ),
                      width: 3,
                    ),
                  ),
                  child: const SizedBox(width: diameter, height: diameter),
                ),
                Container(
                  width: diameter - 16,
                  height: diameter - 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: CameraPalette.shutter.withValues(
                      alpha: enabled ? 1 : 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A circular control over the scrim — camera switch, uploads, retry.
class CameraControlButton extends StatelessWidget {
  /// Creates a control.
  const CameraControlButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.value,
    super.key,
  });

  /// The glyph.
  final IconData icon;

  /// What the control does, for a screen reader.
  final String label;

  /// The control's current value, where it has one.
  final String? value;

  /// Called on press; `null` disables it.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      value: value,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: CameraPalette.controlBackground,
          ),
          child: ExcludeSemantics(
            child: Icon(icon, color: CameraPalette.control, size: 22),
          ),
        ),
      ),
    );
  }
}

/// The back-camera selector (`FLT-CAM-011`).
///
/// **It never names a lens the platform did not name.** The label comes from
/// `ZoomPresetPolicy.labelForCamera`, which returns an optical name only where
/// the platform reported one and an honest ordinal — "Camera 2" — everywhere
/// else. On Android that is everywhere, and a fabricated "0.5x" beside a camera
/// the app cannot identify is exactly the claim `ADR-F03` refuses to make.
///
/// One rear camera is not a choice, so with one the control is absent.
class CameraSelectorButton extends StatelessWidget {
  /// Creates a selector.
  const CameraSelectorButton({
    required this.cameras,
    required this.current,
    required this.onNext,
    this.policy = const ZoomPresetPolicy(),
    super.key,
  });

  /// Every back camera, in enumeration order.
  final List<CameraDevice> cameras;

  /// The camera currently open.
  final CameraDevice current;

  /// Called to move to the next camera; `null` while a capture is in flight.
  final VoidCallback? onNext;

  /// The policy that decides what a camera may be called.
  final ZoomPresetPolicy policy;

  @override
  Widget build(BuildContext context) {
    if (!policy.shouldOfferCameraSelector(cameras)) {
      return const SizedBox(width: 48, height: 48);
    }
    final int index = cameras.indexWhere(
      (CameraDevice c) => c.id == current.id,
    );
    return CameraControlButton(
      icon: Icons.cameraswitch_outlined,
      label: 'Switch camera',
      value:
          '${policy.labelForCamera(current).label}, '
          '${index < 0 ? 1 : index + 1} of ${cameras.length}',
      onPressed: onNext,
    );
  }
}

/// The batch thumbnail and its count badge (`FLT-BAT-007`, `FLT-BAT-008`).
///
/// Answers "did that register?" without a second screen. Absent at count zero:
/// a permanently visible empty frame is clutter, and a contextual control that
/// appears when it means something is the whole reason the chrome stays quiet.
class BatchThumbnail extends StatelessWidget {
  /// Creates a thumbnail stack.
  const BatchThumbnail({
    required this.count,
    required this.imagePath,
    required this.onTap,
    super.key,
  });

  /// How many images the open batch holds.
  final int count;

  /// The most recent capture's durable path, or `null`.
  final String? imagePath;

  /// Called on press.
  final VoidCallback? onTap;

  /// The frame's edge length.
  static const double size = 52;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return const SizedBox(width: size, height: size);
    }
    return Semantics(
      button: onTap != null,
      label: 'Current batch',
      value: count == 1 ? '1 photo' : '$count photos',
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: CameraPalette.controlBackground,
                      border: Border.all(
                        color: CameraPalette.control.withValues(alpha: 0.5),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _Preview(path: imagePath),
                  ),
                ),
              ),
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 22,
                    minHeight: 22,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: CameraPalette.accent,
                  ),
                  child: ExcludeSemantics(
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Color(0xFF06231B),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    final String? source = path;
    if (source == null) {
      return const Icon(
        Icons.photo_outlined,
        color: CameraPalette.control,
        size: 20,
      );
    }
    return Image.file(
      File(source),
      fit: BoxFit.cover,
      // A missing or unreadable file must not throw inside a live camera
      // screen. The count is the authoritative fact; the picture is a courtesy.
      errorBuilder:
          (BuildContext context, Object error, StackTrace? stackTrace) =>
              const Icon(
                Icons.photo_outlined,
                color: CameraPalette.control,
                size: 20,
              ),
    );
  }
}

/// The compact offline hint on the camera (`FLT-SYNC-011`).
///
/// One word, because there is no room for a sentence over a viewfinder and the
/// camera is not where the queue is explained — that is the Upload Manager's
/// job (`UX_SPEC.md` §4.1). It appears only when there is queued work *and* no
/// link; otherwise it is noise.
class CameraOfflineChip extends StatelessWidget {
  /// Creates the chip.
  const CameraOfflineChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Offline. Captures are safe on this device.',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: CameraPalette.controlBackground,
          borderRadius: BorderRadius.circular(999),
        ),
        child: ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.cloud_off_outlined,
                size: 16,
                color: CameraPalette.warning,
              ),
              const SizedBox(width: 6),
              Text(
                'Offline',
                style: const TextStyle(
                  color: CameraPalette.warning,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The route to Pending Uploads (`FLT-UX-012`).
///
/// **Present in every camera state, including the broken ones.** A user whose
/// camera will not open must still be able to reach the photographs they already
/// took; a queue trapped behind a failed preview is the one failure this screen
/// is not allowed to have (`UX_SPEC.md` §3).
class UploadsEntry extends StatelessWidget {
  /// Creates the entry.
  const UploadsEntry({
    required this.pendingCount,
    required this.onPressed,
    this.dark = true,
    super.key,
  });

  /// How many images still owe an upload.
  final int pendingCount;

  /// Called on press.
  final VoidCallback onPressed;

  /// Whether it is rendered over the camera's dark chrome.
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final Color foreground = dark
        ? CameraPalette.control
        : Theme.of(context).colorScheme.onSurface;
    return Semantics(
      button: true,
      label: 'Pending uploads',
      value: pendingCount == 0
          ? 'Nothing waiting'
          : '$pendingCount waiting to upload',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: dark ? CameraPalette.controlBackground : null,
            borderRadius: BorderRadius.circular(999),
          ),
          child: ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Uploads',
                  style: TextStyle(
                    color: foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (pendingCount > 0) ...<Widget>[
                  const SizedBox(width: 6),
                  Text(
                    '$pendingCount',
                    style: const TextStyle(
                      color: CameraPalette.accent,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                    ),
                  ),
                ],
                const SizedBox(width: 2),
                Icon(Icons.chevron_right, size: 20, color: foreground),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
