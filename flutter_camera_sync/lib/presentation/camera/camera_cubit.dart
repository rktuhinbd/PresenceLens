import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/camera_device.dart';
import '../../domain/entities/camera_error.dart';
import '../../domain/entities/camera_geometry.dart';
import '../../domain/entities/camera_lifecycle_signal.dart';
import '../../domain/entities/focus_request.dart';
import '../../domain/entities/zoom_preset.dart';
import '../../domain/policies/camera_selection_policy.dart';
import '../../domain/policies/focus_point_mapper.dart';
import '../../domain/policies/zoom_policy.dart';
import '../../domain/policies/zoom_preset_policy.dart';
import '../../domain/ports/camera_engine.dart';
import '../../domain/usecases/capture_into_batch.dart';
import 'camera_state.dart';

/// Sequences every camera operation and owns the live session.
///
/// **Cubit, not Bloc, and the reason is not preference** (`ADR-F08`). Every
/// camera interaction is a direct imperative command — acquire, zoom, focus
/// here, capture, switch. There is no event stream worth replaying and no
/// cross-event transformation, so a Bloc would buy an event class per method
/// call and nothing else. The genuinely hard part of a camera is *lifecycle and
/// races*, and that is solved by sequencing inside this class, not by event
/// modelling.
///
/// **What it does not do.** It writes no files and touches no database: capture
/// goes out through [CaptureIntoBatch], which is where the F1 durability rules
/// already live. Nothing here knows what SQLite or WorkManager are, and adding
/// that knowledge would turn a sequencer into a god object (`§11`, `§26`).
class CameraCubit extends Cubit<CameraState> {
  /// Creates the cubit.
  ///
  /// The policies default to their stateless instances; they are injectable so
  /// a test can drive an unusual one without reaching through the cubit.
  CameraCubit({
    required CameraEngine engine,
    required CaptureIntoBatch captureIntoBatch,
    CameraSelectionPolicy selection = const CameraSelectionPolicy(),
    ZoomPolicy zoom = const ZoomPolicy(),
    ZoomPresetPolicy presets = const ZoomPresetPolicy(),
    FocusPointMapper focusMapper = const FocusPointMapper(),
  }) : _engine = engine,
       _captureIntoBatch = captureIntoBatch,
       _selection = selection,
       _zoom = zoom,
       _presets = presets,
       _focusMapper = focusMapper,
       super(const CameraInitial());

  final CameraEngine _engine;
  final CaptureIntoBatch _captureIntoBatch;
  final CameraSelectionPolicy _selection;
  final ZoomPolicy _zoom;
  final ZoomPresetPolicy _presets;
  final FocusPointMapper _focusMapper;

  /// **The stale-async guard.**
  ///
  /// Bumped by every acquire, switch and release. Each asynchronous step
  /// captures the value it started with and has to prove it is still current
  /// before it may publish state or keep a session it just built. Without it,
  /// switching A→B and having A's `initialize()` land late leaves the app
  /// rendering a camera the user is no longer on — the single most common way
  /// a camera screen ends up showing a disposed controller (`FLT-CAM-013`).
  int _generation = 0;

  /// The one live session, or `null`. Nothing else may hold one.
  CameraSession? _session;

  /// Application-level capture guard.
  ///
  /// Deliberately **not** `CameraController.value.isTakingPicture`: that flag is
  /// set inside the plugin after our call reaches it, so two shutter presses in
  /// the same frame can both read it as false and both fire. The guard has to
  /// live where the two calls actually race, which is here (`FLT-CAM-014`).
  bool _captureInFlight = false;

  /// The zoom the platform is currently being asked for, keyed by generation.
  int? _zoomPumpGeneration;
  double? _pendingZoom;

  /// Monotonic tap counter, so a newer tap supersedes an older one's result.
  int _focusSequence = 0;

  /// Consecutive permission refusals this session (`ADR-F22`).
  int _denialCount = 0;

  /// The camera the user is on, if any.
  CameraDevice? get activeDevice =>
      _session?.device ??
      (state is CameraReleased ? (state as CameraReleased).device : null);

  /// Enumerates cameras and opens the default one (`FLT-CAM-011`).
  ///
  /// Safe to call repeatedly; each call supersedes any acquisition still in
  /// flight.
  Future<void> acquire() =>
      _acquire(phase: CameraPreparingPhase.discovering, preferred: null);

