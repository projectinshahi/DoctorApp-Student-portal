// lib/widget/home_loading.dart
//
// The home screen while it has nothing to draw yet.
//
// Only reachable on a genuinely cold start — a first launch, or the first one
// after signing out. Every launch after that restores the course tree from
// disk and paints real content, so this is the rarest loading state in the
// app and also the first thing a new student ever sees.
//
// It mirrors the home screen's own blocks: the green header with its search
// bar, the welcome card, the MCQ card, then the pair of Continue Learning
// cards. The page fills in where it is going to be rather than appearing from
// behind a spinner.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../core/theam /app_color.dart';
import 'loading_wave.dart';

class HomeLoading extends StatelessWidget {
  const HomeLoading({super.key});

  /// Header, welcome card, MCQ card, then the two side-by-side cards.
  static const int _blocks = 5;

  @override
  Widget build(BuildContext context) {
    return LoadingWave(
      steps: _blocks,
      builder: (context, lift) => SingleChildScrollView(
        // The real page scrolls; this must not bounce differently.
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── The green header, drawn solid: it is the one part of this
            // screen that never depends on the network, so faking it as a
            // grey block would look like a step backwards. ──
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(20.w, 60.h, 20.w, 22.h),
              decoration: BoxDecoration(
                color: AppColor.buttoncolor,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28.r),
                  bottomRight: Radius.circular(28.r),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WaveBar(
                    width: 120.w,
                    height: 15.h,
                    radius: 8.r,
                    lift: lift(0),
                  ),
                  SizedBox(height: 18.h),
                  Container(
                    height: 46.h,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(26.r),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 22.h, 20.w, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome card — the real one is 165.h.
                  WaveBar(
                    width: double.infinity,
                    height: 165.h,
                    radius: 24.r,
                    lift: lift(1),
                  ),
                  SizedBox(height: 26.h),

                  WaveBar(
                    width: 130.w,
                    height: 14.h,
                    radius: 7.r,
                    lift: lift(2),
                  ),
                  SizedBox(height: 12.h),
                  // MCQ of the Day.
                  WaveBar(
                    width: double.infinity,
                    height: 190.h,
                    radius: 18.r,
                    lift: lift(2),
                  ),
                  SizedBox(height: 26.h),

                  WaveBar(
                    width: 160.w,
                    height: 14.h,
                    radius: 7.r,
                    lift: lift(3),
                  ),
                  SizedBox(height: 12.h),
                  // Continue Learning: two cards, side by side, 150.h each.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: WaveBar(
                          height: 150.h,
                          radius: 16.r,
                          lift: lift(3),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: WaveBar(
                          height: 150.h,
                          radius: 16.r,
                          lift: lift(4),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24.h),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
