import 'package:flutter/material.dart';

import '../../../domain/entities/focus_request.dart';
import '../../theme/app_motion.dart';
import '../../theme/camera_palette.dart';

/// The emerald ring that appears exactly where the user tapped
/// (`FLT-CAM-009`, `FLT-CAM-010`).
///
/// **It is positioned by the caller in widget coordinates, not by the normalised
/// point.** The normalised point is what the *camera* was told; round-tripping
/// it back through the preview geometry to place a ring would put the ring a few
/// pixels from the finger under `PreviewFit.cover`, which is precisely the class
/// of bug the two coordinate spaces exist to keep apart.
///
/// The lifecycle is its own — appear, acquire, settle, hold, fade — and it runs
/// from a [Key] on the request sequence, so a second tap at the same coordinates
/// starts a new reticle rather than reusing a ring that is already fading out.
///
/// **Reduced motion removes the movement, not the ring** (`RU-03`). With
/// animation disabled it appears instantly at full size, holds longer, and
/// disappears. The user still learns where the camera was told to look.
class FocusReticle extends StatefulWidget {
  /// Creates a reticle for [request].
  const FocusReticle({required this.request, super.key});

  /// The request being visualised, including how it resolved.
  final FocusRequest request;

  /// The ring's diameter in logical pixels.
  static const double diameter = 72;

  @override
  State<FocusReticle> createState() => _FocusReticleState();
}

class _FocusReticleState extends State<FocusReticle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.quick,
  );

  @override
  void initState() {
    super.initState();
    _controller.value = 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Read here rather than in `initState` because it needs the MediaQuery.
    _controller.duration = AppMotion.resolve(context, AppMotion.quick);
    if (_controller.duration == Duration.zero) {
      _controller.value = 1;
    } else if (!_controller.isAnimating && _controller.value == 1) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final FocusOutcome outcome = widget.request.outcome;
    final bool reduced = AppMotion.isReduced(context);

    return IgnorePointer(
      child: Semantics(
        // The reticle is feedback, not a control. It is labelled so a screen
        // reader user learns the tap landed, and it takes no focus of its own.
        label: _semanticLabel(outcome),
        liveRegion: true,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) {
            final double t = _controller.value;
            // 1.15 → 1.00. No overshoot: a spring here would read as playful,
            // and this is a record-keeping tool (`UX_SPEC.md` §7.1).
            final double scale = reduced ? 1 : 1.15 - (0.15 * t);
            return Opacity(
              opacity: reduced ? 1 : t,
              child: Transform.scale(scale: scale, child: child),
            );
          },
          child: _Ring(outcome: outcome),
        ),
      ),
    );
  }

  static String _semanticLabel(FocusOutcome outcome) {
    switch (outcome) {
      case FocusOutcome.pending:
        return 'Focusing';
      case FocusOutcome.applied:
        return 'Focus set';
      case FocusOutcome.unsupported:
        return 'This camera focuses automatically';
      case FocusOutcome.failed:
        return 'Could not focus there';
    }
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.outcome});

  final FocusOutcome outcome;

  @override
  Widget build(BuildContext context) {
    // A failed or unsupported focus is shown in the neutral control colour
    // rather than in an error colour. Nothing is broken — the camera is still
    // live, and painting the ring red would say otherwise (`§24`).
    final Color color = switch (outcome) {
      FocusOutcome.pending || FocusOutcome.applied => CameraPalette.accent,
      FocusOutcome.unsupported || FocusOutcome.failed => CameraPalette.control,
    };
    // Settled rings thin out; the acquiring ring stays substantial.
    final double width = outcome == FocusOutcome.pending ? 2.4 : 1.6;

    return SizedBox(
      width: FocusReticle.diameter,
      height: FocusReticle.diameter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: width),
        ),
        child: Center(
          child: SizedBox(
            width: 6,
            height: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
          ),
        ),
      ),
    );
  }
}