  /// Retries after a failure or a refusal, from the same entry point.
  ///
  /// Its own method purely so the call site reads as intent — `FLT-ERR-004`
  /// requires recovery without leaving the screen, and a button labelled
  /// "Try again" calling something called `acquire` reads worse than it works.
  Future<void> retry() => acquire();

  /// Moves to [device], which must be one of the enumerated back cameras.
  Future<void> switchTo(CameraDevice device) {
    final CameraState current = state;
    if (current is CameraReady && current.isCapturing) {
      // Refused, not queued. A switch mid-capture would dispose the controller
      // the photograph is being taken on; deferring it instead would mean the
      // camera changing under the user some time after they stopped asking.
      // The state already exposes `isCapturing`, so the control is disabled
      // visually as well — this guard is the backstop, not the only feedback
      // (`§14`).
      return Future<void>.value();
    }
    if (current is CameraReady && current.device.id == device.id) {
      return Future<void>.value();
    }
    return _acquire(phase: CameraPreparingPhase.switching, preferred: device);
  }

  /// Moves to the next back camera, wrapping.
  Future<void> switchToNextCamera() {
    final CameraState current = state;
    if (current is! CameraReady) {
      return Future<void>.value();
    }
    final CameraDevice? next = _selection.nextCamera(
      current.backCameras,
      current.device,
    );
    if (next == null) {
      return Future<void>.value();
    }
    return switchTo(next);
  }

  /// Applies the app-lifecycle transition (`FLT-CAM-012`).
  ///
  /// The plugin has not handled lifecycle since 0.5.0, so this is the app's job
  /// (`RESEARCH.md` `FR-02`). It is a cubit method rather than logic in the
  /// widget so it can be tested; the widget's only job is to translate
  /// `AppLifecycleState` into a [CameraLifecycleSignal].
  Future<void> handleLifecycle(CameraLifecycleSignal signal) {
    switch (signal) {
      case CameraLifecycleSignal.inactive:
        // Ignored on purpose. `inactive` fires for momentary overlays —
        // including the system permission dialog — and releasing there causes a
        // teardown/rebuild flicker during the very prompt that is trying to
        // grant access (`CAMERA_ENGINE.md` §2).
        return Future<void>.value();
      case CameraLifecycleSignal.paused:
      case CameraLifecycleSignal.detached:
        return release();
      case CameraLifecycleSignal.resumed:
        return _resume();
    }
  }

  /// Releases the hardware, keeping the selected camera for a later resume.
  ///
  /// Captures already taken are untouched: they are durable on the filesystem
  /// and in SQLite before this method can run, and nothing here reaches either
  /// (`FLT-CAM-015`).
  Future<void> release({bool isFinal = false}) async {
    final CameraDevice? device = activeDevice;
    _generation++;
    await _disposeSession();
    if (!isClosed) {
      emit(CameraReleased(device: device, isFinal: isFinal));
    }
  }

  /// Requests a zoom level, clamped to what the camera reported.
  ///
  /// The state moves immediately and the platform call follows, because the
  /// slider must track the finger rather than the IPC (`FLT-CAM-006`).
  Future<void> setZoom(double requested) async {
    final CameraState current = state;
    if (current is! CameraReady) {
      return;
    }
    final double clamped = _zoom.clamp(requested, current.zoomRange);
    final int generation = _generation;
    emit(current.copyWith(currentZoom: clamped, clearOperationError: true));
    await _pushZoom(clamped, generation);
  }

  /// Applies a preset (`FLT-CAM-005`).
  Future<void> applyPreset(ZoomPreset preset) => setZoom(preset.value);

  /// Records the zoom a pinch starts from.
  ///
  /// Called on gesture start. The value is held for the life of the gesture so
  /// that every update is measured from where the fingers landed, not from
  /// wherever the previous frame left off — the difference between a zoom that
  /// tracks the hand and one that drifts (`FLT-CAM-003`).
  void beginPinch() {
    final CameraState current = state;
    _pinchBaseline = current is CameraReady ? current.currentZoom : null;
  }

  double? _pinchBaseline;

  /// Applies a pinch update whose cumulative [scale] is measured from the
  /// gesture's start.
  Future<void> updatePinch(double scale) {
    final CameraState current = state;
    final double? baseline = _pinchBaseline;
    if (current is! CameraReady || baseline == null) {
      return Future<void>.value();
    }
    return setZoom(
      _zoom.forPinch(
        baseline: baseline,
        scale: scale,
        range: current.zoomRange,
      ),
    );
  }

