import 'package:equatable/equatable.dart';

/// A point in the camera's own 0–1 coordinate space.
///
/// This is exactly what `setFocusPoint` and `setExposurePoint` accept
/// (`RESEARCH.md` `FR-01`): *"anywhere between (0,0) and (1,1)"*. It is a
/// domain type rather than `dart:ui`'s `Offset` because the domain layer is
/// barred from importing `dart:ui` at all (`FLT-GEN-007`) — and because an
/// `Offset` in this codebase would be ambiguous about whether it holds pixels
/// or a normalised fraction, which is precisely the mistake that puts the focus
/// reticle in the wrong place.
class NormalizedPoint extends Equatable {
  /// Creates a normalised point, clamping both axes into 0–1.
  ///
  /// Clamping rather than asserting: a tap one pixel outside a rounded rect is
  /// a real event, and the correct response is the nearest valid point, not a
  /// crash in release.
  factory NormalizedPoint(double x, double y) =>
      NormalizedPoint._(_unit(x), _unit(y));

  const NormalizedPoint._(this.x, this.y);

  /// The middle of the frame — the platform's own default focus target.
  static const NormalizedPoint center = NormalizedPoint._(0.5, 0.5);

  /// Horizontal fraction, 0 at the left edge of the image.
  final double x;

  /// Vertical fraction, 0 at the top edge of the image.
  final double y;

  static double _unit(double v) {
    if (!v.isFinite) {
      return 0.5;
    }
    if (v < 0) {
      return 0;
    }
    if (v > 1) {
      return 1;
    }
    return v;
  }

  @override
  List<Object?> get props => <Object?>[x, y];

  @override
  String toString() =>
      'NormalizedPoint(${x.toStringAsFixed(4)}, ${y.toStringAsFixed(4)})';
}

/// How the preview image is fitted into the box that displays it.
///
/// Both are real and the choice belongs to the UI, not to the engine — so the
/// mapping supports both rather than baking one in. Getting this wrong is
/// invisible on a 4:3 preview in a 4:3 box and badly wrong everywhere else.
enum PreviewFit {
  /// The whole image is visible, letterboxed inside the box.
  ///
  /// Taps can land on a band where there is no image, and the correct answer
  /// there is "nothing to focus on" (`CAMERA_ENGINE.md` §5).
  contain,

  /// The image fills the box and is cropped.
  ///
  /// Every tap lands on image, but part of the image is off-screen, so the
  /// normalisation has to account for the cropped-away margin. This is what a
  /// full-bleed viewfinder does (`UX_SPEC.md` §4).
  cover,
}

/// The geometry a tap has to be interpreted against.
///
/// The UI supplies this; the engine never guesses it. Nothing here is a
/// prototype constant — a hard-coded 390×844 would be correct on exactly one
/// device.
class PreviewLayout extends Equatable {
  /// Creates a layout description.
  const PreviewLayout({
    required this.widgetWidth,
    required this.widgetHeight,
    required this.previewAspectRatio,
    this.fit = PreviewFit.cover,
  });

  /// Width of the box the preview is drawn into, in logical pixels.
  final double widgetWidth;

  /// Height of that box, in logical pixels.
  final double widgetHeight;

  /// Width ÷ height of the camera image **as displayed**.
  final double previewAspectRatio;

  /// How the image is fitted into the box.
  final PreviewFit fit;

  /// Whether this layout describes a box and an image that both have area.
  bool get isUsable =>
      widgetWidth > 0 &&
      widgetHeight > 0 &&
      previewAspectRatio.isFinite &&
      previewAspectRatio > 0;

  /// Width ÷ height of the box itself.
  double get widgetAspectRatio => widgetWidth / widgetHeight;

  @override
  List<Object?> get props => <Object?>[
    widgetWidth,
    widgetHeight,
    previewAspectRatio,
    fit,
  ];
}
