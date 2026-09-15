// lib/view/splash/animated_splash.dart
//
// What the app opens on, every launch.
//
// Held for a fixed two seconds on every launch, WhatsApp-style: the mark
// centred, the wordmark sitting at the foot of the screen.
//
// Deliberately a floor rather than a wait on anything. With the course tree
// and session restored from disk, AuthGate resolves in milliseconds — the
// splash was gone before it could be seen, which is why it needed a hold to
// exist at all.
//
// The mark settles in, the wordmark follows a beat later. Two staggered
// curves off one controller, because two controllers drift.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theam /app_color.dart';
import '../../widget/app_logo.dart';

class AnimatedSplash extends StatefulWidget {
  /// What is happening underneath. Null hides the line entirely — on a fast
  /// launch there is nothing worth saying.
  final String? message;

  const AnimatedSplash({super.key, this.message});

  /// How long every launch shows this.
  ///
  /// A brand moment, not a data wait — which is why it is a fixed hold and
  /// not tied to anything finishing.
  static const Duration hold = Duration(seconds: 2);

  /// The mark's scale transition, for tests.
  static const Key markKey = Key('splash-mark');

  @override
  State<AnimatedSplash> createState() => _AnimatedSplashState();
}

class _AnimatedSplashState extends State<AnimatedSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    // Fills most of the hold, so the mark is still settling rather than
    // sitting dead for a second and a half.
    duration: const Duration(milliseconds: 1400),
  )..forward();

  /// The mark: up from slightly small, settling rather than bouncing.
  late final Animation<double> _markScale = Tween<double>(begin: 0.82, end: 1)
      .animate(CurvedAnimation(
          parent: _controller,
          curve: const Interval(0, 0.7, curve: Curves.easeOutBack)));

  late final Animation<double> _markFade = CurvedAnimation(
      parent: _controller, curve: const Interval(0, 0.45, curve: Curves.easeOut));

  /// The wordmark, a beat behind, rising a little as it arrives.
  late final Animation<double> _textFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 1, curve: Curves.easeOut));

  late final Animation<Offset> _textRise = Tween<Offset>(
    begin: const Offset(0, 0.35),
    end: Offset.zero,
  ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 1, curve: Curves.easeOutCubic)));

  @override
  void dispose() {
    // Outlives a frame, so it has to go or the ticker keeps running after the
    // splash is swapped out — and trips the test binding's timer check.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.Screenbackground,
      body: SafeArea(
        child: Stack(
          children: [
            // The mark owns the middle of the screen.
            Center(
              child: FadeTransition(
                opacity: _markFade,
                child: ScaleTransition(
                  // Named so a test can point at this one: route transitions
                  // contribute ScaleTransitions of their own.
                  key: AnimatedSplash.markKey,
                  scale: _markScale,
                  child: AppLogo(size: 150.w),
                ),
              ),
            ),

            // The wordmark sits at the foot, out of the mark's way.
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: 44.h),
                child: FadeTransition(
                  opacity: _textFade,
                  child: SlideTransition(
                    position: _textRise,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Dr. SKM's Academy",
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColor.Textcolor,
                            letterSpacing: 0.3,
                          ),
                        ),
                        if (widget.message != null) ...[
                          SizedBox(height: 8.h),
                          Text(
                            widget.message!,
                            style: TextStyle(
                                fontSize: 12.sp, color: Colors.grey.shade600),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
