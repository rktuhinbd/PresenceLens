/// What went wrong with the camera, in the app's own vocabulary.
///
/// The plugin speaks in `CameraException(code, description)` where the codes
/// are platform strings. Letting those reach the UI would mean presentation
/// code doing string comparison against another package's private vocabulary,
/// and it would put an exception message on screen as though it were copy
/// (`§34`). Translation happens once, in the adapter.
///
/// The list is kept to failures that are **handled differently**. A kind that
/// nothing branches on is a kind that should not exist.
enum CameraErrorKind {
  /// Camera permission was refused, and asking again may still work.
  permissionDenied,

  /// Refused in a way the platform says will not prompt again.
  ///
  /// **Android never reports this.** `camera_android_camerax` 0.7.4+7 emits
  /// only `CameraAccessDenied`; the `...WithoutPrompt` variant exists solely in
  /// `camera_avfoundation`. Verified in the resolved plugin sources, not
  /// assumed (`RESEARCH.md` `FR-12`). So on the mandated platform this state is
  /// unreachable, and the app must not pretend otherwise.
  permissionPermanentlyDenied,

  /// Camera use is blocked by policy — parental controls, MDM — and the user
  /// cannot grant it themselves. iOS `CameraAccessRestricted`.
  permissionRestricted,

  /// The device reported no cameras at all.
  noCamerasAvailable,

  /// Cameras exist, but none of them face away from the user.
  noBackCamera,

  /// Enumeration or the camera service itself failed; hardware may be in use
  /// by another app, or disconnected.
  cameraUnavailable,

  /// A controller was built but would not start.
  initializationFailed,

  /// The operation arrived after its session was torn down.
  ///
  /// A race, not a hardware fault, and it must not be shown to anyone.
  sessionDisposed,

  /// `takePicture` failed. The session may well still be usable.
  captureFailed,

  /// Setting the focus point failed.
  focusFailed,

  /// Setting the exposure point failed.
  exposureFailed,

  /// Setting the zoom level failed.
  zoomFailed,
}

/// Whether a failure ends the camera session or just the operation.
///
/// This distinction is the whole point of the error model. Collapsing
/// everything into "Camera error" would tear down a live preview because one
/// `setZoomLevel` call was rejected (`§31`).
extension CameraErrorSeverity on CameraErrorKind {
  /// Whether this failure means the current session can no longer be used.
  bool get isFatalToSession {
    switch (this) {
      case CameraErrorKind.permissionDenied:
      case CameraErrorKind.permissionPermanentlyDenied:
      case CameraErrorKind.permissionRestricted:
      case CameraErrorKind.noCamerasAvailable:
      case CameraErrorKind.noBackCamera:
      case CameraErrorKind.cameraUnavailable:
      case CameraErrorKind.initializationFailed:
        return true;
      case CameraErrorKind.sessionDisposed:
      case CameraErrorKind.captureFailed:
      case CameraErrorKind.focusFailed:
      case CameraErrorKind.exposureFailed:
      case CameraErrorKind.zoomFailed:
        return false;
    }
  }

  /// Whether this failure is about permission rather than hardware.
  bool get isPermissionProblem =>
      this == CameraErrorKind.permissionDenied ||
      this == CameraErrorKind.permissionPermanentlyDenied ||
      this == CameraErrorKind.permissionRestricted;
}

/// A camera failure, classified, with the original kept for logs.
class CameraFailure implements Exception {
  /// Creates a failure.
  const CameraFailure(this.kind, {this.platformCode, this.cause});

  /// What kind of failure this is.
  final CameraErrorKind kind;

  /// The platform's own code, retained for diagnosis only.
  ///
  /// Deliberately **not** something the UI is expected to render: it is a
  /// vendor string, and putting it in front of a user is how error dialogs end
  /// up saying `CameraAccessDeniedWithoutPrompt`.
  final String? platformCode;

  /// The underlying error.
  final Object? cause;

  /// Whether this failure ends the session.
  bool get isFatalToSession => kind.isFatalToSession;

  @override
  String toString() =>
      'CameraFailure(${kind.name}'
      '${platformCode == null ? '' : ', code: $platformCode'}'
      '${cause == null ? '' : ', cause: $cause'})';
}
