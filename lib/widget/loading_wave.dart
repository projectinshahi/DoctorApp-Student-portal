// lib/widget/loading_wave.dart
//
// The app's loading animation: a wave that travels down a screen's own shape.
//
// Not shimmer. Shimmer sweeps a highlight across grey blocks and reads as a
// page that half-rendered and then broke. This fills the blocks in order, in
// the layout the student is about to see, which says the page is being laid
// out — which is what is happening.
//
// One controller drives however many bars a screen asks for. Separate
// controllers per bar drift out of step and cost a ticker each.
import 'package:flutter/material.dart';

import '../core/theam /app_color.dart';

class LoadingWave extends StatefulWidget {
  /// How many steps the wave has. Pass the number of bars being drawn so the
  /// wave arrives at each in turn and starts over cleanly.
  final int steps;

  /// Builds the skeleton. `lift(i)` is 0 at rest and 1 at the peak of the
  /// wave for step `i` — feed it to [WaveBar].
  final Widget Function(BuildContext context, double Function(int) lift)
      builder;

  /// One full pass of the wave.
  ///
  /// Short enough to read as activity rather than as decoration. A long cycle
  /// makes a wait feel longer than it is, because each block sits lit for a
  /// noticeable beat.
  final Duration duration;

  const LoadingWave({
    super.key,
    required this.steps,
    required this.builder,
    this.duration = const Duration(milliseconds: 1100),
  });

  @override
  State<LoadingWave> createState() => _LoadingWaveState();
}

class _LoadingWaveState extends State<LoadingWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..repeat();

  @override
  void dispose() {
    // Outlives a frame, so it has to go — a leaked ticker animates a screen
    // nobody is looking at, and trips the test binding's timer check.
    _controller.dispose();
    super.dispose();
  }

  /// 0 → 1 → 0 for one step, offset so the wave travels.
  double _lift(int index) {
    final span = 1 / (widget.steps + 1);
    final start = index * span;
    final t = (_controller.value - start) % 1.0;
    if (t > span * 2) return 0;
    final phase = t / (span * 2);
    // Up then back down, so no bar snaps off.
    return phase < 0.5 ? phase * 2 : (1 - phase) * 2;
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => widget.builder(context, _lift),
      );
}

/// One block of a skeleton, brightening as the wave passes through it.
class WaveBar extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  /// 0 at rest, 1 at the peak. From [LoadingWave]'s `lift`.
  final double lift;

  const WaveBar({
    super.key,
    this.width,
    required this.height,
    required this.lift,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        // Barely tinted at rest, clearly the app's green at the peak.
        color: Color.lerp(
          Colors.black.withValues(alpha: 0.05),
          AppColor.buttoncolor.withValues(alpha: 0.28),
          lift,
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Three dots rising in turn, on the same wave as the page skeletons.
///
/// For a slot too small for a skeleton — a thumbnail, an image still on its
/// way. A spinner at that size is a smudge; dots read as "coming" at a glance.
class LoadingDots extends StatelessWidget {
  /// Diameter of one dot. Pass a scaled value (`8.w`): this file stays free of
  /// screenutil so the skeletons can be tested without it.
  final double size;

  const LoadingDots({super.key, this.size = 8});

  @override
  Widget build(BuildContext context) {
    return LoadingWave(
      steps: 3,
      // Quicker than a page skeleton: three dots on a long cycle look stalled.
      duration: const Duration(milliseconds: 900),
      builder: (context, lift) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: size * 0.35),
              child: Transform.translate(
                // A small hop with the brightening, so the wave reads even
                // where the colour change alone is hard to see.
                offset: Offset(0, -size * 0.6 * lift(i)),
                child: WaveBar(
                  width: size,
                  height: size,
                  radius: size / 2,
                  lift: lift(i),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
