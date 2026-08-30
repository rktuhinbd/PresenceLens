import 'package:equatable/equatable.dart';

import '../../domain/entities/camera_capabilities.dart';
import '../../domain/entities/camera_device.dart';
import '../../domain/entities/camera_error.dart';
import '../../domain/entities/focus_request.dart';
import '../../domain/entities/zoom_preset.dart';
import '../../domain/ports/camera_engine.dart';

/// What the camera is doing while it is not yet usable.
///
/// A field on one state rather than three states of its own: all three render
/// the same thing (a viewfinder that is not live yet), and splitting them would
/// force every consumer to handle three cases to say one sentence. It is still
/// carried, because "we are switching" and "we are starting up" are different
/// facts for a progress affordance and for a test to assert on.
enum CameraPreparingPhase {
  /// Asking the device what cameras it has.
  discovering,

  /// Opening a session on the chosen camera.
  initializing,

  /// Replacing a live session with one on another camera.
  switching,

  /// Reopening after the app came back to the foreground.
  restoring,
}

/// Why the camera cannot be used at all on this device.
enum CameraUnavailableReason {
  /// The device reported no cameras whatsoever.
  noCameras,

  /// Cameras exist, but none of them face away from the user (`FLT-CAM-011`).
  noBackCamera,
}

/// Base class for every camera state.
///
/// Sealed so the analyzer, not a code review, is what notices when a new state
/// is added and a consumer forgets to handle it.
sealed class CameraState extends Equatable {
  /// Creates a state.
  const CameraState();

  @override
  List<Object?> get props => <Object?>[];
}

/// Nothing has been attempted yet.
class CameraInitial extends CameraState {
  /// Creates the initial state.
  const CameraInitial();
}

/// Enumerating or opening a camera.
class CameraPreparing extends CameraState {
  /// Creates a preparing state.
  const CameraPreparing(this.phase, {this.device});

  /// What specifically is under way.
  final CameraPreparingPhase phase;

  /// The camera being opened, when one has been chosen.
  final CameraDevice? device;

  @override
  List<Object?> get props => <Object?>[phase, device];
}

/// A live camera, with everything the UI needs to drive it.
///
/// **There is deliberately no `CameraCapturing` state.** Capture is a flag here
/// rather than a state of its own because the preview must keep rendering while
/// a photograph is taken; making it a state would tear the viewfinder down for
/// the duration and rebuild it afterwards (`CAMERA_ENGINE.md` §1).
class CameraReady extends CameraState {
  /// Creates a ready state.
  const CameraReady({
    required this.session,
    required this.backCameras,
    required this.presets,
    required this.currentZoom,
    this.isCapturing = false,
    this.focusRequest,
    this.lastOperationError,
    this.lastCaptureImageId,
    this.batchImageCount = 0,
  });

  /// The live session. The single owner of the platform controller.
  final CameraSession session;

  /// Every back-facing camera this device offers, in enumeration order.
  final List<CameraDevice> backCameras;

  /// The rounded zoom controls this camera's reported range justifies.
  ///
  /// Derived from the device, never from a marketing multiplier (`ADR-F03`).
  final List<ZoomPreset> presets;

  /// **The** zoom value.
  ///
  /// Pinch, the slider and the presets are three inputs to this one number, not
  /// three numbers that have to be kept in agreement. They cannot disagree,
  /// because there is nothing to disagree with (`FLT-CAM-006`).
  final double currentZoom;

  /// Whether a photograph is in flight (`FLT-CAM-014`).
  final bool isCapturing;

  /// The most recent tap-to-focus and how it resolved, or `null`.
  final FocusRequest? focusRequest;

  /// The last operation that failed **without** ending the session.
  ///
  /// A rejected zoom or focus call belongs here, not in [CameraFailed]: the
  /// camera is still live and tearing the screen down over it would be a bug,
  /// not error handling (`§24`, `§31`).
  final CameraFailure? lastOperationError;

  /// The id of the most recent capture, or `null` if none yet this session.
  final String? lastCaptureImageId;

  /// How many images the open draft batch now holds.
  ///
  /// Enough for the capture path to work and to be asserted; the batch *UI* is
  /// gate F4 and none of it is here.
  final int batchImageCount;

  /// The camera currently open.
  CameraDevice get device => session.device;

  /// What the open camera reported it can do.
  CameraCapabilities get capabilities => session.capabilities;

  /// The zoom span of the open camera.
  ZoomRange get zoomRange => session.capabilities.zoom;

  /// Whether tap-to-focus is meaningful on this camera.
  bool get canFocus => session.capabilities.focusPointSupported;

