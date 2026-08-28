// lib/widget/app_shimmer.dart
//
// One shimmer kit for every full-screen load in the app. Spinners stay only
// where they belong — inside buttons and over the video player, where a
// skeleton would be nonsense.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

import '../core/theam /app_color.dart';

/// Which page skeleton to draw. Each one mirrors the real screen's layout so
/// nothing jumps when the content lands.
enum ShimmerLayout {
  rows,   // list screens: QBank topics, subjects, AI videos
  grid,   // home's lesson grid
  cards,  // plans screen
  quiz,   // question + options
  splash, // logo + wordmark
}

/// Wraps anything in the app's shimmer sweep.
class AppShimmer extends StatelessWidget {
  final Widget child;
  const AppShimmer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: child,
    );
  }
}

/// One grey placeholder block.
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const ShimmerBox({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Full-screen skeleton. Drop-in replacement for
/// `Center(child: CircularProgressIndicator())`.
class ScreenShimmer extends StatelessWidget {
  final ShimmerLayout layout;

  const ScreenShimmer({super.key, this.layout = ShimmerLayout.rows});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: switch (layout) {
        ShimmerLayout.rows => _rows(),
        ShimmerLayout.grid => _grid(),
        ShimmerLayout.cards => _cards(),
        ShimmerLayout.quiz => _quiz(),
        ShimmerLayout.splash => _splash(),
      },
    );
  }

  // ── List screens: a search bar, two shortcut cards, then row tiles ──
  Widget _rows() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(height: 50.h, radius: 30.r),
          SizedBox(height: 18.h),
          Row(
            children: [
              Expanded(child: ShimmerBox(height: 165.h, radius: 20.r)),
              SizedBox(width: 14.w),
              Expanded(child: ShimmerBox(height: 165.h, radius: 20.r)),
            ],
          ),
          SizedBox(height: 24.h),
          ShimmerBox(width: 90.w, height: 16.h),
          SizedBox(height: 12.h),
          for (var i = 0; i < 4; i++) ...[
            ShimmerBox(height: 76.h, radius: 20.r),
            SizedBox(height: 12.h),
          ],
        ],
      ),
    );
  }

  // ── Home's two-column lesson grid ──
  Widget _grid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemBuilder: (context, index) => ShimmerBox(height: 100.h, radius: 16.r),
    );
  }

  // ── Plans: one tall card and the two buttons under it ──
  Widget _cards() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 20.h),
      child: Column(
        children: [
          Expanded(child: ShimmerBox(height: double.infinity, radius: 24.r)),
          SizedBox(height: 18.h),
          ShimmerBox(height: 54.h, radius: 16.r),
          SizedBox(height: 12.h),
          ShimmerBox(height: 54.h, radius: 16.r),
        ],
      ),
    );
  }

  // ── Quiz: progress, question lines, four option pills, the button ──
  Widget _quiz() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 20.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShimmerBox(width: 60.w, height: 12.h),
              ShimmerBox(width: 90.w, height: 12.h),
            ],
          ),
          SizedBox(height: 8.h),
          ShimmerBox(height: 5.h, radius: 10.r),
          SizedBox(height: 22.h),
          ShimmerBox(height: 16.h),
          SizedBox(height: 8.h),
          ShimmerBox(width: 240.w, height: 16.h),
          SizedBox(height: 16.h),
          Row(
            children: [
              ShimmerBox(width: 76.w, height: 22.h, radius: 10.r),
              SizedBox(width: 8.w),
              ShimmerBox(width: 76.w, height: 22.h, radius: 10.r),
            ],
          ),
          SizedBox(height: 22.h),
          for (var i = 0; i < 4; i++) ...[
            ShimmerBox(height: 54.h, radius: 30.r),
            SizedBox(height: 12.h),
          ],
          const Spacer(),
          ShimmerBox(height: 50.h, radius: 30.r),
        ],
      ),
    );
  }

  // ── Splash: the logo tile and the wordmark ──
  Widget _splash() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShimmerBox(width: 150.w, height: 150.w, radius: 24.r),
          SizedBox(height: 20.h),
          ShimmerBox(width: 220.w, height: 26.h),
        ],
      ),
    );
  }
}
