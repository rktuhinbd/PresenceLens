// §38, FQ-01.
//
// The device-QA session has to either confirm `RESEARCH.md` FR-04 or overturn
// it, and doing that by squinting at a preview is not evidence. This is the
// format of the answer, tested so the physical run produces something
// copyable rather than something to be paraphrased.

import 'package:flutter_test/flutter_test.dart';
import 'package:presence_lens_capture/data/camera/camera_diagnostics.dart';
import 'package:presence_lens_capture/domain/entities/camera_capabilities.dart';
import 'package:presence_lens_capture/domain/entities/camera_device.dart';

void main() {
  CameraObservation observed(
    String id, {
    CameraFacing facing = CameraFacing.back,
    CameraLensKind lens = CameraLensKind.unknown,
    int ordinal = 0,
    CameraCapabilities? capabilities,
  }) => CameraObservation(
    device: CameraDevice(
      id: id,
      facing: facing,
      sensorOrientation: 90,
      lensKind: lens,
      ordinalAmongFacing: ordinal,
    ),
    capabilities: capabilities,
  );

  test('reports every field the device checklist asks for', () {
    final String report = CameraDiagnostics.report(<CameraObservation>[
      observed(
        '0',
        capabilities: CameraCapabilities(
          zoom: ZoomRange(min: 0.6, max: 10),
          focusPointSupported: true,
          exposurePointSupported: true,
          previewAspectRatio: 4 / 3,
        ),
      ),
    ]);

    expect(report, contains('id=0'));
    expect(report, contains('lensType=unknown'));
    expect(report, contains('sensorOrientation=90'));
    expect(report, contains('zoom=0.6..10.0'));
    expect(report, contains('focusPoint=true'));
    expect(report, contains('exposurePoint=true'));
  });

  test('counts the back cameras — FQ-01', () {
    final String report = CameraDiagnostics.report(<CameraObservation>[
      observed('0'),
      observed('1', ordinal: 1),
      observed('2', facing: CameraFacing.front),
    ]);

    expect(report, contains('backCameras=2'));
  });

  test('states plainly when the platform gave no lens identity', () {
    final String report = CameraDiagnostics.report(<CameraObservation>[
      observed('0'),
      observed('1', ordinal: 1),
    ]);

    expect(report, contains('lensIdentityAvailable=false'));
    expect(
      report,
      contains('ADR-F03'),
      reason: 'the report names the decision the answer confirms or overturns',
    );
  });

  test('an identified lens flips the verdict', () {
    final String report = CameraDiagnostics.report(<CameraObservation>[
      observed('0', lens: CameraLensKind.ultraWide),
    ]);

    expect(report, contains('lensIdentityAvailable=true'));
    expect(report, contains('lensType=ultraWide'));
    expect(report, isNot(contains('ADR-F03')));
  });

  test('a camera that was never opened says so instead of guessing', () {
    final String report = CameraDiagnostics.report(<CameraObservation>[
      observed('0'),
    ]);

    expect(report, contains('zoom=<not opened>'));
  });

  test('an empty enumeration is reported explicitly', () {
    final String report = CameraDiagnostics.report(<CameraObservation>[]);

    expect(report, contains('0 reported'));
    expect(report, contains('empty list'));
  });

  test('no capture path or image content is ever logged', () {
    // A diagnostic on a user's device must not record what they photographed.
    final String report = CameraDiagnostics.report(<CameraObservation>[
      observed(
        '0',
        capabilities: const CameraCapabilities(
          zoom: ZoomRange.fixed,
          focusPointSupported: false,
          exposurePointSupported: false,
        ),
      ),
    ]);

    expect(report, isNot(contains('.jpg')));
    expect(report.toLowerCase(), isNot(contains('captures/')));
  });
}