  /// Whether the exposure point can be paired with focus (`FLT-CAM-018`).
  bool get canSetExposurePoint => session.capabilities.exposurePointSupported;

  /// Whether there is another back camera to switch to.
  bool get canSwitchCamera => backCameras.length > 1;

  /// A copy with the given fields replaced.
  ///
  /// [focusRequest] and [lastOperationError] take explicit clear flags because
  /// `null` here means "leave it alone", and both genuinely need clearing —
  /// a new capture must not inherit the previous operation's error.
  CameraReady copyWith({
    CameraSession? session,
    List<CameraDevice>? backCameras,
    List<ZoomPreset>? presets,
    double? currentZoom,
    bool? isCapturing,
    FocusRequest? focusRequest,
    CameraFailure? lastOperationError,
    String? lastCaptureImageId,
    int? batchImageCount,
    bool clearFocusRequest = false,
    bool clearOperationError = false,
  }) {
    return CameraReady(
      session: session ?? this.session,
      backCameras: backCameras ?? this.backCameras,
      presets: presets ?? this.presets,
      currentZoom: currentZoom ?? this.currentZoom,
      isCapturing: isCapturing ?? this.isCapturing,
      focusRequest: clearFocusRequest
          ? null
          : (focusRequest ?? this.focusRequest),
      lastOperationError: clearOperationError
          ? null
          : (lastOperationError ?? this.lastOperationError),
      lastCaptureImageId: lastCaptureImageId ?? this.lastCaptureImageId,
      batchImageCount: batchImageCount ?? this.batchImageCount,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    session,
    backCameras,
    presets,
    currentZoom,
    isCapturing,
    focusRequest,
    lastOperationError,
    lastCaptureImageId,
    batchImageCount,
  ];
}

/// Camera permission was refused.
class CameraPermissionDenied extends CameraState {
  /// Creates the denied state.
  const CameraPermissionDenied({
    required this.isPermanentPerPlatform,
    required this.isRestricted,
    required this.consecutiveDenials,
  });

  /// Whether the **platform itself** said it will not prompt again.
  ///
  /// This is the only field that may drive a claim about permanence, and on
  /// Android it is always false — `camera_android_camerax` emits one denial
  /// code and no permanent variant (`RESEARCH.md` `FR-12`, `ADR-F22`).
  final bool isPermanentPerPlatform;

  /// Whether access is blocked by policy the user cannot lift. iOS only.
  final bool isRestricted;

  /// How many times in a row this session has been refused.
  ///
  /// Not a permanence verdict, and must never be rendered as one. It exists so
  /// the later UI can *escalate its offer* — "Try again" first, then also
  /// "Open settings" — without the app asserting something the platform never
  /// told it (`ADR-F22`).
  final int consecutiveDenials;

  /// Whether asking again could plausibly succeed.
  bool get canRetry => !isPermanentPerPlatform && !isRestricted;

  @override
  List<Object?> get props => <Object?>[
    isPermanentPerPlatform,
    isRestricted,
    consecutiveDenials,
  ];
}

/// The device has no camera this app can use.
class CameraUnavailable extends CameraState {
  /// Creates the unavailable state.
  const CameraUnavailable(this.reason);

  /// Which of the two ways it is unusable.
  final CameraUnavailableReason reason;

  @override
  List<Object?> get props => <Object?>[reason];
}

/// Enumeration or initialisation failed, and the screen offers a retry.
class CameraFailed extends CameraState {
  /// Creates the failure state.
  const CameraFailed(this.failure);

  /// What went wrong, classified.
  final CameraFailure failure;

  /// The classified kind, for consumers that only branch on it.
  CameraErrorKind get kind => failure.kind;

  @override
  List<Object?> get props => <Object?>[failure.kind, failure.platformCode];
}

/// The camera was released on purpose and can be reacquired.
///
/// A named state rather than a return to [CameraInitial], because the two mean
/// different things to whoever is looking: `initial` is "nothing has happened
/// yet", and this is "we had a camera, we gave the hardware back, and we know
/// which one to reopen". Collapsing them would make a backgrounded app
/// indistinguishable from a cold start, and would lose the selected camera
/// across every trip to the notification shade (`§10`, `FLT-CAM-012`).
class CameraReleased extends CameraState {
  /// Creates the released state.
  const CameraReleased({this.device, this.isFinal = false});

  /// The camera that was open, so resume can reopen the same one.
  final CameraDevice? device;

  /// Whether this release was the cubit closing for good.
  final bool isFinal;

  @override
  List<Object?> get props => <Object?>[device, isFinal];
}