  /// Ends the pinch gesture.
  void endPinch() => _pinchBaseline = null;

  /// Focuses where the user tapped (`FLT-CAM-008`).
  ///
  /// [tapX] and [tapY] are local to the preview widget; [layout] describes how
  /// the image is fitted inside it. Both come from the UI, because only the UI
  /// knows them — and passing the raw screen size instead is the mistake that
  /// focuses on the wrong part of the scene.
  ///
  /// A tap that lands outside the image (a letterbox band under
  /// [PreviewFit.contain]) is ignored: there is nothing there to focus on.
  Future<void> focusAt({
    required double tapX,
    required double tapY,
    required PreviewLayout layout,
  }) async {
    final CameraState current = state;
    if (current is! CameraReady) {
      return;
    }
    final NormalizedPoint? point = _focusMapper.toNormalized(
      tapX: tapX,
      tapY: tapY,
      layout: layout,
    );
    if (point == null) {
      return;
    }

    final int sequence = ++_focusSequence;
    final int generation = _generation;

    if (!current.canFocus) {
      // Not an error. The hardware cannot do it, and saying so is different
      // from saying the camera is broken (`§24`).
      emit(
        current.copyWith(
          focusRequest: FocusRequest(
            sequence: sequence,
            point: point,
            outcome: FocusOutcome.unsupported,
          ),
        ),
      );
      return;
    }

    emit(
      current.copyWith(
        focusRequest: FocusRequest(
          sequence: sequence,
          point: point,
          outcome: FocusOutcome.pending,
        ),
        clearOperationError: true,
      ),
    );

    final CameraSession? session = _session;
    if (session == null) {
      return;
    }

    try {
      await session.setFocusPoint(point);
    } catch (error) {
      _publishFocus(
        generation,
        sequence,
        FocusRequest(
          sequence: sequence,
          point: point,
          outcome: FocusOutcome.failed,
        ),
        // A rejected focus point is not a reason to tear down a working
        // viewfinder, so it lands as an operation error rather than a state
        // change (`§24`).
        operationError: _asFailure(error, CameraErrorKind.focusFailed),
      );
      return;
    }

    bool exposurePaired = false;
    bool exposureFailed = false;
    if (current.canSetExposurePoint) {
      try {
        await session.setExposurePoint(point);
        exposurePaired = true;
      } catch (_) {
        // The bonus failing must not undo the mandatory operation that
        // succeeded: focus is set, and the user's tap did what they asked
        // (`FLT-CAM-018`, `§23`).
        exposureFailed = true;
      }
    }

    _publishFocus(
      generation,
      sequence,
      FocusRequest(
        sequence: sequence,
        point: point,
        outcome: FocusOutcome.applied,
        exposurePaired: exposurePaired,
        exposureFailed: exposureFailed,
      ),
    );
  }

  /// Takes one photograph and puts it in the open draft batch.
  ///
  /// The ordering that matters is not implemented here — it is delegated, and
  /// deliberately so. `takePicture()` yields a **temporary** file; making it
  /// durable and writing the queue row is [CaptureIntoBatch] over F1's
  /// [RecordCapture], where the file-then-row rule and its compensation already
  /// live and are already tested (`FLT-CAM-015`, `FLT-ERR-005`).
  ///
  /// If the photograph fails, nothing durable was attempted, so there is no
  /// file and no row to clean up (`§27`).
  Future<void> capture() async {
    final CameraState current = state;
    if (current is! CameraReady) {
      return;
    }
    if (_captureInFlight) {
      // The second of two simultaneous shutter presses. Dropped deterministically
      // so exactly one platform capture happens (`FLT-CAM-014`).
      return;
    }

    final CameraSession? session = _session;
    if (session == null) {
      return;
    }

    _captureInFlight = true;
    final int generation = _generation;
    emit(current.copyWith(isCapturing: true, clearOperationError: true));

    try {
      final String temporaryPath = await session.takePicture();

      if (!_isCurrent(generation)) {
        // The session went away while the shutter was open. The bytes are the
        // plugin's to reclaim; publishing state for a camera that is gone is
        // what this guard exists to prevent.
        return;
      }

      final CaptureResult result = await _captureIntoBatch(
        temporaryPath: temporaryPath,
      );

      _publishReady(
        generation,
        (CameraReady ready) => ready.copyWith(
          isCapturing: false,
          lastCaptureImageId: result.image.id,
          batchImageCount: result.imageCount,
        ),
      );
    } catch (error) {
      // Both halves land here: a plugin failure taking the photograph, and a
      // storage or database failure making it durable. The cause is preserved
      // so the later UI can tell a user "storage is full" rather than "camera
      // error", but the session itself is untouched — it is still usable.
      _publishReady(
        generation,
        (CameraReady ready) => ready.copyWith(
          isCapturing: false,
          lastOperationError: _asFailure(error, CameraErrorKind.captureFailed),
        ),
      );
    } finally {
      _captureInFlight = false;
    }
  }

