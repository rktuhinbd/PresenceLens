import '../entities/camera_capabilities.dart';
import '../entities/camera_device.dart';
import '../entities/zoom_preset.dart';

/// Chooses the rounded zoom controls to offer, from what the device reported.
///
/// **The honesty rule lives here.** The assessment asks for "rounded buttons
/// (0.5x, 1x, .. available back cameras)" and the sentence is truncated in the
/// source PDF, so the intended set is unknowable (root `AMB-01`). What *is*
/// knowable is that `camera_android_camerax` 0.7.4+7 never populates
/// `CameraDescription.lensType` — verified in the resolved package source
/// (`RESEARCH.md` `FR-04`) — so on Android the app has no basis for printing
/// "0.5x" beside a camera it cannot identify.
///
/// The resolution (`ADR-F03`): derive the set from the range the device
/// actually reported, and let every label carry its provenance so a reviewer
/// can see which claims are backed by the platform and which are arithmetic
/// (`FLT-CAM-005`, `FLT-CAM-016`).
class ZoomPresetPolicy {
  /// Creates the policy. It carries no state.
  const ZoomPresetPolicy();

  /// Stops offered above baseline, in order, each included only while the
  /// device's reported maximum reaches it.
  static const List<double> _upperStops = <double>[2, 5, 10];

  /// The presets to offer for a camera reporting [range].
  ///
  /// Always includes `1x`: it is the active camera's own baseline, true by
  /// definition on every camera. Below it, a preset appears **only** when
  /// `range.min < 1`, and it is labelled with the actual reported minimum — a
  /// device reporting 0.6 gets `0.6x`, not a rounded marketing `0.5x`.
  List<ZoomPreset> presetsFor(ZoomRange range) {
    final List<ZoomPreset> presets = <ZoomPreset>[];

    if (range.supportsSubBaseline) {
      presets.add(
        ZoomPreset(
          value: range.min,
          label: _label(range.min),
          provenance: ZoomPresetProvenance.deviceReportedRange,
        ),
      );
    }

    if (range.contains(1)) {
      presets.add(
        const ZoomPreset(
          value: 1,
          label: '1x',
          provenance: ZoomPresetProvenance.baseline,
        ),
      );
    } else {
      // A camera whose whole range sits above 1 has no meaningful "1x" to
      // offer; its own minimum is the honest baseline.
      presets.add(
        ZoomPreset(
          value: range.min,
          label: _label(range.min),
          provenance: ZoomPresetProvenance.deviceReportedRange,
        ),
      );
    }

    for (final double stop in _upperStops) {
      if (stop > range.min && stop <= range.max) {
        presets.add(
          ZoomPreset(
            value: stop,
            label: _label(stop),
            provenance: ZoomPresetProvenance.deviceReportedRange,
          ),
        );
      }
    }

    return List<ZoomPreset>.unmodifiable(presets);
  }

  /// Whether a preset row is worth showing at all for [range].
  ///
  /// One inert pill on a camera that cannot zoom is worse than no row: it
  /// invites a tap that does nothing (`UX_SPEC.md` §4).
  bool shouldOfferPresets(ZoomRange range) => range.isAdjustable;

  /// A label for one of the back cameras in a selector.
  ///
  /// Where the platform named the lens, the name is used and the label says so
  /// through its provenance. Where it did not — which is **every camera on
  /// Android** — the fallback is an ordinal, because "Camera 2" is a true
  /// statement about enumeration order and "0.5x" would be a false statement
  /// about optics.
  ZoomPreset labelForCamera(CameraDevice device) {
    switch (device.lensKind) {
      case CameraLensKind.ultraWide:
        return const ZoomPreset(
          value: 1,
          label: 'Ultra wide',
          provenance: ZoomPresetProvenance.platformReportedLens,
        );
      case CameraLensKind.wide:
        return const ZoomPreset(
          value: 1,
          label: 'Wide',
          provenance: ZoomPresetProvenance.platformReportedLens,
        );
      case CameraLensKind.telephoto:
        return const ZoomPreset(
          value: 1,
          label: 'Telephoto',
          provenance: ZoomPresetProvenance.platformReportedLens,
        );
      case CameraLensKind.unknown:
        return ZoomPreset(
          value: 1,
          label: 'Camera ${device.ordinalAmongFacing + 1}',
          provenance: ZoomPresetProvenance.deviceReportedRange,
        );
    }
  }

  /// Whether a camera selector is worth showing.
  ///
  /// One rear camera is not a choice.
  bool shouldOfferCameraSelector(List<CameraDevice> backCameras) =>
      backCameras.length > 1;

  /// Formats a zoom value the way a viewfinder does: no trailing `.0`, one
  /// decimal otherwise.
  String _label(double value) {
    final double rounded = (value * 10).roundToDouble() / 10;
    if (rounded == rounded.roundToDouble()) {
      return '${rounded.toStringAsFixed(0)}x';
    }
    return '${rounded.toStringAsFixed(1)}x';
  }
}
