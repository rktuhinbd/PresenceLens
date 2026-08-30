import '../../domain/entities/camera_capabilities.dart';
import '../../domain/entities/camera_device.dart';

/// One camera as it was actually observed on a device.
///
/// [capabilities] is null until a session has been opened on that camera, which
/// is the honest shape: zoom range and focus support cannot be known from
/// enumeration alone.
class CameraObservation {
  /// Records one camera.
  const CameraObservation({required this.device, this.capabilities});

  /// The camera's identity, as reported.
  final CameraDevice device;

  /// What it reported once open, or `null` if it was never opened.
  final CameraCapabilities? capabilities;
}

/// Formats what the platform actually said about the cameras on this device.
///
/// **Why this exists.** `RESEARCH.md` `FR-04` says Android never populates
/// `lensType`, and that claim was made by reading the plugin source. The
/// physical-device session has to either confirm it or overturn it, and doing
/// that by squinting at a preview is not evidence. This turns the question into
/// one line of copyable output (`§38`, `FQ-01`).
///
/// It is a diagnostic, not a feature: nothing renders it, it is never on a user
/// path, and it deliberately records **no image path and no capture content** —
/// only hardware capability metadata.
class CameraDiagnostics {
  const CameraDiagnostics._();

  /// A stable, greppable report of [observations].
  ///
  /// One line per camera plus a verdict line, so the device-QA note can be
  /// pasted into `TRACEABILITY_MATRIX.md` verbatim rather than paraphrased.
  static String report(List<CameraObservation> observations) {
    final StringBuffer buffer = StringBuffer()
      ..writeln('CAMERA INVENTORY (${observations.length} reported)');

    if (observations.isEmpty) {
      buffer.writeln('  <none> — availableCameras() returned an empty list');
    }

    for (final CameraObservation observation in observations) {
      final CameraDevice d = observation.device;
      buffer
        ..write('  [${d.facing.name}#${d.ordinalAmongFacing}] ')
        ..write('id=${d.id} ')
        ..write('lensType=${d.lensKind.name} ')
        ..write('sensorOrientation=${d.sensorOrientation} ');

      final CameraCapabilities? caps = observation.capabilities;
      if (caps == null) {
        buffer.writeln('zoom=<not opened> focusPoint=? exposurePoint=?');
      } else {
        buffer
          ..write('zoom=${caps.zoom.min}..${caps.zoom.max} ')
          ..write('focusPoint=${caps.focusPointSupported} ')
          ..write('exposurePoint=${caps.exposurePointSupported} ')
          ..writeln('previewAspect=${caps.previewAspectRatio}');
      }
    }

    final int backCount = observations
        .where((CameraObservation o) => o.device.facing == CameraFacing.back)
        .length;
    final bool anyLensIdentity = observations.any(
      (CameraObservation o) => o.device.hasKnownLens,
    );

    buffer
      ..writeln('  backCameras=$backCount')
      ..writeln(
        '  lensIdentityAvailable=$anyLensIdentity'
        '${anyLensIdentity ? '' : '  (labels must stay range-derived — ADR-F03)'}',
      );

    return buffer.toString();
  }
}
