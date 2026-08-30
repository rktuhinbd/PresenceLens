import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

import '../../domain/entities/camera_capabilities.dart';
import '../../domain/entities/camera_device.dart';
import '../../domain/entities/camera_error.dart';
import '../../domain/entities/camera_geometry.dart';
import '../../domain/ports/camera_engine.dart';
import 'camera_error_translation.dart';
import 'camera_preview_source.dart';

/// Signature of `availableCameras()`, injected so enumeration can be faked.
typedef CameraLister = Future<List<CameraDescription>> Function();

/// The plugin's own enumeration, behind a name the adapter's own method does
/// not shadow.
Future<List<CameraDescription>> _pluginCameras() => availableCameras();

/// Builds a controller for a description. Injected for the same reason.
typedef ControllerFactory =
    CameraController Function(CameraDescription description);

/// The [CameraEngine] implemented over the `camera` plugin.
///
/// Everything plugin-shaped stops here: `CameraDescription`,
/// `CameraController`, `CameraException` and `XFile` do not appear above this
/// file, which is what keeps the domain purity rule honest and the cubit
/// testable with no binding at all (`FLT-GEN-007`).
///
/// On Android the plugin resolves to `camera_android_camerax`, so this is a
/// CameraX adapter in practice. It is deliberately **not** swapped for the
/// Camera2 implementation to obtain richer lens metadata: that would be a
/// platform change made on speculation, and an honest label costs nothing while
/// a backend swap risks everything (`ADR-F03`, `RESEARCH.md` `FR-04`).
class CameraXAdapter implements CameraEngine {
  /// Creates the adapter.
  ///
  /// [lister] and [controllerFactory] default to the plugin's own entry points.
  /// They are injectable so the adapter's *translation* can be exercised
  /// without a device; the state machine above it is tested against a fake
  /// engine instead, which is cheaper and covers far more.
  CameraXAdapter({
    CameraLister? lister,
    ControllerFactory? controllerFactory,
    this.resolution = ResolutionPreset.high,
  }) : _lister = lister ?? _pluginCameras,
       _controllerFactory = controllerFactory;

  final CameraLister _lister;
  final ControllerFactory? _controllerFactory;

  /// Capture resolution requested from the platform.
  final ResolutionPreset resolution;

  /// The descriptions behind the [CameraDevice]s handed out by
  /// [availableCameras], keyed by device id.
  ///
  /// The domain type deliberately does not carry the plugin object around, so
  /// the adapter keeps the mapping itself. The key is the platform's own camera
  /// name, which on Android is the raw Camera2 id.
  final Map<String, CameraDescription> _descriptions =
      <String, CameraDescription>{};

  @override
  Future<List<CameraDevice>> availableCameras() async {
    final List<CameraDescription> descriptions;
    try {
      descriptions = await _lister();
    } catch (error) {
      throw CameraErrorTranslation.classify(
        error,
        CameraErrorKind.cameraUnavailable,
      );
    }

    _descriptions.clear();
    final List<CameraDevice> devices = <CameraDevice>[];
    final Map<CameraFacing, int> counts = <CameraFacing, int>{};

    for (final CameraDescription description in descriptions) {
      final CameraFacing facing = _facing(description.lensDirection);
      final int ordinal = counts[facing] ?? 0;
      counts[facing] = ordinal + 1;

      _descriptions[description.name] = description;
      devices.add(
        CameraDevice(
          id: description.name,
          facing: facing,
          sensorOrientation: description.sensorOrientation,
          lensKind: _lensKind(description.lensType),
          ordinalAmongFacing: ordinal,
        ),
      );
    }

    return List<CameraDevice>.unmodifiable(devices);
  }

  @override
  Future<CameraSession> openSession(CameraDevice device) async {
    final CameraDescription? description = _descriptions[device.id];
    if (description == null) {
      throw CameraFailure(
        CameraErrorKind.cameraUnavailable,
        cause: StateError(
          'camera ${device.id} was not in the last enumeration',
        ),
      );
    }

    final CameraController controller =
        _controllerFactory?.call(description) ??
        CameraController(
          description,
          resolution,
          // Not a detail. Leaving audio on makes the plugin request the
          // **microphone** permission for an app that only takes stills — a
          // real privacy defect, and one a reviewer would rightly flag
          // (`FLT-CAM-017`).
          enableAudio: false,
        );

    try {
      await controller.initialize();
    } catch (error) {
      // The controller object exists even though it would not start; dropping
      // it undisposed leaks the platform handle for the life of the process.
      await _disposeQuietly(controller);
      throw CameraErrorTranslation.classify(
        error,
        CameraErrorKind.initializationFailed,
      );
    }

    final CameraCapabilities capabilities;
    try {
      capabilities = await _readCapabilities(controller);
    } catch (error) {
      await _disposeQuietly(controller);
      throw CameraErrorTranslation.classify(
        error,
        CameraErrorKind.initializationFailed,
      );
    }

    return CameraXSession(
      device: device,
      capabilities: capabilities,
      controller: controller,
    );
  }

