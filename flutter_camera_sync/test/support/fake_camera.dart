import 'dart:async';

import 'package:presence_lens_capture/domain/entities/camera_capabilities.dart';
import 'package:presence_lens_capture/domain/entities/camera_device.dart';
import 'package:presence_lens_capture/domain/entities/camera_error.dart';
import 'package:presence_lens_capture/domain/entities/camera_geometry.dart';
import 'package:presence_lens_capture/domain/ports/camera_engine.dart';

/// A camera the test drives completely.
///
/// **Why this is the centre of the camera test strategy.** Every failure that
/// actually costs a camera app — a switch that lands out of order, a capture
/// that resolves after disposal, a zoom flood, a device with no rear camera —
/// is a matter of *timing and ordering*, and none of it can be provoked on
/// demand with real hardware. Here it can: initialisation, capture and disposal
/// can each be held open and released by the test at the exact moment that
/// makes the race happen.
///
/// It also means the whole camera state machine is verified on a Windows host
/// with no emulator, which is what `TEST_STRATEGY.md` §2 is built around.
class FakeCameraEngine implements CameraEngine {
  /// Creates a fake engine reporting [devices].
  FakeCameraEngine({List<CameraDevice>? devices})
    : devices = devices ?? <CameraDevice>[backCamera('0')];

  /// A back-facing camera with an unknown lens — what Android always reports.
  static CameraDevice backCamera(
    String id, {
    int ordinal = 0,
    CameraLensKind lens = CameraLensKind.unknown,
    int sensorOrientation = 90,
  }) => CameraDevice(
    id: id,
    facing: CameraFacing.back,
    sensorOrientation: sensorOrientation,
    lensKind: lens,
    ordinalAmongFacing: ordinal,
  );

  /// A front-facing camera, which the app must filter out (`FLT-CAM-011`).
  static CameraDevice frontCamera(String id, {int ordinal = 0}) => CameraDevice(
    id: id,
    facing: CameraFacing.front,
    sensorOrientation: 270,
    ordinalAmongFacing: ordinal,
  );

  /// An external camera — a real third case on Android.
  static CameraDevice externalCamera(String id) =>
      CameraDevice(id: id, facing: CameraFacing.external, sensorOrientation: 0);

  /// What `availableCameras()` reports.
  List<CameraDevice> devices;

  /// When set, enumeration throws this instead of answering.
  Object? enumerationFailure;

  /// When set, opening a session throws this.
  Object? openFailure;

  /// Fails the *next* open only, then clears itself.
  ///
  /// Exists so a test can prove recovery — denied, then granted — without
  /// having to reach in and mutate the engine between two awaits.
  Object? openFailureOnce;

  /// Capabilities handed to each new session, keyed by camera id.
  final Map<String, CameraCapabilities> capabilities =
      <String, CameraCapabilities>{};

  /// Capabilities for any camera not named in [capabilities].
  CameraCapabilities defaultCapabilities = const CameraCapabilities(
    zoom: ZoomRange.fixed,
    focusPointSupported: true,
    exposurePointSupported: false,
  );

  /// Gates that hold `openSession` open until the test releases them, keyed by
  /// camera id.
  ///
  /// This is how the switch race is produced deterministically: open A, open B,
  /// then complete A *last* and assert that A's session is disposed rather than
  /// attached.
  final Map<String, Completer<void>> openGates = <String, Completer<void>>{};

  /// Every camera id `openSession` was called for, in order.
  final List<String> openCalls = <String>[];

  /// Every session handed out, in order — including ones that were superseded.
  final List<FakeCameraSession> sessions = <FakeCameraSession>[];

  /// How many times enumeration was requested.
  int enumerationCount = 0;

  /// Sessions built but never disposed. A leak, if it is not empty at the end.
  Iterable<FakeCameraSession> get liveSessions =>
      sessions.where((FakeCameraSession s) => !s.isDisposed);

  /// Suspends `openSession` for [cameraId] until [releaseOpen] is called.
  Completer<void> holdOpen(String cameraId) =>
      openGates[cameraId] = Completer<void>();

  /// Lets a held `openSession` finish.
  void releaseOpen(String cameraId) {
    final Completer<void>? gate = openGates.remove(cameraId);
    if (gate != null && !gate.isCompleted) {
      gate.complete();
    }
  }

