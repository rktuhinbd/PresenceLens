import 'package:equatable/equatable.dart';

import 'camera_geometry.dart';

/// How a focus (and optional exposure) request ended.
enum FocusOutcome {
  /// Sent to the platform, awaiting the result.
  pending,

  /// The platform accepted the point.
  applied,

  /// This camera does not support a focus point at all.
  ///
  /// Distinct from [failed] on purpose: nothing is wrong, the hardware simply
  /// cannot do it, and telling the user their camera is broken would be untrue
  /// (`§24`).
  unsupported,

  /// The platform rejected the point, or the session went away underneath it.
  failed,
}

/// One tap-to-focus request and what became of it.
///
/// The engine owns the *fact* of the request — where, when, and how it
/// resolved. It does not own the reticle's animation: that is the UI's, and
/// putting animation state in the camera engine would make a device concern out
/// of a rendering one (`§22`).
class FocusRequest extends Equatable {
  /// Creates a focus request record.
  const FocusRequest({
    required this.sequence,
    required this.point,
    required this.outcome,
    this.exposurePaired = false,
    this.exposureFailed = false,
  });

  /// Monotonic counter, incremented per request.
  ///
  /// Two taps at the same coordinates produce equal [point]s, so without this
  /// the state would compare equal and `BlocBuilder` would suppress the rebuild
  /// — the reticle would silently fail to reappear on a second tap at the same
  /// spot.
  final int sequence;

  /// Where the user asked the camera to focus, in the camera's 0–1 space.
  final NormalizedPoint point;

  /// How it resolved.
  final FocusOutcome outcome;

  /// Whether the exposure point was set to the same coordinate (`FLT-CAM-018`).
  final bool exposurePaired;

  /// Whether the exposure half failed while focus itself succeeded.
  ///
  /// Recorded rather than merged into [outcome], because a failed bonus must
  /// not erase a successful mandatory operation.
  final bool exposureFailed;

  /// A copy with the given fields replaced.
  FocusRequest copyWith({
    FocusOutcome? outcome,
    bool? exposurePaired,
    bool? exposureFailed,
  }) {
    return FocusRequest(
      sequence: sequence,
      point: point,
      outcome: outcome ?? this.outcome,
      exposurePaired: exposurePaired ?? this.exposurePaired,
      exposureFailed: exposureFailed ?? this.exposureFailed,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    sequence,
    point,
    outcome,
    exposurePaired,
    exposureFailed,
  ];
}
