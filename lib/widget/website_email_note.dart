// lib/widget/website_email_note.dart
//
// "Use the email you registered with on the website."
//
// One wording, on every screen a student can sign in from. An account here is
// the website account — the plan is bought there — so signing in with a
// different address creates a second account with no plan attached, and the
// app then tells them their learning plan is not active.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../core/theam /app_color.dart';

class WebsiteEmailNote extends StatelessWidget {
  const WebsiteEmailNote({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
      decoration: BoxDecoration(
        color: AppColor.buttoncolor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 16.sp, color: AppColor.buttoncolor),
          SizedBox(width: 9.w),
          Expanded(
            child: Text(
              'Use the same email address you registered with on our '
              'website. Your plan is linked to it.',
              style: TextStyle(
                fontSize: 12.sp,
                height: 1.45,
                color: const Color(0xFF3D4A2C),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
