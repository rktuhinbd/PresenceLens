import 'package:camera/camera.dart';

import '../../domain/entities/camera_error.dart';

/// Turns the plugin's platform error codes into the app's error model.
///
/// The codes below were read out of the **resolved plugin sources** in this
/// project's pub cache rather than taken from a blog post, because which
/// platform emits which code is the entire basis for what the UI is allowed to
/// offer the user:
///
/// | Code | Emitted by |
/// | --- | --- |
/// | `CameraAccessDenied` | `camera_android_camerax` 0.7.4+7 **and** `camera_avfoundation` 0.10.3 |
/// | `CameraAccessDeniedWithoutPrompt` | `camera_avfoundation` **only** |
/// | `CameraAccessRestricted` | `camera_avfoundation` **only** |
/// | `CameraPermissionsRequestOngoing` | `camera_android_camerax` |
///
/// **The consequence is load-bearing** (`RESEARCH.md` `FR-12`): on Android —
/// the only mandated platform — the plugin cannot tell "denied once" from
/// "denied for good". `CameraPermissionsManager.java` constructs exactly two
/// errors, `CameraAccessDenied` and `AudioAccessDenied`, and there is no third.
/// So [CameraErrorKind.permissionPermanentlyDenied] is **unreachable on
/// Android**, and any UI that routes to app settings must do so on an honest
/// basis rather than on a platform verdict that never arrives (`ADR-F22`).
class CameraErrorTranslation {
  const CameraErrorTranslation._();

  /// Codes the plugin uses for a refusal that may still be retried.
  static const Set<String> deniedCodes = <String>{'CameraAccessDenied'};

  /// Codes for a refusal the platform says will not prompt again. iOS only.
  static const Set<String> permanentlyDeniedCodes = <String>{
    'CameraAccessDeniedWithoutPrompt',
  };

  /// Codes for access blocked by policy rather than by the user. iOS only.
  static const Set<String> restrictedCodes = <String>{'CameraAccessRestricted'};

  /// Codes meaning the camera service could not give us the hardware.
  static const Set<String> unavailableCodes = <String>{
    'CameraPermissionsRequestOngoing',
    'cameraNotFound',
    'CameraAccessFailed',
  };

  /// Codes meaning the controller was gone before the call reached it.
  static const Set<String> disposedCodes = <String>{
    'Disposed CameraController',
    'Uninitialized CameraController',
  };

  /// Classifies [error] for an operation whose own failure kind is [fallback].
  ///
  /// [fallback] is what an unrecognised code becomes — which is why the caller
  /// passes the operation's own kind rather than everything defaulting to one
  /// generic failure. An unknown code during `setZoomLevel` is a zoom failure;
  /// the same code during `initialize` is fatal. Collapsing both into "camera
  /// error" is exactly what `§31` forbids.
  static CameraFailure classify(Object error, CameraErrorKind fallback) {
    if (error is CameraFailure) {
      return error;
    }
    if (error is CameraException) {
      final String code = error.code;
      if (deniedCodes.contains(code)) {
        return CameraFailure(
          CameraErrorKind.permissionDenied,
          platformCode: code,
          cause: error,
        );
      }
      if (permanentlyDeniedCodes.contains(code)) {
        return CameraFailure(
          CameraErrorKind.permissionPermanentlyDenied,
          platformCode: code,
          cause: error,
        );
      }
      if (restrictedCodes.contains(code)) {
        return CameraFailure(
          CameraErrorKind.permissionRestricted,
          platformCode: code,
          cause: error,
        );
      }
      if (unavailableCodes.contains(code)) {
        return CameraFailure(
          CameraErrorKind.cameraUnavailable,
          platformCode: code,
          cause: error,
        );
      }
      // The plugin raises this when a controller is used after disposal. That
      // is a race in our own sequencing, not a hardware fault, and it must
      // never reach the user.
      if (disposedCodes.contains(code)) {
        return CameraFailure(
          CameraErrorKind.sessionDisposed,
          platformCode: code,
          cause: error,
        );
      }
      return CameraFailure(fallback, platformCode: code, cause: error);
    }
    return CameraFailure(fallback, cause: error);
  }
}
