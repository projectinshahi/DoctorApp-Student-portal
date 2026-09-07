// lib/widget/app_loading_screen.dart
//
// The screen a student looks at while the app is working out where to send
// them — after signing in, and on a cold start with a saved token.
//
// Not the plain AppLoading spinner used elsewhere: this one is the whole
// screen with nothing behind it, so it carries the mark and a line of text
// saying what is actually happening.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

const Color _kPrimary = Color(0xFF87986B);
const Color _kBg = Color(0xFFEFF4E2);
const Color _kInk = Color(0xFF1F2418);

class AppLoadingScreen extends StatefulWidget {
  /// What is being waited on. Kept short and concrete — "Signing you in",
  /// "Loading your course" — so a wait of a few seconds is explained rather
  /// than merely decorated.
  final String message;

  const AppLoadingScreen({super.key, this.message = 'Just a moment…'});

  @override
  State<AppLoadingScreen> createState() => _AppLoadingScreenState();
}

class _AppLoadingScreenState extends State<AppLoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  late final Animation<double> _pulse = Tween<double>(begin: 0.94, end: 1.06)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    // The controller outlives a frame, so it has to be disposed or the ticker
    // keeps running after the screen is swapped out.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The mark, breathing. Motion is what separates "working" from
              // "frozen" when the network is slow.
              ScaleTransition(
                scale: _pulse,
                child: Container(
                  width: 110.w,
                  height: 110.w,
                  decoration: BoxDecoration(
                    color: _kPrimary,
                    borderRadius: BorderRadius.circular(26.r),
                  ),
                ),
              ),
              SizedBox(height: 26.h),
              Text(
                "Dr. SKM's Academy",
                style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w800,
                    color: _kInk),
              ),
              SizedBox(height: 34.h),
              SizedBox(
                width: 26.w,
                height: 26.w,
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  valueColor: const AlwaysStoppedAnimation<Color>(_kPrimary),
                  backgroundColor: _kPrimary.withValues(alpha: 0.18),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13.sp,
                    height: 1.4,
                    color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
