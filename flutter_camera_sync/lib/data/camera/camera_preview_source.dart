import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

import '../../domain/ports/camera_engine.dart';

/// A session that can be rendered by the plugin's `CameraPreview` widget.
///
/// **This is the one place the architecture bends, and it bends deliberately.**
/// `CameraPreview` needs a `CameraController`; there is no pure-Dart substitute
/// for it, and inventing one would mean writing a "preview abstraction" whose
/// only implementation hands back the controller anyway — architecture theatre
/// that makes the real integration harder, not safer (`§32`).
///
/// So the seam is one getter, declared next to the adapter that satisfies it,
/// and used by exactly one widget. What it buys is real: [CameraSession] stays
/// free of Flutter, the cubit and every state test run with no binding, and a
/// fake session simply does not implement this interface — which is what makes
/// widget tests possible without a camera.
abstract interface class CameraPreviewSource implements CameraSession {
  /// The controller to hand to `CameraPreview`.
  ///
  /// Read-only. Nothing outside the owning session may dispose it or replace
  /// it; the single-owner rule in `CAMERA_ENGINE.md` §9 depends on that.
  CameraController get previewController;
}

/// Renders the live preview for [session], or [placeholder] if it has none.
///
/// The type test is the whole bridge. A session that is not a
/// [CameraPreviewSource] — a fake in a test, or a future implementation on a
/// platform with a different preview mechanism — degrades to the placeholder
/// instead of crashing, which is what lets the production screen be widget-
/// tested without a device.
Widget buildCameraPreview(
  CameraSession? session, {
  Widget placeholder = const SizedBox.expand(),
}) {
  if (session is CameraPreviewSource && !session.isDisposed) {
    return CameraPreview(session.previewController);
  }
  return placeholder;
}
