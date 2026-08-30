/// The app-lifecycle transitions the camera reacts to.
///
/// A domain enum rather than Flutter's `AppLifecycleState` so the sequencing
/// rules can be driven from a plain Dart test with no binding — and so the
/// cubit's API cannot quietly acquire a Flutter dependency. The screen maps the
/// framework's enum onto this one; that mapping is the only place the framework
/// type appears.
///
/// The camera plugin has not handled lifecycle since 0.5.0, so this is the
/// app's job and is a mandated failure path, not polish (`RESEARCH.md` `FR-02`,
/// `FLT-CAM-012`).
enum CameraLifecycleSignal {
  /// The app is in the foreground and interactive: acquire the camera.
  resumed,

  /// A transient overlay is up — notification shade, the permission dialog
  /// itself, an incoming call banner.
  ///
  /// **Deliberately not a release trigger.** Releasing here tears the preview
  /// down and rebuilds it during the very permission prompt that is trying to
  /// grant access (`CAMERA_ENGINE.md` §2).
  inactive,

  /// The app is backgrounded: release the hardware for other apps.
  paused,

  /// The view is being destroyed: release.
  detached,
}