  /// Reads back what the open camera actually supports.
  ///
  /// Every value comes from the platform. The minimum zoom in particular is
  /// asked for rather than assumed to be 1.0: CameraX reports real sub-1 ratios
  /// on hardware that has them, and inventing the floor would make the wide end
  /// of the range unreachable (`FLT-CAM-007`).
  Future<CameraCapabilities> _readCapabilities(
    CameraController controller,
  ) async {
    final double min = await controller.getMinZoomLevel();
    final double max = await controller.getMaxZoomLevel();
    final Size? preview = controller.value.previewSize;

    return CameraCapabilities(
      zoom: ZoomRange(min: min, max: max),
      focusPointSupported: controller.value.focusPointSupported,
      exposurePointSupported: controller.value.exposurePointSupported,
      previewAspectRatio: preview == null || preview.height <= 0
          ? null
          : preview.width / preview.height,
    );
  }

  Future<void> _disposeQuietly(CameraController controller) async {
    try {
      await controller.dispose();
    } catch (_) {
      // A more useful failure is already on its way up; masking it with a
      // disposal error would be strictly worse.
    }
  }

  static CameraFacing _facing(CameraLensDirection direction) {
    switch (direction) {
      case CameraLensDirection.back:
        return CameraFacing.back;
      case CameraLensDirection.front:
        return CameraFacing.front;
      case CameraLensDirection.external:
        return CameraFacing.external;
    }
  }

  /// Maps the platform's lens type across **without filling in a default**.
  ///
  /// `CameraLensType.unknown` becomes [CameraLensKind.unknown] and stops there.
  /// It would be one line to guess that the first back camera is the wide one;
  /// that line is the fabrication this design exists to avoid (`FLT-CAM-016`).
  static CameraLensKind _lensKind(CameraLensType type) {
    switch (type) {
      case CameraLensType.wide:
        return CameraLensKind.wide;
      case CameraLensType.telephoto:
        return CameraLensKind.telephoto;
      case CameraLensType.ultraWide:
        return CameraLensKind.ultraWide;
      case CameraLensType.unknown:
        return CameraLensKind.unknown;
    }
  }
}

/// One live `CameraController`, behind the [CameraSession] port.
///
/// **This object is the sole owner of its controller.** The adapter creates it,
/// the cubit holds exactly one at a time, and [dispose] destroys it; nothing
/// else constructs or disposes one. Widgets reach the preview through
/// [CameraPreviewSource], which *reads* the controller and can never replace it
/// (`CAMERA_ENGINE.md` §9).
class CameraXSession implements CameraSession, CameraPreviewSource {
  /// Wraps an already-initialised [controller].
  CameraXSession({
    required this.device,
    required this.capabilities,
    required CameraController controller,
  }) : _controller = controller;

  @override
  final CameraDevice device;

  @override
  final CameraCapabilities capabilities;

  final CameraController _controller;
  bool _disposed = false;

  @override
  bool get isDisposed => _disposed;

  @override
  CameraController get previewController => _controller;

  @override
  Future<void> setZoom(double zoom) =>
      _guard(() => _controller.setZoomLevel(zoom), CameraErrorKind.zoomFailed);

  @override
  Future<void> setFocusPoint(NormalizedPoint point) => _guard(
    () => _controller.setFocusPoint(Offset(point.x, point.y)),
    CameraErrorKind.focusFailed,
  );

  @override
  Future<void> setExposurePoint(NormalizedPoint point) => _guard(
    () => _controller.setExposurePoint(Offset(point.x, point.y)),
    CameraErrorKind.exposureFailed,
  );

  @override
  Future<String> takePicture() async {
    if (_disposed) {
      throw const CameraFailure(CameraErrorKind.sessionDisposed);
    }
    try {
      final XFile file = await _controller.takePicture();
      // The path, not the `XFile`. This is a **temporary** location the OS may
      // reclaim at any time, and it is handed straight to `CaptureStore` before
      // anything treats the capture as real (`FLT-CAM-015`).
      return file.path;
    } catch (error) {
      throw CameraErrorTranslation.classify(
        error,
        CameraErrorKind.captureFailed,
      );
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      // Idempotent on purpose: a lifecycle release and a camera switch can each
      // decide to let this session go, and the second one has to be a no-op
      // rather than a plugin exception (`§33`).
      return;
    }
    _disposed = true;
    try {
      await _controller.dispose();
    } catch (_) {
      // Nothing useful is left to do with a controller being discarded.
    }
  }

  Future<void> _guard(
    Future<void> Function() operation,
    CameraErrorKind fallback,
  ) async {
    if (_disposed) {
      throw const CameraFailure(CameraErrorKind.sessionDisposed);
    }
    try {
      await operation();
    } catch (error) {
      throw CameraErrorTranslation.classify(error, fallback);
    }
  }
}
