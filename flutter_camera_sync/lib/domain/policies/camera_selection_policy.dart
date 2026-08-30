import '../entities/camera_device.dart';

/// Which cameras the app offers, and which one it opens first.
///
/// The assessment asks for controls based on the *available back cameras*
/// (p2), so filtering is a requirement rather than housekeeping
/// (`FLT-CAM-011`). The default-choice rule is written down here because
/// "whatever `availableCameras()` returned first" is not a policy — it is an
/// accident that happens to work on the developer's handset.
class CameraSelectionPolicy {
  /// Creates the policy. It carries no state.
  const CameraSelectionPolicy();

  /// The back-facing cameras among [all], in enumeration order.
  ///
  /// Front and external cameras are dropped: a USB webcam is not one of the
  /// "available back cameras", and offering it would answer a question nobody
  /// asked.
  ///
  /// Each survivor is stamped with its position among the back cameras, so a
  /// fallback label can say "Camera 2" without anything downstream having to
  /// re-derive the index — and without that index ever being mistaken for a
  /// focal length.
  List<CameraDevice> backCameras(List<CameraDevice> all) {
    final List<CameraDevice> back = <CameraDevice>[];
    for (final CameraDevice device in all) {
      if (device.facing != CameraFacing.back) {
        continue;
      }
      back.add(
        CameraDevice(
          id: device.id,
          facing: device.facing,
          sensorOrientation: device.sensorOrientation,
          lensKind: device.lensKind,
          ordinalAmongFacing: back.length,
        ),
      );
    }
    return List<CameraDevice>.unmodifiable(back);
  }

  /// The camera to open first, or `null` if [backCameras] is empty.
  ///
  /// **The rule, in priority order:**
  ///
  /// 1. The camera the platform identified as [CameraLensKind.wide] — the
  ///    normal lens, and what a viewfinder should open on. This branch is
  ///    reachable on iOS and, today, never on Android.
  /// 2. Failing that, the first back camera in enumeration order.
  ///
  /// Step 2 is a *deterministic fallback*, not a claim. It is explicitly **not**
  /// "camera 0 is the 1x lens": the app does not know that, and CameraX does
  /// not say it (`RESEARCH.md` `FR-04`). What it guarantees is that the same
  /// device opens the same camera every launch, which is what makes the
  /// behaviour reviewable at all.
  CameraDevice? defaultCamera(List<CameraDevice> backCameras) {
    if (backCameras.isEmpty) {
      return null;
    }
    for (final CameraDevice device in backCameras) {
      if (device.lensKind == CameraLensKind.wide) {
        return device;
      }
    }
    return backCameras.first;
  }

  /// The camera after [current] in [backCameras], wrapping at the end.
  ///
  /// Returns `null` when there is nothing to switch to, so the caller cannot
  /// start a switch that would land back on the camera it is already using and
  /// tear down a working session for nothing.
  CameraDevice? nextCamera(
    List<CameraDevice> backCameras,
    CameraDevice? current,
  ) {
    if (backCameras.length < 2) {
      return null;
    }
    final int index = backCameras.indexWhere(
      (CameraDevice d) => d.id == current?.id,
    );
    if (index < 0) {
      return backCameras.first;
    }
    return backCameras[(index + 1) % backCameras.length];
  }

  /// Whether any camera in [all] reported a usable optical identity.
  ///
  /// The switch that decides whether lens-named labels are allowed at all. On
  /// Android this is false for every device, and the preset policy degrades to
  /// range-derived labels because of it (`ADR-F03`).
  bool hasTrustworthyLensIdentity(List<CameraDevice> all) =>
      all.any((CameraDevice d) => d.hasKnownLens);
}
