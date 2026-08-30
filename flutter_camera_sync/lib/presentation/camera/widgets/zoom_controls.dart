import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/entities/camera_capabilities.dart';
import '../../../domain/entities/zoom_preset.dart';
import '../../theme/camera_palette.dart';

/// The vertical zoom slider (`FLT-CAM-004`).
///
/// Right edge, because that is where a thumb reaches one-handed; a horizontal
/// slider along the bottom would collide with the shutter (`UX_SPEC.md` §3).
///
/// **Its bounds come from the open camera, never from a constant.** They are the
/// min and max the session reported, so a camera that cannot go below 1.0 gets
/// no sub-1.0 travel and a camera that can gets exactly as much as it said
/// (`FLT-CAM-007`).
///
/// It is an equal-status control, not a fallback for pinch: zoom has to be fully
/// operable without a gesture (`FLT-UX-013`).
class ZoomSlider extends StatelessWidget {
  /// Creates a slider over [range].
  const ZoomSlider({
    required this.range,
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// The active camera's reported zoom span.
  final ZoomRange range;

  /// The one shared zoom value (`FLT-CAM-006`).
  final double value;

  /// Called with a requested zoom level.
  final ValueChanged<double> onChanged;

  /// Height of the track.
  static const double trackHeight = 200;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: SizedBox(
        // 48 dp wide so the hit area meets the target minimum even though the
        // painted track is narrower (`FLT-UX-002`).
        width: 48,
        height: trackHeight + 48,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _EndLabel(_format(range.max)),
            Expanded(
              child: RotatedBox(
                quarterTurns: 3,
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: CameraPalette.accent,
                    inactiveTrackColor: CameraPalette.control.withValues(
                      alpha: 0.28,
                    ),
                    thumbColor: CameraPalette.shutter,
                    overlayColor: CameraPalette.accent.withValues(alpha: 0.16),
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: range.clamp(value),
                    min: range.min,
                    max: range.max,
                    onChanged: onChanged,
                    // The value a screen reader reads out is the zoom itself,
                    // not a percentage of a range nobody can see.
                    semanticFormatterCallback: (double v) =>
                        'Zoom ${_format(v)}',
                  ),
                ),
              ),
            ),
            _EndLabel(_format(range.min)),
          ],
        ),
      ),
    );
  }

  static String _format(double value) {
    final double rounded = (value * 10).roundToDouble() / 10;
    return rounded == rounded.roundToDouble()
        ? '${rounded.toStringAsFixed(0)}x'
        : '${rounded.toStringAsFixed(1)}x';
  }
}

class _EndLabel extends StatelessWidget {
  const _EndLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Text(
        text,
        style: const TextStyle(
          color: CameraPalette.control,
          fontSize: 11,
          fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// The rounded zoom presets (`FLT-CAM-005`).
///
/// **Every pill here is a zoom *ratio*, never a claim about a lens.** The list
/// is produced by `ZoomPresetPolicy` from the range the open session reported,
/// and each preset carries its own provenance, so a label that would assert
/// optical identity cannot be rendered on a platform that never reported one
/// (`FLT-CAM-016`, `ADR-F03`).
///
/// A `1x` pill on a camera that cannot zoom would invite a tap that does
/// nothing, so the row is absent entirely when the range is not adjustable.
class ZoomPresetRow extends StatelessWidget {
  /// Creates a preset row.
  const ZoomPresetRow({
    required this.presets,
    required this.currentZoom,
    required this.onSelected,
    super.key,
  });

  /// The presets the device's own range justifies.
  final List<ZoomPreset> presets;

  /// The one shared zoom value, for deciding which pill is active.
  final double currentZoom;

  /// Called with the preset the user chose.
  final ValueChanged<ZoomPreset> onSelected;

  @override
  Widget build(BuildContext context) {
    if (presets.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 48,
      child: ListView.separated(
        // Scrolls rather than shrinking: a preset that shrank below 48 dp to fit
        // a small screen would stop being usable to fit a screen it is used on
        // (`UX_SPEC.md` §8).
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: presets.length,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final ZoomPreset preset = presets[index];
          return _PresetPill(
            preset: preset,
            isActive: _isActive(preset, index),
            onTap: () {
              unawaited(HapticFeedback.selectionClick());
              onSelected(preset);
            },
          );
        },
      ),
    );
  }

  /// Which pill reads as current.
  ///
  /// The nearest preset at or below the live zoom, so a pinch between 1x and 2x
  /// leaves 1x lit rather than lighting nothing.
  bool _isActive(ZoomPreset preset, int index) {
    int best = 0;
    for (int i = 0; i < presets.length; i++) {
      if (presets[i].value <= currentZoom + 0.0001) {
        best = i;
      }
    }
    return best == index;
  }
}

class _PresetPill extends StatelessWidget {
  const _PresetPill({
    required this.preset,
    required this.isActive,
    required this.onTap,
  });

  final ZoomPreset preset;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isActive,
      label: 'Zoom ${preset.label}',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? CameraPalette.controlActiveBackground
                : CameraPalette.controlBackground,
            border: isActive
                ? Border.all(color: CameraPalette.controlActive, width: 1.5)
                : null,
          ),
          child: ExcludeSemantics(
            child: Text(
              preset.label,
              style: TextStyle(
                // Accent on a *darker* pill. White-on-translucent-white failed
                // contrast badly over a bright document, which is the defect the
                // prototype gate caught (`UX_SPEC.md` §2.2).
                color: isActive
                    ? CameraPalette.controlActive
                    : CameraPalette.control,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
