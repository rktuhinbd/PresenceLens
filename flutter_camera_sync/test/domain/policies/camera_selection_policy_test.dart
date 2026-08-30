// FLT-CAM-011.
//
// "Available back cameras" is the assessment's own wording, so filtering is a
// requirement rather than tidiness — and the default-camera rule is written
// down here so that "whichever one came back first" cannot quietly become the
// policy.

import 'package:flutter_test/flutter_test.dart';
import 'package:presence_lens_capture/domain/entities/camera_device.dart';
import 'package:presence_lens_capture/domain/policies/camera_selection_policy.dart';

void main() {
  const CameraSelectionPolicy policy = CameraSelectionPolicy();

  CameraDevice camera(
    String id,
    CameraFacing facing, {
    CameraLensKind lens = CameraLensKind.unknown,
  }) => CameraDevice(
    id: id,
    facing: facing,
    sensorOrientation: 90,
    lensKind: lens,
  );

  List<String> ids(List<CameraDevice> devices) =>
      devices.map((CameraDevice d) => d.id).toList();

  group('back-camera filtering', () {
    test('front cameras are excluded', () {
      final List<CameraDevice> back = policy.backCameras(<CameraDevice>[
        camera('0', CameraFacing.back),
        camera('1', CameraFacing.front),
      ]);
      expect(ids(back), <String>['0']);
    });

    test('external cameras are excluded too', () {
      // A USB webcam is not one of the "available back cameras"; offering it
      // would answer a question nobody asked.
      final List<CameraDevice> back = policy.backCameras(<CameraDevice>[
        camera('0', CameraFacing.back),
        camera('9', CameraFacing.external),
      ]);
      expect(ids(back), <String>['0']);
    });

    test('a front-only device yields nothing', () {
      expect(
        policy.backCameras(<CameraDevice>[camera('1', CameraFacing.front)]),
        isEmpty,
      );
    });

    test('an empty enumeration yields nothing', () {
      expect(policy.backCameras(<CameraDevice>[]), isEmpty);
    });

    test('several back cameras are all kept, in enumeration order', () {
      final List<CameraDevice> back = policy.backCameras(<CameraDevice>[
        camera('0', CameraFacing.back),
        camera('1', CameraFacing.front),
        camera('2', CameraFacing.back),
        camera('3', CameraFacing.back),
      ]);
      expect(ids(back), <String>['0', '2', '3']);
    });

    test('ordinals are re-stamped over the back cameras only', () {
      // So "Camera 2" means the second *rear* camera, not the second camera the
      // platform happened to list.
      final List<CameraDevice> back = policy.backCameras(<CameraDevice>[
        camera('0', CameraFacing.front),
        camera('1', CameraFacing.back),
        camera('2', CameraFacing.back),
      ]);
      expect(back.map((CameraDevice d) => d.ordinalAmongFacing).toList(), <int>[
        0,
        1,
      ]);
    });

    test('the returned list cannot be mutated by a caller', () {
      final List<CameraDevice> back = policy.backCameras(<CameraDevice>[
        camera('0', CameraFacing.back),
      ]);
      expect(
        () => back.add(camera('9', CameraFacing.back)),
        throwsUnsupportedError,
      );
    });
  });

  group('default camera', () {
    test('nothing to choose from returns null', () {
      expect(policy.defaultCamera(<CameraDevice>[]), isNull);
    });

    test('a single back camera is the choice', () {
      final List<CameraDevice> back = policy.backCameras(<CameraDevice>[
        camera('0', CameraFacing.back),
      ]);
      expect(policy.defaultCamera(back)!.id, '0');
    });

    test('the platform-identified wide lens wins when there is one', () {
      // Reachable on iOS. This is the branch that uses real information.
      final List<CameraDevice> back = policy.backCameras(<CameraDevice>[
        camera('0', CameraFacing.back, lens: CameraLensKind.ultraWide),
        camera('1', CameraFacing.back, lens: CameraLensKind.wide),
        camera('2', CameraFacing.back, lens: CameraLensKind.telephoto),
      ]);
      expect(policy.defaultCamera(back)!.id, '1');
    });

    test(
      'with no lens identity it falls back to the first, deterministically',
      () {
        // Android, always. This is a *stable* choice, explicitly not a claim that
        // camera 0 is the 1x lens.
        final List<CameraDevice> back = policy.backCameras(<CameraDevice>[
          camera('4', CameraFacing.back),
          camera('0', CameraFacing.back),
          camera('2', CameraFacing.back),
        ]);
        expect(policy.defaultCamera(back)!.id, '4');
        expect(policy.defaultCamera(back)!.id, '4', reason: 'same every time');
      },
    );
  });

  group('next camera', () {
    test('a single camera has no next', () {
      final List<CameraDevice> back = policy.backCameras(<CameraDevice>[
        camera('0', CameraFacing.back),
      ]);
      expect(policy.nextCamera(back, back.first), isNull);
    });

    test('cycles forward and wraps', () {
      final List<CameraDevice> back = policy.backCameras(<CameraDevice>[
        camera('0', CameraFacing.back),
        camera('1', CameraFacing.back),
        camera('2', CameraFacing.back),
      ]);
      expect(policy.nextCamera(back, back[0])!.id, '1');
      expect(policy.nextCamera(back, back[1])!.id, '2');
      expect(policy.nextCamera(back, back[2])!.id, '0');
    });

    test('an unknown current camera starts from the beginning', () {
      final List<CameraDevice> back = policy.backCameras(<CameraDevice>[
        camera('0', CameraFacing.back),
        camera('1', CameraFacing.back),
      ]);
      expect(policy.nextCamera(back, null)!.id, '0');
    });
  });

  group('lens-identity trust', () {
    test('all-unknown reports no trustworthy identity — the Android case', () {
      expect(
        policy.hasTrustworthyLensIdentity(<CameraDevice>[
          camera('0', CameraFacing.back),
          camera('1', CameraFacing.back),
          camera('2', CameraFacing.front),
        ]),
        isFalse,
      );
    });

    test('one identified lens is enough to trust the platform', () {
      expect(
        policy.hasTrustworthyLensIdentity(<CameraDevice>[
          camera('0', CameraFacing.back, lens: CameraLensKind.wide),
          camera('1', CameraFacing.back),
        ]),
        isTrue,
      );
    });
  });
}