  @override
  Future<List<CameraDevice>> availableCameras() async {
    enumerationCount++;
    final Object? failure = enumerationFailure;
    if (failure != null) {
      _raise(failure);
    }
    return List<CameraDevice>.unmodifiable(devices);
  }

  @override
  Future<CameraSession> openSession(CameraDevice device) async {
    openCalls.add(device.id);

    final Completer<void>? gate = openGates[device.id];
    if (gate != null) {
      await gate.future;
    }

    final Object? once = openFailureOnce;
    if (once != null) {
      openFailureOnce = null;
      _raise(once);
    }
    final Object? failure = openFailure;
    if (failure != null) {
      _raise(failure);
    }

    final FakeCameraSession session = FakeCameraSession(
      device: device,
      capabilities: capabilities[device.id] ?? defaultCapabilities,
    );
    sessions.add(session);
    return session;
  }
}

/// One fake live camera, recording everything it was asked to do.
class FakeCameraSession implements CameraSession {
  /// Creates a fake session.
  FakeCameraSession({required this.device, required this.capabilities});

  @override
  final CameraDevice device;

  @override
  final CameraCapabilities capabilities;

  bool _disposed = false;

  @override
  bool get isDisposed => _disposed;

  /// Every zoom value that reached the platform, in order.
  ///
  /// The coalescing assertion reads this: a flood of requests must not become a
  /// flood of calls, and the **last** value asked for must be the last one here
  /// (`§19`).
  final List<double> appliedZoom = <double>[];

  /// Every focus point that reached the platform.
  final List<NormalizedPoint> focusPoints = <NormalizedPoint>[];

  /// Every exposure point that reached the platform.
  final List<NormalizedPoint> exposurePoints = <NormalizedPoint>[];

  /// How many times `takePicture` was invoked.
  ///
  /// The double-shutter test asserts this is exactly 1 (`FLT-CAM-014`).
  int captureCount = 0;

  /// How many times `dispose` was invoked, including repeats.
  int disposeCount = 0;

  /// Temporary paths handed back by successive captures.
  int _captureSequence = 0;

  /// When set, `setZoom` throws it.
  Object? zoomFailure;

  /// When set, `setFocusPoint` throws it.
  Object? focusFailure;

  /// When set, `setExposurePoint` throws it.
  Object? exposureFailure;

  /// When set, `takePicture` throws it.
  Object? captureFailure;

  /// Holds `setZoom` open until released, so overlapping calls can be observed.
  Completer<void>? zoomGate;

  /// Holds `takePicture` open — how "two shutter presses in one frame" is
  /// produced without relying on timing.
  Completer<void>? captureGate;

  /// Holds `dispose` open.
  Completer<void>? disposeGate;

  @override
  Future<void> setZoom(double zoom) async {
    final Completer<void>? gate = zoomGate;
    if (gate != null) {
      await gate.future;
    }
    final Object? failure = zoomFailure;
    if (failure != null) {
      _raise(failure);
    }
    appliedZoom.add(zoom);
  }

  @override
  Future<void> setFocusPoint(NormalizedPoint point) async {
    final Object? failure = focusFailure;
    if (failure != null) {
      _raise(failure);
    }
    focusPoints.add(point);
  }

  @override
  Future<void> setExposurePoint(NormalizedPoint point) async {
    final Object? failure = exposureFailure;
    if (failure != null) {
      _raise(failure);
    }
    exposurePoints.add(point);
  }

  @override
  Future<String> takePicture() async {
    captureCount++;
    final Completer<void>? gate = captureGate;
    if (gate != null) {
      await gate.future;
    }
    final Object? failure = captureFailure;
    if (failure != null) {
      _raise(failure);
    }
    return 'tmp/${device.id}-${_captureSequence++}.jpg';
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
    if (_disposed) {
      return;
    }
    _disposed = true;
    final Completer<void>? gate = disposeGate;
    if (gate != null) {
      await gate.future;
    }
  }
}

/// A [CameraFailure] with the given [kind], for injecting into the fake.
CameraFailure cameraFailure(CameraErrorKind kind) => CameraFailure(kind);

/// Throws an injected failure of any type.
///
/// Routed through `Error.throwWithStackTrace` rather than a bare `throw` so the
/// fake can inject an `Error` as well as an `Exception` — the production code
/// has to survive both, and a lint that only permits one would narrow the test
/// rather than the code.
Never _raise(Object failure) =>
    Error.throwWithStackTrace(failure, StackTrace.current);
