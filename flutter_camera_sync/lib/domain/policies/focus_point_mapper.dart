import '../entities/camera_geometry.dart';

/// Turns a tap on the preview widget into the normalised point the platform
/// wants.
///
/// `setFocusPoint` takes values *"anywhere between (0,0) and (1,1)"*
/// (`RESEARCH.md` `FR-01`), and CameraX documents that the point is measured
/// against the **entire unaltered preview surface**. So dividing the tap by the
/// widget's size is only correct when the image happens to exactly fill the
/// widget. Every other time — which is most of the time, because a 4:3 sensor
/// rarely matches a 19.5:9 screen — it focuses on the wrong part of the scene,
/// and the error is invisible in a screenshot.
///
/// Pure arithmetic, so it is tested at the aspect-ratio boundaries with no
/// camera present (`FLT-CAM-008`).
class FocusPointMapper {
  /// Creates the mapper. It carries no state.
  const FocusPointMapper();

  /// Where inside the camera image the user touched, or `null` if nowhere.
  ///
  /// [tapX] and [tapY] are local to the preview widget, in logical pixels.
  ///
  /// Returns `null` when:
  ///
  /// * the layout is degenerate (zero-sized box, or no reported aspect ratio) —
  ///   there is no image to map onto;
  /// * the tap is outside the widget entirely;
  /// * the fit is [PreviewFit.contain] and the tap landed on a letterbox band.
  ///   Focusing on a black bar is meaningless, and clamping it to the image
  ///   edge instead would silently move the reticle away from the finger.
  NormalizedPoint? toNormalized({
    required double tapX,
    required double tapY,
    required PreviewLayout layout,
  }) {
    if (!layout.isUsable || !tapX.isFinite || !tapY.isFinite) {
      return null;
    }
    if (tapX < 0 ||
        tapY < 0 ||
        tapX > layout.widgetWidth ||
        tapY > layout.widgetHeight) {
      return null;
    }

    switch (layout.fit) {
      case PreviewFit.contain:
        return _mapContain(tapX, tapY, layout);
      case PreviewFit.cover:
        return _mapCover(tapX, tapY, layout);
    }
  }

  /// The image is letterboxed: it is smaller than the box on one axis, and the
  /// bands on either side of it hold no picture.
  NormalizedPoint? _mapContain(double tapX, double tapY, PreviewLayout layout) {
    double drawnWidth = layout.widgetWidth;
    double drawnHeight = layout.widgetWidth / layout.previewAspectRatio;

    if (drawnHeight > layout.widgetHeight) {
      drawnHeight = layout.widgetHeight;
      drawnWidth = layout.widgetHeight * layout.previewAspectRatio;
    }

    final double left = (layout.widgetWidth - drawnWidth) / 2;
    final double top = (layout.widgetHeight - drawnHeight) / 2;

    final double localX = tapX - left;
    final double localY = tapY - top;

    if (localX < 0 ||
        localY < 0 ||
        localX > drawnWidth ||
        localY > drawnHeight) {
      return null;
    }

    return NormalizedPoint(localX / drawnWidth, localY / drawnHeight);
  }

  /// The image fills the box and overflows it: part of the picture is off
  /// screen, and the visible window has to be re-expressed against the whole
  /// image.
  NormalizedPoint _mapCover(double tapX, double tapY, PreviewLayout layout) {
    double drawnWidth = layout.widgetWidth;
    double drawnHeight = layout.widgetWidth / layout.previewAspectRatio;

    if (drawnHeight < layout.widgetHeight) {
      drawnHeight = layout.widgetHeight;
      drawnWidth = layout.widgetHeight * layout.previewAspectRatio;
    }

    // Negative or zero: the amount of image hidden past each edge.
    final double left = (layout.widgetWidth - drawnWidth) / 2;
    final double top = (layout.widgetHeight - drawnHeight) / 2;

    return NormalizedPoint(
      (tapX - left) / drawnWidth,
      (tapY - top) / drawnHeight,
    );
  }
}
