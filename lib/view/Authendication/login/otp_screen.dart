import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../core/constant/app_size.dart';
import '../../../core/theam /app_color.dart';
import '../../../repository/google_sign_in_provider.dart';
import '../../../repository/refresh_api_provider.dart';
import '../../../widget/app_loading_screen.dart';
import '../../../widget/login_refused_dialog.dart';

/// The 6-digit code emailed at signup, or at every email login when
/// [isLogin]. The right code signs the student straight in.
class OtpScreen extends StatefulWidget {
  final String email;

  /// The second step of an email login rather than of a sign-up.
  final bool isLogin;

  /// Login only. Resending a login code is the login call again, so it is
  /// held here for that and never stored.
  final String? password;

  const OtpScreen({
    super.key,
    required this.email,
    this.isLogin = false,
    this.password,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  /// The server ignores a resend inside a minute, so the button waits too.
  static const int _resendSeconds = 60;

  final _codeController = TextEditingController();
  Timer? _timer;
  int _secondsLeft = _resendSeconds;
  bool _verifying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // A code was sent just before this screen opened.
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) t.cancel();
    });
  }

  Future<void> _resend() async {
    final viewModel = context.read<GoogleSignInIntergration>();
    if (widget.isLogin) {
      await viewModel.loginWithEmail(widget.email, widget.password!);
    } else {
      await viewModel.resendOtp(widget.email);
    }
    if (!mounted) return;
    _codeController.clear();
    setState(() => _error = null);
    _startTimer();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('A new code is on its way.')),
    );
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code from the email.');
      return;
    }

    final viewModel = context.read<GoogleSignInIntergration>();
    setState(() {
      _verifying = true;
      _error = null;
    });

    final success = widget.isLogin
        ? await viewModel.verifyLoginOtp(widget.email, code)
        : await viewModel.verifyOtp(widget.email, code);
    if (!mounted) return;

    final result = viewModel.authResult;
    final refusal = viewModel.refusal;
    if (!success &&
        refusal != null &&
        (refusal.isSessionActiveElsewhere || refusal.isAccountBlocked)) {
      // Not about the code: the same sheet a refused login shows.
      setState(() => _verifying = false);
      await showLoginRefusedDialog(context, refusal);
      return;
    }
    if (!success || result == null) {
      // A dead code needs a new one now, not in a minute.
      if (refusal?.code == 'OTP_EXPIRED' || refusal?.code == 'OTP_LOCKED') {
        _timer?.cancel();
        _secondsLeft = 0;
      }
      // Wrong, expired or locked: each message says what to do next, and
      // this screen is where they do it.
      setState(() {
        _verifying = false;
        _error = viewModel.refusal?.message ??
            viewModel.errorMessage ??
            'Could not verify the code. Please try again.';
      });
      return;
    }

    // As after Google sign-in: AuthGate watches AuthProvider and swaps its
    // own root — to the course picker, since this account is new.
    await context.read<AuthProvider>().adoptSession(result);
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final canResend = _secondsLeft <= 0 && !_verifying;

    return Stack(
      fit: StackFit.expand,
      children: [
        Scaffold(
          backgroundColor: AppColor.Screenbackground,
          appBar: AppBar(
            backgroundColor: AppColor.Screenbackground,
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Image.asset(
                'asset/icons/Backarrow.png',
                width: AppSize.iconBackArrowWidth,
                height: AppSize.iconBackArrowHeight,
              ),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: AppSize.screenHorizontal.w,
                vertical: AppSize.screenVertical.h,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isLogin ? 'Enter your login code' : 'Verify your email',
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColor.Textcolor,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text.rich(
                    TextSpan(
                      text: widget.isLogin
                          ? 'We sent a 6-digit code to\n'
                          : 'Enter the 6-digit code we sent to\n',
                      children: [
                        TextSpan(
                          text: widget.email,
                          style: TextStyle(
                              fontWeight: widget.isLogin
                                  ? FontWeight.w600
                                  : FontWeight.normal),
                        ),
                      ],
                    ),
                    style: TextStyle(fontSize: 15.sp, color: AppColor.Textcolor),
                  ),
                  if (widget.isLogin)
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size(0, 36.h),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      child: Text(
                        'Not you? Change email',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppColor.Textcolor,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  SizedBox(height: 32.h),

                  Container(
                    width: double.infinity,
                    height: 60.h,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12.r),
                      color: AppColor.Screenbackground,
                      border: Border.all(
                        color: _error == null ? Colors.grey : Colors.red.shade400,
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: TextField(
                      controller: _codeController,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 12,
                      ),
                      decoration: const InputDecoration(
                        hintText: '••••••',
                        border: InputBorder.none,
                        isCollapsed: true,
                        counterText: '',
                      ),
                      onChanged: (v) {
                        if (_error != null) setState(() => _error = null);
                        // All six typed or pasted: no need to reach for the button.
                        if (v.length == 6 && !_verifying) _verify();
                      },
                    ),
                  ),

                  if (_error != null) ...[
                    SizedBox(height: 8.h),
                    Text(
                      _error!,
                      style: TextStyle(fontSize: 14.sp, color: Colors.red.shade700),
                    ),
                  ],

                  SizedBox(height: AppSize.gap.h),

                  GestureDetector(
                    onTap: _verifying ? null : _verify,
                    child: Container(
                      width: double.infinity,
                      height: 60.h,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12.r),
                        color: AppColor.buttoncolor,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        widget.isLogin ? 'Verify and log in' : 'Verify',
                        style: TextStyle(
                          color: AppColor.Buttontextcolor,
                          fontWeight: FontWeight.w500,
                          fontSize: 18.sp,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 20.h),

                  Center(
                    child: TextButton(
                      onPressed: canResend ? _resend : null,
                      child: Text(
                        canResend
                            ? 'Resend code'
                            : 'Resend code in ${_secondsLeft}s',
                        style: TextStyle(
                          fontSize: 15.sp,
                          color: canResend ? AppColor.Textcolor : Colors.grey,
                        ),
                      ),
                    ),
                  ),

                  if (widget.isLogin) ...[
                    SizedBox(height: 12.h),
                    Text(
                      "The code expires in 10 minutes. Check your spam folder "
                      "if you don't see it.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13.sp, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (_verifying) const AppLoadingScreen(message: 'Signing you in…'),
      ],
    );
  }
}
