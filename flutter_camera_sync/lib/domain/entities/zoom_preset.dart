import 'package:equatable/equatable.dart';

/// Where a preset's label came from — which is the same question as how much it
/// may claim.
///
/// This enum exists so that "we know this is the ultra-wide lens" and "the
/// device said it can reach 0.6" cannot be confused at the point of rendering.
/// The assessment's own example text is truncated in the source PDF (root
/// `AMB-01`), so the honest move is to make the provenance explicit rather than
/// to guess the intended labels (`ADR-F03`, `FLT-CAM-016`).
enum ZoomPresetProvenance {
  /// `1.0x` — the active camera's own baseline. True by definition: it is what
  /// `setZoomLevel(1.0)` means.
  baseline,

  /// Derived from the zoom range the device actually reported.
  ///
  /// A `0.6x` here means the device said its minimum is 0.6 — not that a
  /// marketing "0.5x ultra-wide" exists.
  deviceReportedRange,

  /// The platform named the lens. iOS only, today (`RESEARCH.md` `FR-04`).
  platformReportedLens,
}

/// One rounded zoom control the UI may offer.
///
/// Carries the exact zoom [value] to apply *and* the [label] to print, because
/// those are not the same thing: a label is rounded for legibility, and the
/// value must not be rounded or the control would set a zoom the user did not
/// choose.
class ZoomPreset extends Equatable {
  /// Creates a preset.
  const ZoomPreset({
    required this.value,
    required this.label,
    required this.provenance,
  });

  /// The exact zoom level to apply.
  final double value;

  /// What to print. Never asserts an optical multiplier the platform did not
  /// report (`FLT-CAM-016`).
  final String label;

  /// Where the label's authority comes from.
  final ZoomPresetProvenance provenance;

  /// Whether this preset claims knowledge of the physical lens.
  ///
  /// Used by the test that guards `FLT-CAM-016`: on a device reporting no lens
  /// identity, this must be false for every preset offered.
  bool get claimsOpticalIdentity =>
      provenance == ZoomPresetProvenance.platformReportedLens;

  @override
  List<Object?> get props => <Object?>[value, label, provenance];

  @override
  String toString() => 'ZoomPreset($label = $value, ${provenance.name})';
}
