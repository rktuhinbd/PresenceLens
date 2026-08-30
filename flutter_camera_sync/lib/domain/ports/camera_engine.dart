import '../entities/camera_capabilities.dart';
import '../entities/camera_device.dart';
import '../entities/camera_geometry.dart';

/// The camera hardware, in the vocabulary the app actually uses.
///
/// Narrow on purpose. The plugin's `CameraController` exposes flash modes,
/// video recording, image streaming, exposure offset stepping and orientation
/// locking; none of that is in scope, and wrapping it mechanically would
/// produce a port that is harder to fake than the thing it wraps
/// (`ARCHITECTURE.md` §9).
///
/// Two objects rather than one, because a camera app has two lifetimes that do
/// not coincide: the *list of cameras*, which is a property of the device, and
/// a *session on one of them*, which is acquired, replaced on a switch, and
/// released on every background. Modelling both as one long-lived object is
/// what leads to a disposed controller still attached to the preview
/// (`FLT-CAM-013`).
abstract interface class CameraEngine {
  /// Every camera the device reports.
  ///
  /// Throws [CameraFailure] with [CameraErrorKind.cameraUnavailable] if
  /// enumeration itself fails. An empty list is a valid answer and is **not**
  /// an error here — deciding what an empty list means belongs to the caller
  /// (`FLT-ERR-003`).
  Future<List<CameraDevice>> availableCameras();

  /// Opens a session on [device] and reads back what it can do.
  ///
  /// Throws [CameraFailure]: permission kinds when access was refused,
  /// [CameraErrorKind.initializationFailed] otherwise.
  Future<CameraSession> openSession(CameraDevice device);
}

/// One live camera, from initialisation to disposal.
///
/// The session, not the engine, is what the app holds while the preview is up —
/// so "release the camera" is `dispose()` on an object that is then thrown
/// away, rather than a flag on something long-lived that might still be
/// consulted afterwards.
abstract interface class CameraSession {
  /// The camera this session was opened on.
  CameraDevice get device;

  /// What this camera turned out to support, read after initialisation.
  ///
  /// Read from the platform, never assumed: minimum zoom in particular is not
  /// taken to be 1.0 (`FLT-CAM-007`).
  CameraCapabilities get capabilities;

  /// Whether [dispose] has already run.
  bool get isDisposed;

  /// Applies a zoom level.
  ///
  /// The caller is responsible for clamping to [CameraCapabilities.zoom]; this
  /// method does not silently repair an out-of-range request, because a port
  /// that quietly corrects its caller hides the bug it is correcting.
  ///
  /// Throws [CameraFailure] with [CameraErrorKind.zoomFailed].
  Future<void> setZoom(double zoom);

  /// Points the autofocus at [point].
  ///
  /// Only call this when [CameraCapabilities.focusPointSupported]; a session
  /// that cannot do it throws rather than pretending.
  ///
  /// Throws [CameraFailure] with [CameraErrorKind.focusFailed].
  Future<void> setFocusPoint(NormalizedPoint point);

  /// Points the metering at [point] (`FLT-CAM-018`).
  ///
  /// Throws [CameraFailure] with [CameraErrorKind.exposureFailed].
  Future<void> setExposurePoint(NormalizedPoint point);

  /// Takes one photograph and returns the **temporary** path it landed at.
  ///
  /// A path rather than the plugin's `XFile` so the domain stays free of the
  /// plugin — and a *temporary* one, which is the whole point: the plugin
  /// writes into a cache directory the OS may reclaim, so nothing is captured
  /// until [CaptureStore] has copied it somewhere the app owns
  /// (`FLT-CAM-015`).
  ///
  /// Throws [CameraFailure] with [CameraErrorKind.captureFailed].
  Future<String> takePicture();

  /// Releases the hardware. Safe to call more than once.
  Future<void> dispose();
}
