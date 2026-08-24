// lib/widget/pro_plan_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../core/theam /app_color.dart';
import '../repository/selection_content_provider.dart';
import '../view/Home/profile/plans_screen.dart';

/// Paywall shown when a locked (pro-only) lesson is opened.
/// Returns true when the user came back from the plans screen subscribed.
Future<bool> showProPlanDialog(BuildContext context) async {
  final wantsPlans = await showDialog<bool>(
    context: context,
    builder: (_) => const _ProPlanDialog(),
  );

  if (wantsPlans != true || !context.mounted) return false;

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

class _ProPlanDialog extends StatelessWidget {
  const _ProPlanDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(horizontal: 24.w),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.r)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 28.h, 20.w, 22.h),
        child: Column(
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
              'This video is available for pro users of this course. '
              'Want to check Pro plans?',
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
                onPressed: () => Navigator.pop(context, true),
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
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColor.Textcolor,
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                ),
                child: Text('Go back', style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w500)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
