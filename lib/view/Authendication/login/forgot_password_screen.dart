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

/// Reset a forgotten password, or add one to a Google account: the email
/// gets a 6-digit code, and the code plus a new password signs straight in.
class ForgotPasswordScreen extends StatefulWidget {
  /// Whatever was typed on the login screen, so it need not be typed twice.
  final String email;

  const ForgotPasswordScreen({super.key, this.email = ''});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  /// The server ignores a second request inside a minute, so the button waits too.
  static const int _resendSeconds = 60;

  late final _emailController = TextEditingController(text: widget.email);
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  bool _codeSent = false;
  bool _busy = false;
  bool _signingIn = false;
  String? _error;
  Timer? _timer;
  int _secondsLeft = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
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

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    await context.read<GoogleSignInIntergration>().forgotPassword(email);
    if (!mounted) return;
    _codeController.clear();
    setState(() {
      _busy = false;
      _codeSent = true;
    });
    _startTimer();
  }

  Future<void> _reset() async {
    final code = _codeController.text.trim();
    final password = _passwordController.text;
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code from the email.');
      return;
    }
    if (password.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }

    final viewModel = context.read<GoogleSignInIntergration>();
    setState(() {
      _busy = _signingIn = true;
      _error = null;
    });

    final success = await viewModel.resetPassword(
        _emailController.text.trim(), code, password);
    if (!mounted) return;

    final result = viewModel.authResult;
    if (!success || result == null) {
      setState(() {
        _busy = _signingIn = false;
        _error = viewModel.refusal?.message ??
            viewModel.errorMessage ??
            'Could not reset the password. Please try again.';
      });
      return;
    }

    // As after any sign-in: AuthGate watches AuthProvider and takes over.
    await context.read<AuthProvider>().adoptSession(result);
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffix,
    List<TextInputFormatter>? formatters,
    bool enabled = true,
  }) {
    return Container(
      width: double.infinity,
      height: 60.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.r),
        color: AppColor.Screenbackground,
        border: Border.all(color: Colors.grey, width: 1),
      ),
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      alignment: Alignment.centerLeft,
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        obscureText: obscure,
        autocorrect: false,
        inputFormatters: formatters,
        style: TextStyle(fontSize: 16.sp),
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          isCollapsed: true,
          suffixIcon: suffix,
        ),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
      ),
    );
  }

  Widget _button(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: _busy ? null : onTap,
      child: Container(
        width: double.infinity,
        height: 60.h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.r),
          color: AppColor.buttoncolor,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: AppColor.Buttontextcolor,
            fontWeight: FontWeight.w500,
            fontSize: 18.sp,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canResend = _secondsLeft <= 0 && !_busy;

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
                    'Forgot password',
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColor.Textcolor,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    _codeSent
                        ? 'If an account exists for ${_emailController.text.trim()}, we sent it a 6-digit code. Enter it with your new password.'
                        : 'Enter your email and we will send you a code to set a new password.',
                    style: TextStyle(fontSize: 15.sp, color: AppColor.Textcolor),
                  ),
                  SizedBox(height: 32.h),

                  _field(
                    controller: _emailController,
                    hint: 'Enter your Email',
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_codeSent,
                  ),

                  if (_codeSent) ...[
                    SizedBox(height: AppSize.gap.h),
                    _field(
                      controller: _codeController,
                      hint: '6-digit code',
                      keyboardType: TextInputType.number,
                      formatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                    ),
                    SizedBox(height: AppSize.gap.h),
                    _field(
                      controller: _passwordController,
                      hint: 'New password (8+ characters)',
                      obscure: _obscurePassword,
                      suffix: IconButton(
                        icon: Icon(_obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ],

                  if (_error != null) ...[
                    SizedBox(height: 8.h),
                    Text(
                      _error!,
                      style: TextStyle(fontSize: 14.sp, color: Colors.red.shade700),
                    ),
                  ],

                  SizedBox(height: AppSize.gap.h),
                  _codeSent
                      ? _button('Reset password', _reset)
                      : _button('Send code', _sendCode),

                  if (_codeSent) ...[
                    SizedBox(height: 20.h),
                    Center(
                      child: TextButton(
                        onPressed: canResend ? _sendCode : null,
                        child: Text(
                          canResend ? 'Resend code' : 'Resend code in ${_secondsLeft}s',
                          style: TextStyle(
                            fontSize: 15.sp,
                            color: canResend ? AppColor.Textcolor : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                  _codeSent = false;
                                  _error = null;
                                }),
                        child: Text(
                          'Use a different email',
                          style: TextStyle(fontSize: 15.sp, color: AppColor.Textcolor),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (_signingIn) const AppLoadingScreen(message: 'Signing you in…'),
      ],
    );
  }
}
