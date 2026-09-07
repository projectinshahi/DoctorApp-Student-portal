// lib/widget/app_loading.dart
//
// The app's one loading state.
//
// This replaced a shimmer kit — five hand-drawn page skeletons plus inline
// grey blocks at every call site. Skeletons have to be redrawn whenever the
// screen behind them changes, and when they drift they read as a broken
// layout rather than as a wait. A spinner cannot drift.
//
// Sized to the space it is given: pass `height` inside a card or a list,
// leave it null to fill a Scaffold body or an Expanded.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../core/theam /app_color.dart';

class AppLoading extends StatelessWidget {
  /// Fixed height for an inline slot — a card, a row, a comment list. Null
  /// fills whatever bounded space the parent hands down.
  final double? height;

  /// Optional line under the spinner. Worth setting only where the wait has
  /// a name the student would recognise.
  final String? message;

  /// Defaults to the app's green. The video player and the PDF sheet load
  /// over dark backdrops and pass white.
  final Color? color;

  const AppLoading({super.key, this.height, this.message, this.color});

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColor.buttoncolor;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 30.w,
              height: 30.w,
              child: CircularProgressIndicator(
                strokeWidth: 2.6,
                valueColor: AlwaysStoppedAnimation<Color>(tint),
                backgroundColor: tint.withValues(alpha: 0.16),
              ),
            ),
            if (message != null) ...[
              SizedBox(height: 12.h),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5.sp,
                  color: color == null ? Colors.grey.shade700 : Colors.white70,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