  @override
  Future<void> close() async {
    _generation++;
    await _disposeSession();
    return super.close();
  }

  // ---------------------------------------------------------------------------
  // Sequencing
  // ---------------------------------------------------------------------------

  /// One acquisition path for cold start, retry, switch and resume.
  ///
  /// They differ only in which camera is wanted and what to call the wait, so
  /// they share the algorithm rather than each growing their own copy of the
  /// generation guard — which is how one of the four ends up without it.
  Future<void> _acquire({
    required CameraPreparingPhase phase,
    required CameraDevice? preferred,
  }) async {
    final int generation = ++_generation;

    // Before anything else. Two live sessions on one device is the leak this
    // ordering prevents; the old controller is gone before the new one is asked
    // for (`§14`).
    await _disposeSession();
    if (!_isCurrent(generation)) {
      return;
    }
    emit(CameraPreparing(phase, device: preferred));

    final List<CameraDevice> all;
    try {
      all = await _engine.availableCameras();
    } catch (error) {
      _publish(
        generation,
        CameraFailed(_asFailure(error, CameraErrorKind.cameraUnavailable)),
      );
      return;
    }
    if (!_isCurrent(generation)) {
      return;
    }

    if (all.isEmpty) {
      _publish(
        generation,
        const CameraUnavailable(CameraUnavailableReason.noCameras),
      );
      return;
    }

    final List<CameraDevice> back = _selection.backCameras(all);
    if (back.isEmpty) {
      // Cameras exist, but the assessment asks for the *back* ones, and there
      // are none. A named state, not an exception (`FLT-ERR-003`).
      _publish(
        generation,
        const CameraUnavailable(CameraUnavailableReason.noBackCamera),
      );
      return;
    }

    final CameraDevice target = _resolveTarget(back, preferred);
    emit(CameraPreparing(phase, device: target));

    final CameraSession session;
    try {
      session = await _engine.openSession(target);
    } catch (error) {
      _publishOpenFailure(
        generation,
        _asFailure(error, CameraErrorKind.initializationFailed),
      );
      return;
    }

    if (!_isCurrent(generation)) {
      // **The race this whole mechanism exists for.** A switch A→B→C where A
      // finishes last: A's session is real and open, and attaching it would put
      // the user on a camera they left two taps ago. It is disposed instead,
      // and no state is emitted.
      await session.dispose();
      return;
    }

    _session = session;
    _denialCount = 0;

    final double startingZoom = _zoom.defaultFor(session.capabilities.zoom);
    emit(
      CameraReady(
        session: session,
        backCameras: back,
        presets: _presets.presetsFor(session.capabilities.zoom),
        currentZoom: startingZoom,
      ),
    );

    // The camera opens at its own baseline rather than inheriting the previous
    // camera's number, which would mean a different field of view than the one
    // the user was looking at a moment ago (`§14`).
    await _pushZoom(startingZoom, generation);
  }

  CameraDevice _resolveTarget(
    List<CameraDevice> back,
    CameraDevice? preferred,
  ) {
    if (preferred != null) {
      for (final CameraDevice device in back) {
        if (device.id == preferred.id) {
          return device;
        }
      }
    }
    // `defaultCamera` cannot return null here: `back` is known non-empty.
    return _selection.defaultCamera(back) ?? back.first;
  }

