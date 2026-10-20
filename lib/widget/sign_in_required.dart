// lib/widget/sign_in_required.dart
//
// "Sign in to continue" — the answer to every tap in the preview that would
// need an account.
//
// The preview exists so a visitor can see what the app does. The moment they
// want it to do something for *them* — answer a question, open their course,
// keep a bookmark — there has to be an account to do it to.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../core/theam /app_color.dart';
import '../view/Authendication/login/login_screen.dart';

Future<void> showSignInRequired(BuildContext context, {String? what}) async {
  final signIn = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: const Color(0xFFEDF6D8),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22.r)),
      icon: Icon(Icons.person_outline_rounded,
          size: 30.sp, color: AppColor.buttoncolor),
      title: Text(
        'Sign in to continue',
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: 17.sp, fontWeight: FontWeight.w800, color: Colors.black87),
      ),
      content: Text(
        what == null
            ? 'You are looking at a sample. Sign in to open your own course, '
                'with your lessons, tests and progress.'
            : 'Sign in to $what. What you are seeing now is a sample of the '
                'app.',
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
          child: Text('Keep looking',
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
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22.r)),
          ),
          child: Text('Sign in',
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );

  if (signIn == true && context.mounted) {
    // Pushed, not replaced: the gate swaps the whole tree the moment a
    // session lands, and a visitor who changes their mind comes back here.
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }
}
