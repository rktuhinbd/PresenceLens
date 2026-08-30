import '../entities/camera_capabilities.dart';

/// Everything the app decides about a zoom value, with no camera present.
///
/// Pure so that the pinch arithmetic — the part with a genuine failure mode —
/// is verified on the host rather than by pinching a phone and squinting
/// (`FLT-CAM-003`, `FLT-CAM-007`).
class ZoomPolicy {
  /// Creates the policy. It carries no state.
  const ZoomPolicy();

  /// [requested] confined to what [range] says the camera accepts.
  ///
  /// No hard-coded bounds anywhere: 1.0 is not assumed to be the minimum,
  /// because CameraX reports real sub-1 ratios on hardware that has them
  /// (`FLT-CAM-007`).
  double clamp(double requested, ZoomRange range) => range.clamp(requested);

  /// The zoom a pinch has reached, given the zoom it started from.
  ///
  /// **Anchored, not accumulated.** [baseline] is the zoom at the moment the
  /// gesture began and does not move for the life of the gesture; [scale] is
  /// the framework's cumulative scale since that moment. Multiplying the
  /// *current* zoom by each frame's scale instead is the classic drift bug: the
  /// zoom runs away under the fingers and never returns to where it started
  /// when they do.
  ///
  /// A scale that is not a positive finite number cannot describe a pinch, so
  /// the baseline is held rather than inventing a movement from it.
  double forPinch({
    required double baseline,
    required double scale,
    required ZoomRange range,
  }) {
    if (!scale.isFinite || scale <= 0) {
      return range.clamp(baseline);
    }
    return range.clamp(range.clamp(baseline) * scale);
  }

  /// The zoom a camera should start at, and return to after a switch.
  ///
  /// `1.0` when the camera can do it, because that is the baseline the user
  /// expects a viewfinder to open at. A camera whose minimum is above 1 — a
  /// fixed telephoto — starts at its own minimum instead, which is the closest
  /// truthful equivalent.
  double defaultFor(ZoomRange range) => range.clamp(1);
}
