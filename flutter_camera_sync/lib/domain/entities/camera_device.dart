import 'package:equatable/equatable.dart';

/// Which way a camera points.
///
/// Mirrors the platform's own vocabulary rather than reducing it to a boolean:
/// `external` is a real third case (a USB camera on Android), and collapsing it
/// into "back" would offer the user a camera the assessment never asked for
/// (`FLT-CAM-011`).
enum CameraFacing {
  /// Points away from the user.
  back,

  /// Points at the user.
  front,

  /// Attached hardware that may not be mounted to the device at all.
  external,

  /// The platform reported a direction this app does not model.
  unknown,
}

/// What the platform claims about a camera's optics.
///
/// **This is only ever as good as the platform.** `camera_android_camerax`
/// 0.7.4+7 never populates it, so on Android every value here is [unknown] —
/// verified in the resolved package source, not assumed (`RESEARCH.md` `FR-04`).
/// The whole reason this enum carries an explicit [unknown] rather than being
/// nullable is that "the platform did not say" is a fact the UI has to render
/// honestly, not an absence to be filled in (`ADR-F03`, `FLT-CAM-016`).
enum CameraLensKind {
  /// A normal/primary lens.
  wide,

  /// A longer focal length than [wide].
  telephoto,

  /// A shorter focal length than [wide].
  ultraWide,

  /// The platform did not report a lens type.
  unknown,
}

/// The **identity** of one camera the device reported.
///
/// Identity only. What this camera can *do* — its zoom range, whether it
/// supports a focus point — is [CameraCapabilities], and it is deliberately not
/// here: those values cannot be read until a session has been opened on the
/// camera, so putting them on the identity would mean either lying about them
/// before initialisation or making every field nullable.
class CameraDevice extends Equatable {
  /// Creates a camera identity.
  const CameraDevice({
    required this.id,
    required this.facing,
    required this.sensorOrientation,
    this.lensKind = CameraLensKind.unknown,
    this.ordinalAmongFacing = 0,
  });

  /// The platform's own stable name for this camera.
  ///
  /// On Android this is the raw Camera2 camera ID string. It is treated as an
  /// opaque handle: **nothing in this app parses it**, because the mapping from
  /// a Camera2 ID to a physical lens is undocumented and OEM-specific
  /// (`ADR-F03`).
  final String id;

  /// Which way it points.
  final CameraFacing facing;

  /// Clockwise rotation needed to bring the sensor output upright.
  final int sensorOrientation;

  /// What the platform said about the optics, which on Android is nothing.
  final CameraLensKind lensKind;

  /// This camera's position among the cameras sharing its [facing], from 0.
  ///
  /// Enumeration order, and nothing more. It exists so a fallback label can say
  /// "Camera 2" truthfully; it is **not** evidence of focal length, and the
  /// order in which `availableCameras()` returns cameras is not documented to
  /// mean anything.
  final int ordinalAmongFacing;

  /// Whether the platform gave a usable optical identity for this camera.
  bool get hasKnownLens => lensKind != CameraLensKind.unknown;

  @override
  List<Object?> get props => <Object?>[
    id,
    facing,
    sensorOrientation,
    lensKind,
    ordinalAmongFacing,
  ];

  @override
  String toString() =>
      'CameraDevice($id, ${facing.name}, $sensorOrientation°, '
      '${lensKind.name}, #$ordinalAmongFacing)';
}
