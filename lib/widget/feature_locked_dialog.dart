// lib/widget/feature_locked_dialog.dart
//
// "This is not part of your plan" — shown when a student taps a tab their
// plan's card does not mention.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../core/theam /app_color.dart';
import '../core/utils/website.dart';

/// Says what is missing and offers the plans. Dismissible, unlike the
/// learning-plan gate: everything else in the app still works.
Future<void> showFeatureLockedDialog(
  BuildContext context, {
  required String feature,
  String? planTitle,
}) async {
  final explore = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: const Color(0xFFEDF6D8),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22.r)),
      icon: Icon(Icons.lock_outline_rounded,
          size: 30.sp, color: AppColor.buttoncolor),
      title: Text(
        '$feature is not in your plan',
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: 17.sp, fontWeight: FontWeight.w800, color: Colors.black87),
      ),
      content: Text(
        planTitle == null || planTitle.isEmpty
            ? 'Your current plan does not include $feature. Plans are '
                'upgraded on our website.'
            : 'Your plan, $planTitle, does not include $feature. Plans are '
                'upgraded on our website.',
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: 13.sp,
            height: 1.5,
            color: Colors.black.withValues(alpha: 0.72)),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text('Not now',
              style: TextStyle(
                  fontSize: 13.sp, color: Colors.black.withValues(alpha: 0.6))),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColor.buttoncolor,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 12.h),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(22.r)),
          ),
          child: Text('See plans',
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );

  if (explore == true && context.mounted) await openWebsite(context);
}
