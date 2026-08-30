// FLT-CAM-008.
//
// The failure this guards is silent: a tap-to-focus that normalises against the
// widget instead of the image focuses on the wrong part of the scene, and the
// reticle still lands under the finger, so the bug looks like correct
// behaviour. Only arithmetic catches it, which is why the arithmetic is pure.

import 'package:flutter_test/flutter_test.dart';
import 'package:presence_lens_capture/domain/entities/camera_geometry.dart';
import 'package:presence_lens_capture/domain/policies/focus_point_mapper.dart';

void main() {
  const FocusPointMapper mapper = FocusPointMapper();

  PreviewLayout layout({
    required double width,
    required double height,
    required double aspect,
    PreviewFit fit = PreviewFit.cover,
  }) => PreviewLayout(
    widgetWidth: width,
    widgetHeight: height,
    previewAspectRatio: aspect,
    fit: fit,
  );

  void expectPoint(NormalizedPoint? actual, double x, double y) {
    expect(actual, isNotNull);
    expect(actual!.x, closeTo(x, 1e-6));
    expect(actual.y, closeTo(y, 1e-6));
  }

  group('exact fit — the only case where naive division is correct', () {
    final PreviewLayout square = layout(width: 400, height: 400, aspect: 1);

    test('the centre maps to the centre', () {
      expectPoint(
        mapper.toNormalized(tapX: 200, tapY: 200, layout: square),
        0.5,
        0.5,
      );
    });

    test('each corner maps to its corner', () {
      expectPoint(mapper.toNormalized(tapX: 0, tapY: 0, layout: square), 0, 0);
      expectPoint(
        mapper.toNormalized(tapX: 400, tapY: 0, layout: square),
        1,
        0,
      );
      expectPoint(
        mapper.toNormalized(tapX: 0, tapY: 400, layout: square),
        0,
        1,
      );
      expectPoint(
        mapper.toNormalized(tapX: 400, tapY: 400, layout: square),
        1,
        1,
      );
    });
  });

  group('contain — the image is letterboxed', () {
    // A 4:3 image in a tall phone-shaped box: bands above and below.
    final PreviewLayout tallBox = layout(
      width: 400,
      height: 800,
      aspect: 4 / 3,
      fit: PreviewFit.contain,
    );

    test('the drawn image is centred, so its centre is the box centre', () {
      expectPoint(
        mapper.toNormalized(tapX: 200, tapY: 400, layout: tallBox),
        0.5,
        0.5,
      );
    });

    test('a tap on the letterbox band is rejected, not clamped', () {
      // Image height is 400·(3/4) = 300, so it occupies y ∈ [250, 550].
      expect(
        mapper.toNormalized(tapX: 200, tapY: 100, layout: tallBox),
        isNull,
        reason: 'there is no image there to focus on',
      );
      expect(
        mapper.toNormalized(tapX: 200, tapY: 700, layout: tallBox),
        isNull,
      );
    });

    test('the exact top and bottom edges of the image are inside it', () {
      expectPoint(
        mapper.toNormalized(tapX: 200, tapY: 250, layout: tallBox),
        0.5,
        0,
      );
      expectPoint(
        mapper.toNormalized(tapX: 200, tapY: 550, layout: tallBox),
        0.5,
        1,
      );
    });

    test('a wide image in a wide box letterboxes on the sides instead', () {
      // A 1:1 image in a 2:1 box: bands left and right, image x ∈ [100, 300].
      final PreviewLayout wideBox = layout(
        width: 400,
        height: 200,
        aspect: 1,
        fit: PreviewFit.contain,
      );
      expect(mapper.toNormalized(tapX: 50, tapY: 100, layout: wideBox), isNull);
      expectPoint(
        mapper.toNormalized(tapX: 100, tapY: 100, layout: wideBox),
        0,
        0.5,
      );
      expectPoint(
        mapper.toNormalized(tapX: 300, tapY: 100, layout: wideBox),
        1,
        0.5,
      );
    });

    test(
      'the same tap gives different answers under different aspect ratios',
      () {
        // The proof that the aspect ratio is actually load-bearing rather than
        // decorative — the whole point of FLT-CAM-008.
        final NormalizedPoint? fourThree = mapper.toNormalized(
          tapX: 200,
          tapY: 300,
          layout: layout(
            width: 400,
            height: 800,
            aspect: 4 / 3,
            fit: PreviewFit.contain,
          ),
        );
        final NormalizedPoint? sixteenNine = mapper.toNormalized(
          tapX: 200,
          tapY: 300,
          layout: layout(
            width: 400,
            height: 800,
            aspect: 16 / 9,
            fit: PreviewFit.contain,
          ),
        );
        expect(fourThree, isNotNull);
        expect(sixteenNine, isNotNull);
        expect(fourThree!.y, isNot(closeTo(sixteenNine!.y, 1e-3)));
      },
    );
  });

  group('cover — the full-bleed viewfinder', () {
    // A 4:3 image filling a tall box: the image overflows top and bottom, so
    // part of the picture is never visible.
    final PreviewLayout tallBox = layout(
      width: 400,
      height: 800,
      aspect: 4 / 3,
    );

    test('every tap inside the box lands on image', () {
      expect(mapper.toNormalized(tapX: 5, tapY: 5, layout: tallBox), isNotNull);
      expect(
        mapper.toNormalized(tapX: 395, tapY: 795, layout: tallBox),
        isNotNull,
      );
    });

    test('the centre still maps to the centre', () {
      expectPoint(
        mapper.toNormalized(tapX: 200, tapY: 400, layout: tallBox),
        0.5,
        0.5,
      );
    });

    test('the cropped-away margin is accounted for, not ignored', () {
      // Drawn height is 400·(3/4)... no: under cover the image is scaled to fill
      // the *height*, so drawn width is 800·(4/3) ≈ 1066.7 and the horizontal
      // overflow is (400-1066.7)/2 = -333.3 per side.
      final NormalizedPoint? left = mapper.toNormalized(
        tapX: 0,
        tapY: 400,
        layout: tallBox,
      );
      expect(left, isNotNull);
      expect(
        left!.x,
        closeTo(333.333333 / 1066.666667, 1e-4),
        reason:
            'a tap at the visible left edge is a third of the way into the '
            'image, not at its edge',
      );
      expect(left.x, greaterThan(0.3));
    });

    test('the vertical axis is untouched when the crop is horizontal', () {
      expectPoint(
        mapper.toNormalized(tapX: 200, tapY: 0, layout: tallBox),
        0.5,
        0,
      );
      expectPoint(
        mapper.toNormalized(tapX: 200, tapY: 800, layout: tallBox),
        0.5,
        1,
      );
    });

    test('an image taller than its box crops top and bottom instead', () {
      // A 1:2 portrait image in a square box: filling the width makes it 800
      // tall, so a quarter of the picture is hidden above the top edge.
      final PreviewLayout squareBox = layout(
        width: 400,
        height: 400,
        aspect: 0.5,
      );
      final NormalizedPoint? top = mapper.toNormalized(
        tapX: 200,
        tapY: 0,
        layout: squareBox,
      );
      expect(top, isNotNull);
      expect(top!.x, closeTo(0.5, 1e-6));
      expect(top.y, closeTo(0.25, 1e-6));
    });

    test('the result is always inside 0–1', () {
      for (final double aspect in <double>[0.5, 4 / 3, 16 / 9, 3]) {
        for (final double x in <double>[0, 137, 400]) {
          for (final double y in <double>[0, 421, 800]) {
            final NormalizedPoint? point = mapper.toNormalized(
              tapX: x,
              tapY: y,
              layout: layout(width: 400, height: 800, aspect: aspect),
            );
            expect(point, isNotNull);
            expect(point!.x, inInclusiveRange(0, 1));
            expect(point.y, inInclusiveRange(0, 1));
          }
        }
      }
    });
  });

  group('inputs that cannot be mapped', () {
    final PreviewLayout usable = layout(width: 400, height: 800, aspect: 4 / 3);

    test('a tap outside the widget is rejected', () {
      expect(mapper.toNormalized(tapX: -1, tapY: 400, layout: usable), isNull);
      expect(mapper.toNormalized(tapX: 401, tapY: 400, layout: usable), isNull);
      expect(mapper.toNormalized(tapX: 200, tapY: -1, layout: usable), isNull);
      expect(mapper.toNormalized(tapX: 200, tapY: 801, layout: usable), isNull);
    });

    test('a zero-sized box has no image to map onto', () {
      expect(
        mapper.toNormalized(
          tapX: 0,
          tapY: 0,
          layout: layout(width: 0, height: 800, aspect: 1),
        ),
        isNull,
      );
      expect(
        mapper.toNormalized(
          tapX: 0,
          tapY: 0,
          layout: layout(width: 400, height: 0, aspect: 1),
        ),
        isNull,
      );
    });

    test('an unreported aspect ratio is not guessed at', () {
      expect(
        mapper.toNormalized(
          tapX: 200,
          tapY: 400,
          layout: layout(width: 400, height: 800, aspect: 0),
        ),
        isNull,
      );
      expect(
        mapper.toNormalized(
          tapX: 200,
          tapY: 400,
          layout: layout(width: 400, height: 800, aspect: double.nan),
        ),
        isNull,
      );
    });

    test('a non-finite tap is rejected', () {
      expect(
        mapper.toNormalized(tapX: double.nan, tapY: 400, layout: usable),
        isNull,
      );
    });
  });

  group('NormalizedPoint', () {
    test('clamps rather than throwing on an out-of-range construction', () {
      expect(NormalizedPoint(-0.2, 1.7).x, 0);
      expect(NormalizedPoint(-0.2, 1.7).y, 1);
    });

    test('a non-finite component falls back to the centre of that axis', () {
      expect(NormalizedPoint(double.nan, 0.25).x, 0.5);
    });
  });
}
