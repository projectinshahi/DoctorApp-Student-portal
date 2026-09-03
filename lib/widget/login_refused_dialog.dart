// lib/widget/login_refused_dialog.dart
//
// What a student sees when the server turns their login away.
//
// A bottom sheet rather than an AlertDialog. A refused login is not an error
// popup — it is an answer to the button they just pressed, and it usually
// asks them to go and do something on another phone. A sheet rising from the
// button gives that explanation room to breathe, and keeps the login screen
// visible behind it so it never feels like the app went wrong.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../services/Auth_services.dart' show LoginRefusedException;

const Color _kPrimary = Color(0xFF87986B);
const Color _kPrimaryDark = Color(0xFF6B7C51);
const Color _kBg = Color(0xFFEFF4E2);
const Color _kInk = Color(0xFF1F2418);

/// One refusal, in the words its code calls for.
class _Refusal {
  final IconData icon;
  final String title;
  final String body;

  /// The one concrete thing the student can do next, or null when there is
  /// nothing but waiting.
  final String? action;

  const _Refusal({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });
}

_Refusal _read(LoginRefusedException refused) {
  // The account is in use elsewhere and this login was refused rather than
  // the other device being kicked off. There is no force-sign-in flag in the
  // API, so the only honest options are: sign out there, or wait it out.
  if (refused.isSessionActiveElsewhere) {
    final minutes = refused.retryAfterMinutes;
    return _Refusal(
      icon: Icons.phonelink_lock_rounded,
      title: 'Already signed in',
      body: refused.message,
      action: minutes == null
          ? 'Sign out on your other device, then try again.'
          : 'Sign out on your other device — or wait about $minutes minutes '
              'and that session will be released on its own.',
    );
  }

  // One person, several accounts, one phone. Nothing to retry; support has
  // to release the device.
  if (refused.isDeviceBound) {
    return _Refusal(
      icon: Icons.smartphone_rounded,
      title: 'This device is registered',
      body: refused.message,
      action: 'Each device works with one account. If this phone is yours, '
          'contact support to move it.',
    );
  }

  if (refused.isAccountBlocked) {
    return _Refusal(
      icon: Icons.gpp_bad_outlined,
      title: 'Account disabled',
      body: refused.message,
      action: 'Please contact support to have your account reviewed.',
    );
  }

  return _Refusal(
    icon: Icons.error_outline_rounded,
    title: 'Could not sign in',
    body: refused.message,
  );
}

Future<void> showLoginRefusedDialog(
  BuildContext context,
  LoginRefusedException refused,
) {
  final r = _read(refused);

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    // Dismissible: unlike a session ending mid-lesson, nothing is lost by
    // closing this — the login screen is right behind it.
    isScrollControlled: true,
    builder: (sheetContext) => Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26.r)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: 22.h),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ),
              Container(
                width: 62.w,
                height: 62.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _kBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(r.icon, size: 28.sp, color: _kPrimary),
              ),
              SizedBox(height: 16.h),
              Text(r.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                      color: _kInk)),
              SizedBox(height: 8.h),
              // The server's own sentence, unchanged.
              Text(r.body,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13.sp,
                      height: 1.5,
                      color: Colors.grey.shade700)),
              if (r.action != null) ...[
                SizedBox(height: 18.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                      horizontal: 14.w, vertical: 13.h),
                  decoration: BoxDecoration(
                    color: _kBg,
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_outline_rounded,
                          size: 17.sp, color: _kPrimaryDark),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(r.action!,
                            style: TextStyle(
                                fontSize: 12.5.sp,
                                height: 1.45,
                                fontWeight: FontWeight.w600,
                                color: _kPrimaryDark)),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: 22.h),
              SizedBox(
                width: double.infinity,
                height: 50.h,
                // One button, and it only closes the sheet. Deliberately no
                // "try again" and no "sign in anyway": an immediate retry
                // fails identically, and the API has no override to offer.
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26.r)),
                  ),
                  child: Text('Got it',
                      style: TextStyle(
                          fontSize: 14.sp, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
