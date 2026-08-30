import 'package:equatable/equatable.dart';

/// The zoom span one camera reported once it was open.
///
/// Held as its own type because a range is a pair whose members are only
/// meaningful together, and because **the minimum is not assumed to be 1.0**.
/// CameraX exposes a real minimum ratio, so a device that can go wider says so,
/// and a device that cannot must not be told it can (`FLT-CAM-007`).
class ZoomRange extends Equatable {
  /// Creates a range, normalising a platform answer that makes no sense.
  ///
  /// A max below the min is not repaired silently into something wider than the
  /// device reported: the range collapses to the minimum, which is the only
  /// value the device definitely supports.
  factory ZoomRange({required double min, required double max}) {
    final double safeMin = min.isFinite && min > 0 ? min : 1;
    final double safeMax = max.isFinite && max >= safeMin ? max : safeMin;
    return ZoomRange._(safeMin, safeMax);
  }

  const ZoomRange._(this.min, this.max);

  /// The range of a camera that cannot zoom at all.
  static const ZoomRange fixed = ZoomRange._(1, 1);

  /// Smallest zoom the camera accepts. **Not necessarily 1.0.**
  final double min;

  /// Largest zoom the camera accepts.
  final double max;

  /// Whether there is any range to offer a control over.
  bool get isAdjustable => max > min;

  /// Whether the device reported it can go wider than its baseline.
  ///
  /// This is the *only* thing that may put a sub-1x control on screen
  /// (`ADR-F03`).
  bool get supportsSubBaseline => min < 1;

  /// [value] confined to this range.
  ///
  /// `NaN` resolves to the minimum rather than propagating: it has no ordering,
  /// so there is no "nearest valid value", and the minimum is the one zoom
  /// every camera definitely supports. The infinities need no special case —
  /// they compare correctly and land on the ends.
  double clamp(double value) {
    if (value.isNaN) {
      return min;
    }
    if (value < min) {
      return min;
    }
    if (value > max) {
      return max;
    }
    return value;
  }

  /// Whether [value] lies inside this range.
  bool contains(double value) => value >= min && value <= max;

  @override
  List<Object?> get props => <Object?>[min, max];

  @override
  String toString() => 'ZoomRange($min..$max)';
}

/// What an **open** camera session turned out to support.
///
/// Every field is read back from the platform after initialisation rather than
/// assumed, which is what lets the UI hide a control the hardware cannot honour
/// instead of showing an inert one (`RF-02`).
class CameraCapabilities extends Equatable {
  /// Creates a capability set.
  const CameraCapabilities({
    required this.zoom,
    required this.focusPointSupported,
    required this.exposurePointSupported,
    this.previewAspectRatio,
  });

  /// Capabilities of a camera that reported nothing beyond being open.
  static const CameraCapabilities none = CameraCapabilities(
    zoom: ZoomRange.fixed,
    focusPointSupported: false,
    exposurePointSupported: false,
  );

  /// The reported zoom span.
  final ZoomRange zoom;

  /// Whether `setFocusPoint` is meaningful on this session (`FLT-CAM-008`).
  final bool focusPointSupported;

  /// Whether `setExposurePoint` is meaningful on this session (`FLT-CAM-018`).
  final bool exposurePointSupported;

  /// Preview width ÷ height, or `null` if the platform did not report a size.
  ///
  /// Needed by the focus-coordinate mapping, which has to know the shape of the
  /// image before it can say where inside it the user tapped.
  final double? previewAspectRatio;

  /// A copy with the given fields replaced.
  CameraCapabilities copyWith({
    ZoomRange? zoom,
    bool? focusPointSupported,
    bool? exposurePointSupported,
    double? previewAspectRatio,
  }) {
    return CameraCapabilities(
      zoom: zoom ?? this.zoom,
      focusPointSupported: focusPointSupported ?? this.focusPointSupported,
      exposurePointSupported:
          exposurePointSupported ?? this.exposurePointSupported,
      previewAspectRatio: previewAspectRatio ?? this.previewAspectRatio,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    zoom,
    focusPointSupported,
    exposurePointSupported,
    previewAspectRatio,
  ];
}
