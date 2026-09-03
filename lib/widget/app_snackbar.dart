// lib/widget/app_snackbar.dart
//
// One definition for every in-app message, so a success and a failure cannot
// drift into looking alike — or into looking like the OS.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

const Color _kPrimary = Color(0xFF87986B);
const Color _kDanger = Color(0xFFB03A2B);

enum AppMessage { success, failure }

/// Shows a floating, app-coloured message.
///
/// Green for done, red for failed. The default SnackBar is near-black and
/// square-cornered, which reads as a system toast rather than as this app
/// answering the tap the student just made.
void showAppSnackBar(
  BuildContext context,
  String text, {
  AppMessage kind = AppMessage.success,
}) {
  final success = kind == AppMessage.success;

  ScaffoldMessenger.of(context)
    // Otherwise a queued message from the previous tap shows after this one.
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
                success
                    ? Icons.check_circle_rounded
                    : Icons.error_outline_rounded,
                size: 18.sp,
                color: Colors.white),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(text,
                  style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: success ? _kPrimary : _kDanger,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: success ? 2 : 3),
      ),
    );
}
