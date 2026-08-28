// lib/widget/pro_plan_dialog.dart
//
// The single paywall used everywhere a locked lesson is opened: PRO badge,
// the ask, "View Plan" → the plans screen, "Go back". Rendered full-screen —
// video lessons and quizzes both hand the whole screen over to it, so a
// student sees the same paywall whichever kind of locked lesson they open.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../core/theam /app_color.dart';
import '../repository/selection_content_provider.dart';
import '../view/Home/profile/plans_screen.dart';

/// Opens the plans screen for the student's selected course.
/// Returns true when they came back subscribed.
Future<bool> openPlans(BuildContext context) async {
  final course = context.read<SelectionContentProvider>().content?.course;
  if (course == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Select a course first to see its plans.')),
    );
    return false;
  }

  final subscribed = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => PlansScreen(courseId: course.id, courseTitle: course.title),
    ),
  );
  return subscribed == true;
}

/// The card body: PRO badge, the ask, and the two buttons. Every paywall in
/// the app is this one widget, so they can't drift apart.
class ProPlanPrompt extends StatelessWidget {
  final String message;
  final VoidCallback onViewPlan;
  final VoidCallback onGoBack;

  const ProPlanPrompt({
    super.key,
    required this.message,
    required this.onViewPlan,
    required this.onGoBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── PRO badge ──
        Container(
          padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 8.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24.r),
            gradient: const LinearGradient(
              colors: [Color(0xFF7BB8F5), Color(0xFF3B87E8)],
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.diamond_rounded, size: 18.sp, color: Colors.white),
              SizedBox(width: 8.w),
              Text(
                'PRO',
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 20.h),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17.sp,
            fontWeight: FontWeight.w500,
            color: AppColor.Textcolor,
            height: 1.35,
          ),
        ),
        SizedBox(height: 22.h),
        SizedBox(
          width: double.infinity,
          height: 54.h,
          child: ElevatedButton(
            onPressed: onViewPlan,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColor.buttoncolor,
              foregroundColor: AppColor.Buttontextcolor,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
            ),
            child: Text('View Plan', style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w600)),
          ),
        ),
        SizedBox(height: 12.h),
        SizedBox(
          width: double.infinity,
          height: 54.h,
          child: OutlinedButton(
            onPressed: onGoBack,
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColor.Textcolor,
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
            ),
            child: Text('Go back', style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w500)),
          ),
        ),
      ],
    );
  }
}

/// The card centred on a full screen. Used by every locked lesson — quiz or
/// video — because there is nothing behind the paywall worth showing: the
/// server strips the video URL and the questions from a locked lesson.
class ProPlanPaywall extends StatelessWidget {
  final String message;

  /// Called after a successful subscribe, so the screen can reload itself.
  final VoidCallback? onSubscribed;

  const ProPlanPaywall({super.key, required this.message, this.onSubscribed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
        child: Container(
          padding: EdgeInsets.fromLTRB(20.w, 28.h, 20.w, 22.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28.r),
          ),
          child: ProPlanPrompt(
            message: message,
            onViewPlan: () async {
              final subscribed = await openPlans(context);
              if (subscribed) onSubscribed?.call();
            },
            onGoBack: () => Navigator.maybePop(context),
          ),
        ),
      ),
    );
  }
}
