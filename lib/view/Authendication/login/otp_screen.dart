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

/// The 6-digit code emailed at signup. The right code verifies the account
/// and signs the student straight in.
class OtpScreen extends StatefulWidget {
  final String email;

  const OtpScreen({super.key, required this.email});

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
    await context.read<GoogleSignInIntergration>().resendOtp(widget.email);
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

    final success = await viewModel.verifyOtp(widget.email, code);
    if (!mounted) return;

    final result = viewModel.authResult;
    if (!success || result == null) {
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
                    'Verify your email',
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColor.Textcolor,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Enter the 6-digit code we sent to\n${widget.email}',
                    style: TextStyle(fontSize: 15.sp, color: AppColor.Textcolor),
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
                        'Verify',
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