  Future<void> _resume() {
    final CameraState current = state;
    if (current is CameraReady || current is CameraPreparing) {
      return Future<void>.value();
    }
    if (current is CameraUnavailable) {
      // A device with no usable camera will still have none after a trip to
      // the home screen. Re-enumerating on every resume would be a pointless
      // loop against a fact that cannot change.
      return Future<void>.value();
    }
    final CameraDevice? previous = current is CameraReleased
        ? current.device
        : null;
    // Reacquiring from the denied state is what makes the settings round-trip
    // work without the user having to find a retry button
    // (`CAMERA_ENGINE.md` §7).
    return _acquire(phase: CameraPreparingPhase.restoring, preferred: previous);
  }

  /// Serialises zoom writes and coalesces superseded ones.
  ///
  /// A pinch produces callbacks far faster than the platform channel can retire
  /// them. Firing one `setZoomLevel` per callback floods the plugin and the
  /// values arrive out of order; queueing them all makes the zoom lag seconds
  /// behind the fingers. So: one call in flight, the newest request kept, and
  /// **the last value the user asked for is always the one finally applied**
  /// (`§19`).
  Future<void> _pushZoom(double value, int generation) async {
    if (_zoomPumpGeneration == generation) {
      _pendingZoom = value;
      return;
    }
    _zoomPumpGeneration = generation;
    double next = value;
    try {
      while (true) {
        final CameraSession? session = _session;
        if (session == null || !_isCurrent(generation)) {
          return;
        }
        try {
          await session.setZoom(next);
        } catch (error) {
          _publishReady(
            generation,
            (CameraReady ready) => ready.copyWith(
              lastOperationError: _asFailure(error, CameraErrorKind.zoomFailed),
            ),
          );
          return;
        }
        final double? pending = _pendingZoom;
        _pendingZoom = null;
        if (pending == null) {
          return;
        }
        next = pending;
      }
    } finally {
      if (_zoomPumpGeneration == generation) {
        _zoomPumpGeneration = null;
        _pendingZoom = null;
      }
    }
  }

  Future<void> _disposeSession() async {
    final CameraSession? session = _session;
    _session = null;
    _zoomPumpGeneration = null;
    _pendingZoom = null;
    _pinchBaseline = null;
    if (session != null) {
      await session.dispose();
    }
  }

  // ---------------------------------------------------------------------------
  // Publishing — every path through here proves it is still current first
  // ---------------------------------------------------------------------------

  bool _isCurrent(int generation) => !isClosed && generation == _generation;

  void _publish(int generation, CameraState next) {
    if (_isCurrent(generation)) {
      emit(next);
    }
  }

  /// Applies [update] to the current ready state, if there still is one.
  void _publishReady(int generation, CameraReady Function(CameraReady) update) {
    if (!_isCurrent(generation)) {
      return;
    }
    final CameraState current = state;
    if (current is CameraReady) {
      emit(update(current));
    }
  }

  void _publishFocus(
    int generation,
    int sequence,
    FocusRequest request, {
    CameraFailure? operationError,
  }) {
    // A newer tap has already been made; publishing this one would move the
    // reticle backwards to where the user tapped before.
    if (sequence != _focusSequence) {
      return;
    }
    _publishReady(
      generation,
      (CameraReady ready) => ready.copyWith(
        focusRequest: request,
        lastOperationError: operationError,
      ),
    );
  }

  /// Turns an open-session failure into the right state.
  ///
  /// Permission is separated from hardware here because they lead to different
  /// places: one offers to ask again, the other offers to retry or explains
  /// there is nothing to retry (`FLT-ERR-001`, `FLT-ERR-004`).
  void _publishOpenFailure(int generation, CameraFailure failure) {
    if (!_isCurrent(generation)) {
      return;
    }
    if (failure.kind.isPermissionProblem) {
      _denialCount++;
      emit(
        CameraPermissionDenied(
          isPermanentPerPlatform:
              failure.kind == CameraErrorKind.permissionPermanentlyDenied,
          isRestricted: failure.kind == CameraErrorKind.permissionRestricted,
          consecutiveDenials: _denialCount,
        ),
      );
      return;
    }
    emit(CameraFailed(failure));
  }

  /// Classifies anything thrown into the app's error model.
  ///
  /// The adapter has already done this for plugin errors, so this mostly passes
  /// [CameraFailure] straight through. It exists for what the adapter cannot
  /// see: a storage or database error arriving from the capture pipeline, which
  /// must be labelled by the operation it broke rather than by its own type.
  CameraFailure _asFailure(Object error, CameraErrorKind fallback) {
    if (error is CameraFailure) {
      return error;
    }
    return CameraFailure(fallback, cause: error);
  }
}
