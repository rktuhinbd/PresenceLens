// FLT-CAM-003, FLT-CAM-007.
//
// Pure arithmetic, so it is verified here rather than by pinching a phone and
// deciding it "felt right". The drift case in particular is invisible to
// inspection and obvious to a test.

import 'package:flutter_test/flutter_test.dart';
import 'package:presence_lens_capture/domain/entities/camera_capabilities.dart';
import 'package:presence_lens_capture/domain/policies/zoom_policy.dart';

void main() {
  const ZoomPolicy policy = ZoomPolicy();

  group('ZoomRange', () {
    test('keeps the minimum the device reported, even below 1', () {
      // The whole point of FLT-CAM-007: a device that says it can go to 0.5
      // must not be told its floor is 1.0.
      final ZoomRange range = ZoomRange(min: 0.5, max: 8);
      expect(range.min, 0.5);
      expect(range.supportsSubBaseline, isTrue);
    });

    test('a camera that cannot zoom is not adjustable', () {
      expect(ZoomRange.fixed.isAdjustable, isFalse);
      expect(ZoomRange.fixed.supportsSubBaseline, isFalse);
    });

    test(
      'a max below the min collapses to the min rather than inventing room',
      () {
        final ZoomRange range = ZoomRange(min: 2, max: 1);
        expect(range.min, 2);
        expect(range.max, 2);
      },
    );

    test('a non-finite or non-positive minimum falls back to 1', () {
      expect(ZoomRange(min: double.nan, max: 4).min, 1);
      expect(ZoomRange(min: 0, max: 4).min, 1);
      expect(ZoomRange(min: -3, max: 4).min, 1);
    });

    test('contains is inclusive at both ends', () {
      final ZoomRange range = ZoomRange(min: 0.6, max: 4);
      expect(range.contains(0.6), isTrue);
      expect(range.contains(4), isTrue);
      expect(range.contains(0.59), isFalse);
      expect(range.contains(4.01), isFalse);
    });
  });

  group('clamp', () {
    final ZoomRange range = ZoomRange(min: 0.5, max: 8);

    test('a value inside the range is untouched', () {
      expect(policy.clamp(3.25, range), 3.25);
    });

    test('below the minimum clamps to the minimum', () {
      expect(policy.clamp(0.1, range), 0.5);
    });

    test('above the maximum clamps to the maximum', () {
      expect(policy.clamp(99, range), 8);
    });

    test('clamps to a minimum that is not 1.0', () {
      final ZoomRange telephoto = ZoomRange(min: 2, max: 10);
      expect(policy.clamp(1, telephoto), 2);
    });

    test('a non-finite request resolves to the minimum, not a crash', () {
      expect(policy.clamp(double.nan, range), 0.5);
      expect(policy.clamp(double.infinity, range), 8);
    });
  });

  group('pinch', () {
    final ZoomRange range = ZoomRange(min: 0.5, max: 8);

    test('a scale of 1 leaves the zoom exactly where the gesture started', () {
      expect(policy.forPinch(baseline: 2, scale: 1, range: range), 2);
    });

    test('spreading the fingers zooms in proportionally', () {
      expect(policy.forPinch(baseline: 2, scale: 1.5, range: range), 3);
    });

    test('pinching in zooms out proportionally', () {
      expect(policy.forPinch(baseline: 4, scale: 0.5, range: range), 2);
    });

    test('clamps at the top', () {
      expect(policy.forPinch(baseline: 6, scale: 4, range: range), 8);
    });

    test('clamps at the bottom', () {
      expect(policy.forPinch(baseline: 1, scale: 0.01, range: range), 0.5);
    });

    test('a baseline outside the range is clamped before being scaled', () {
      // Guards against a stale baseline captured on a previous camera with a
      // wider range surviving a switch.
      expect(policy.forPinch(baseline: 40, scale: 1, range: range), 8);
    });

    test(
      'an impossible scale holds the baseline instead of inventing motion',
      () {
        expect(policy.forPinch(baseline: 3, scale: 0, range: range), 3);
        expect(policy.forPinch(baseline: 3, scale: -2, range: range), 3);
        expect(
          policy.forPinch(baseline: 3, scale: double.nan, range: range),
          3,
        );
      },
    );

    test('does NOT compound across a gesture — the drift bug', () {
      // The regression this exists for. A gesture reports a *cumulative* scale
      // from its own start. Feeding each frame back in as the next baseline —
      // 1.1 · 1.2 · 1.3 · 1.4 — would land at 2.4 instead of 1.4, and the zoom
      // would run away under the fingers and never come back.
      const double start = 1;
      double anchored = start;
      for (final double scale in <double>[1.1, 1.2, 1.3, 1.4]) {
        anchored = policy.forPinch(baseline: start, scale: scale, range: range);
      }
      expect(anchored, closeTo(1.4, 1e-9));

      double compounded = start;
      for (final double scale in <double>[1.1, 1.2, 1.3, 1.4]) {
        compounded = policy.forPinch(
          baseline: compounded,
          scale: scale,
          range: range,
        );
      }
      expect(compounded, greaterThan(2.4));
    });

    test('a gesture that returns to scale 1 returns to where it began', () {
      const double start = 2.5;
      final double out = policy.forPinch(
        baseline: start,
        scale: 2,
        range: range,
      );
      expect(out, 5);
      expect(policy.forPinch(baseline: start, scale: 1, range: range), start);
    });

    test('a second gesture anchors on where the first one ended', () {
      final double afterFirst = policy.forPinch(
        baseline: 1,
        scale: 2,
        range: range,
      );
      expect(afterFirst, 2);
      expect(policy.forPinch(baseline: afterFirst, scale: 2, range: range), 4);
    });
  });

  group('default zoom', () {
    test('opens at 1.0 when the camera can do it', () {
      expect(policy.defaultFor(ZoomRange(min: 0.5, max: 8)), 1);
    });

    test('a camera whose range starts above 1 opens at its own minimum', () {
      expect(policy.defaultFor(ZoomRange(min: 2, max: 10)), 2);
    });

    test('a fixed camera opens at its only value', () {
      expect(policy.defaultFor(ZoomRange.fixed), 1);
    });
  });
}
