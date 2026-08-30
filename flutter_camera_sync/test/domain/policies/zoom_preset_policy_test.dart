// FLT-CAM-005, FLT-CAM-016, ADR-F03.
//
// The honesty requirement, made checkable. The single most important assertion
// in this file is the one that says no preset claims an optical identity when
// the platform reported none — because that is the exact failure the assessment
// is most likely to be probing with a truncated example.

import 'package:flutter_test/flutter_test.dart';
import 'package:presence_lens_capture/domain/entities/camera_capabilities.dart';
import 'package:presence_lens_capture/domain/entities/camera_device.dart';
import 'package:presence_lens_capture/domain/entities/zoom_preset.dart';
import 'package:presence_lens_capture/domain/policies/zoom_preset_policy.dart';

void main() {
  const ZoomPresetPolicy policy = ZoomPresetPolicy();

  CameraDevice device(
    String id, {
    CameraLensKind lens = CameraLensKind.unknown,
    int ordinal = 0,
  }) => CameraDevice(
    id: id,
    facing: CameraFacing.back,
    sensorOrientation: 90,
    lensKind: lens,
    ordinalAmongFacing: ordinal,
  );

  List<String> labels(List<ZoomPreset> presets) =>
      presets.map((ZoomPreset p) => p.label).toList();

  group('presets from the reported range', () {
    test('a camera that cannot zoom offers only its baseline', () {
      expect(labels(policy.presetsFor(ZoomRange.fixed)), <String>['1x']);
    });

    test(
      'no sub-1 preset appears unless the device reported a sub-1 minimum',
      () {
        final List<ZoomPreset> presets = policy.presetsFor(
          ZoomRange(min: 1, max: 8),
        );
        expect(labels(presets), <String>['1x', '2x', '5x']);
        expect(
          presets.every((ZoomPreset p) => p.value >= 1),
          isTrue,
          reason:
              'a 0.5x button on a device with no sub-1 range is a fabrication',
        );
      },
    );

    test('a sub-1 preset uses the REPORTED minimum, not a rounded 0.5', () {
      // The device said 0.6. Printing "0.5x" because that is what the
      // assessment's example happened to show would be inventing hardware.
      final List<ZoomPreset> presets = policy.presetsFor(
        ZoomRange(min: 0.6, max: 4),
      );
      expect(labels(presets), <String>['0.6x', '1x', '2x']);
      expect(presets.first.value, 0.6);
    });

    test(
      'a device that genuinely reports 0.5 gets 0.5x — because it said so',
      () {
        expect(
          labels(policy.presetsFor(ZoomRange(min: 0.5, max: 10))),
          <String>['0.5x', '1x', '2x', '5x', '10x'],
        );
      },
    );

    test('upper stops stop where the reported maximum stops', () {
      expect(labels(policy.presetsFor(ZoomRange(min: 1, max: 3))), <String>[
        '1x',
        '2x',
      ]);
      expect(labels(policy.presetsFor(ZoomRange(min: 1, max: 5))), <String>[
        '1x',
        '2x',
        '5x',
      ]);
    });

    test('no preset ever falls outside the reported range', () {
      for (final ZoomRange range in <ZoomRange>[
        ZoomRange.fixed,
        ZoomRange(min: 0.5, max: 2),
        ZoomRange(min: 0.75, max: 12),
        ZoomRange(min: 1, max: 1.9),
        ZoomRange(min: 3, max: 30),
      ]) {
        for (final ZoomPreset preset in policy.presetsFor(range)) {
          expect(
            range.contains(preset.value),
            isTrue,
            reason: '$preset escaped $range',
          );
        }
      }
    });

    test('a camera whose whole range sits above 1 offers its own baseline', () {
      // A fixed telephoto. "1x" would be a button that cannot be honoured.
      final List<ZoomPreset> presets = policy.presetsFor(
        ZoomRange(min: 2, max: 10),
      );
      expect(labels(presets), <String>['2x', '5x', '10x']);
      expect(presets.any((ZoomPreset p) => p.label == '1x'), isFalse);
    });

    test('the baseline preset is the only one claiming to be exactly 1x', () {
      final List<ZoomPreset> presets = policy.presetsFor(
        ZoomRange(min: 0.5, max: 8),
      );
      final Iterable<ZoomPreset> baseline = presets.where(
        (ZoomPreset p) => p.provenance == ZoomPresetProvenance.baseline,
      );
      expect(baseline.length, 1);
      expect(baseline.single.value, 1);
    });

    test('a preset row is not offered on a camera that cannot zoom', () {
      expect(policy.shouldOfferPresets(ZoomRange.fixed), isFalse);
      expect(policy.shouldOfferPresets(ZoomRange(min: 1, max: 2)), isTrue);
    });
  });

  group('the honesty rule (FLT-CAM-016)', () {
    test(
      'NO preset asserts an optical identity when the platform reported none',
      () {
        // Android, always. If this ever fails, the app has started making a
        // hardware claim it cannot support.
        for (final ZoomRange range in <ZoomRange>[
          ZoomRange.fixed,
          ZoomRange(min: 0.5, max: 8),
          ZoomRange(min: 0.6, max: 12),
          ZoomRange(min: 1, max: 30),
        ]) {
          for (final ZoomPreset preset in policy.presetsFor(range)) {
            expect(
              preset.claimsOpticalIdentity,
              isFalse,
              reason: '$preset claims optics the platform never reported',
            );
          }
        }
      },
    );

    test(
      'an unidentified camera is labelled by ordinal, never by multiplier',
      () {
        final ZoomPreset label = policy.labelForCamera(device('3', ordinal: 1));
        expect(label.label, 'Camera 2');
        expect(label.claimsOpticalIdentity, isFalse);
        expect(label.label, isNot(contains('x')));
      },
    );

    test(
      'an identified lens is named — and says the platform is its source',
      () {
        expect(
          policy
              .labelForCamera(device('0', lens: CameraLensKind.ultraWide))
              .label,
          'Ultra wide',
        );
        expect(
          policy.labelForCamera(device('1', lens: CameraLensKind.wide)).label,
          'Wide',
        );
        final ZoomPreset tele = policy.labelForCamera(
          device('2', lens: CameraLensKind.telephoto),
        );
        expect(tele.label, 'Telephoto');
        expect(tele.provenance, ZoomPresetProvenance.platformReportedLens);
        expect(tele.claimsOpticalIdentity, isTrue);
      },
    );
  });

  group('camera selector visibility', () {
    test('one rear camera is not a choice', () {
      expect(
        policy.shouldOfferCameraSelector(<CameraDevice>[device('0')]),
        isFalse,
      );
    });

    test('two or more rear cameras are offered', () {
      expect(
        policy.shouldOfferCameraSelector(<CameraDevice>[
          device('0'),
          device('1', ordinal: 1),
        ]),
        isTrue,
      );
    });

    test('no rear camera means no selector', () {
      expect(policy.shouldOfferCameraSelector(<CameraDevice>[]), isFalse);
    });
  });
}
