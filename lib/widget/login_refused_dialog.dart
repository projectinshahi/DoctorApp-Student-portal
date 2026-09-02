// lib/widget/login_refused_dialog.dart
//
// What a student sees when the server turns their login away.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../services/Auth_services.dart' show LoginRefusedException;

const Color _kPrimary = Color(0xFF87986B);
const Color _kBg = Color(0xFFEFF4E2);

/// Shows the server's reason, with wording matched to the code.
///
/// A refused login is not a failed tap: the student needs to know whether to
/// try again, contact support, or use a different phone. A generic "sign-in
/// failed" leaves them tapping a button that will never work.
Future<void> showLoginRefusedDialog(
  BuildContext context,
  LoginRefusedException refused,
) {
  final (icon, title, hint) = switch (refused) {
    // One person, several accounts, one phone — the subscription-sharing
    // case. There is nothing to retry; support has to release the device.
    _ when refused.isDeviceBound => (
        Icons.phonelink_lock_rounded,
        'This device is already registered',
        'Each device can be used with one account. If this phone is yours '
            'and you need it moved, contact support.',
      ),
    _ when refused.isAccountBlocked => (
        Icons.gpp_bad_outlined,
        'Account disabled',
        'Please contact support to have your account reviewed.',
      ),
    _ => (
        Icons.error_outline_rounded,
        'Could not sign in',
        null,
      ),
  };

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: _kBg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      icon: Icon(icon, size: 34.sp, color: _kPrimary),
      title: Text(title,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w800)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The server's own wording first — it knows the specifics.
          Text(refused.message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13.sp, height: 1.45, color: Colors.black87)),
          if (hint != null) ...[
            SizedBox(height: 10.h),
            Text(hint,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12.sp, height: 1.4, color: Colors.grey.shade700)),
          ],
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogContext),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kPrimary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 12.h),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
          ),
          child: Text('OK',
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}
