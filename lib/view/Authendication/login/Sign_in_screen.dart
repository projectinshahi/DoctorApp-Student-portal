import 'package:flutter/material.dart';


import '../../../widget/app_loading_screen.dart';

import '../../../repository/refresh_api_provider.dart';

import '../../../widget/login_refused_dialog.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../core/theam /app_color.dart';
import '../../../core/constant/app_size.dart';
import '../../../repository/google_sign_in_provider.dart';
import 'otp_screen.dart';
import 'forgot_password_screen.dart';

class SignInScreen extends StatefulWidget {
  /// Filled in when a sign-up was turned away because the account exists, so
  /// the student is not asked to type an address they just typed.
  final String? initialEmail;

  /// Why they were sent here, shown above the form.
  final String? notice;

  const SignInScreen({super.key, this.initialEmail, this.notice});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  /// Spans the whole sign-in, not just the HTTP call.
  ///
  /// `viewModel.isLoading` drops as soon as the 200 lands, but the session is
  /// not usable until AuthProvider has adopted it and, on a new device,
  /// resolved the course — so the button un-spun and sat there looking idle
  /// while work was still going on.
  bool _finishing = false;

  bool _obscurePassword = true;

  late final _emailController =
      TextEditingController(text: widget.initialEmail ?? '');
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _loginWithEmail(GoogleSignInIntergration viewModel) {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email and password.')),
      );
      return;
    }
    _signIn(viewModel, () => viewModel.loginWithEmail(email, password));
  }

  /// Shared by the Google and Apple buttons: the server's reply, and so
  /// everything after it, is the same for both.
  Future<void> _signIn(
    GoogleSignInIntergration viewModel,
    Future<bool> Function() signIn,
  ) async {
    setState(() => _finishing = true);
    final success = await signIn();

    if (!mounted) return;

    // A refusal stays on this screen and explains
    // itself, rather than falling through to the
    // generic failure snack bar below.
    final refused = viewModel.refusal;
    if (refused != null && refused.isEmailNotVerified) {
      // Signed up but never entered the code. A fresh one beats explaining
      // that the old one has probably expired.
      setState(() => _finishing = false);
      final email = _emailController.text.trim();
      await viewModel.resendOtp(email);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OtpScreen(email: email)),
      );
      return;
    }
    if (refused != null) {
      setState(() => _finishing = false);
      await showLoginRefusedDialog(context, refused);
      return;
    }

    if (success) {
      // Hand the session to AuthProvider, which is
      // what AuthGate watches. Without this the
      // tokens were stored but the gate still showed
      // the login screen until some later rebuild —
      // the flicker between signing in and landing on
      // home.
      final result = viewModel.authResult;
      if (result != null) {
        await context
            .read<AuthProvider>()
            .adoptSession(result);
      }
      if (!mounted) return;
      setState(() => _finishing = false);

      // No "Welcome back" toast, and no navigation.
      // The home screen already greets them by name,
      // and AuthGate swaps its own root — to the
      // course picker for a new account, to home
      // otherwise. pushReplacement here removed
      // AuthGate, and with it the session watcher.
      Navigator.of(context).popUntil((r) => r.isFirst);
    } else {
      // Without this the button stays disabled after
      // a failed attempt and the student cannot try
      // again.
      setState(() => _finishing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(viewModel.errorMessage ?? 'Sign-in failed'),
        ),
      );
    }
  }

  Widget build(BuildContext context) {

    final signingIn = _finishing ||
        context.watch<GoogleSignInIntergration>().isLoading;

    return Stack(
      fit: StackFit.expand,
      children: [
        Scaffold(
          backgroundColor: AppColor.Screenbackground,
          appBar: AppBar(
            backgroundColor: AppColor.Screenbackground,
            leading: IconButton(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: Image.asset(
                'asset/icons/Backarrow.png',
                width: AppSize.iconBackArrowWidth,
                height: AppSize.iconBackArrowHeight,
              ),
            ),
          ),
          body: SafeArea(
            // Scrolls only when it has to. The Spacer below fills a tall screen
            // as before, but on a short one — an iPhone SE was 1.7px over — a
            // Spacer cannot go negative and the column clips instead. minHeight
            // keeps the fill behaviour; the scroll view absorbs the shortfall.
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSize.screenHorizontal.w,
                  vertical: AppSize.screenVertical.h,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        constraints.maxHeight - (AppSize.screenVertical.h * 2),
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                children: [
                  SizedBox(height: 300.h),

                  // Why they were sent here — a sign-up that found the
                  // account already exists lands on this screen, and
                  // arriving at a login form with no explanation reads as
                  // the app having lost their place.
                  if (widget.notice != null) ...[
                    Container(
                      width: double.infinity,
                      padding:
                          EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                      decoration: BoxDecoration(
                        color: AppColor.buttoncolor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              size: 17.sp, color: const Color(0xFF3D4A2C)),
                          SizedBox(width: 9.w),
                          Expanded(
                            child: Text(
                              widget.notice!,
                              style: TextStyle(
                                  fontSize: 12.5.sp,
                                  height: 1.45,
                                  color: const Color(0xFF3D4A2C)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.h),
                  ],

                  SizedBox(
                    width: double.infinity,
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          height: 60.h,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12.r),
                            color: AppColor.Screenbackground,
                            border: Border.all(
                              color: Colors.grey,
                              width: 1,
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 15.h, horizontal: 20.w),
                            child: TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                fontWeight: FontWeight.w300,
                                fontSize: 16.sp,
                                letterSpacing: 0,
                              ),
                              decoration: InputDecoration(
                                hintText: "Enter your Email",
                                hintStyle: TextStyle(
                                  fontWeight: FontWeight.w300,
                                  fontSize: 16.sp,
                                  letterSpacing: 0,
                                ),
                                border: InputBorder.none,
                                isCollapsed: true,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: AppSize.gap.h),
                        Container(
                          width: double.infinity,
                          height: 60.h,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12.r),
                            color: AppColor.Screenbackground,
                            border: Border.all(
                              color: Colors.grey,
                              width: 1,
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 15.h, horizontal: 20.w),
                            child:  TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                fontWeight: FontWeight.w300,
                                fontSize: 16.sp,
                                letterSpacing: 0,
                              ),
                              decoration: InputDecoration(
                                hintText: "Enter your Password",
                                hintStyle: TextStyle(
                                  fontWeight: FontWeight.w300,
                                  fontSize: 16.sp,
                                  letterSpacing: 0,
                                ),
                                border: InputBorder.none,
                                isCollapsed: true,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: AppSize.gap.h),
                        Consumer<GoogleSignInIntergration>(
                          builder: (context, viewModel, child) => GestureDetector(
                            onTap: (viewModel.isLoading || _finishing)
                                ? null
                                : () => _loginWithEmail(viewModel),
                            child: Container(
                              width: double.infinity,
                              height: 60.h,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12.r),
                                color: AppColor.buttoncolor,
                              ),
                              child: Center(
                                child: Text(
                                  "Login",
                                  style: TextStyle(
                                    color: AppColor.Buttontextcolor,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 20.sp,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: AppSize.gap.h),
              
                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ForgotPasswordScreen(
                            email: _emailController.text.trim(),
                          ),
                        ),
                      ),
                      child: Text("Forgot Password", style: TextStyle(
                        fontWeight: FontWeight.w300,
                        fontSize: 16.sp,
                        letterSpacing: 0,
                      )),
                    ),
                  ),


                  SizedBox(height: 80.h),

                  SizedBox(height: 18.h),

                  // The rules take whatever the label leaves, rather than two
                  // fixed 130.w bars that only happened to fit the design width.
                  // At 130 + 130 + the label this overflowed on any narrower
                  // screen — iPhone first, because iOS lays the text out wider.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Expanded(
                        child: Divider(color: Colors.grey, thickness: 0.5),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.w),
                        child: Text(
                          "Or sign-Up with",
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w500,
                            color: AppColor.Textcolor,
                          ),
                        ),
                      ),
                      const Expanded(
                        child: Divider(color: Colors.grey, thickness: 0.5),
                      ),
                    ],
                  ),

                  SizedBox(height: 40.h),

                  SizedBox(
                    width: double.infinity,
                    height: 60.h,
                    child: Row(
                      children: [
                        // ---- GOOGLE SIGN-IN BUTTON ----
                        Consumer<GoogleSignInIntergration>(
                          builder: (context, viewModel, child) {
                            return GestureDetector(
                              onTap: (viewModel.isLoading || _finishing)
                                  ? null
                                  : () => _signIn(viewModel, viewModel.signInWithGoogle),
                              child: Container(
                                width: 192.w,
                                height: 60.h,
                                decoration: BoxDecoration(
                                  color: AppColor.buttoncolor,
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Center(
                                  child: (viewModel.isLoading || _finishing)
                                      ? const CircularProgressIndicator()
                                      : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Image.asset(
                                        "asset/icons/googleicon.png",
                                        height: 24.h,
                                        width: 24.w,
                                      ),
                                      SizedBox(width: 10.w),
                                      Text(
                                        "Google",
                                        style: TextStyle(
                                          color: AppColor.Buttontextcolor,
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        const Spacer(),

                        // ---- APPLE SIGN-IN BUTTON ----
                        Consumer<GoogleSignInIntergration>(
                          builder: (context, viewModel, child) {
                            return GestureDetector(
                              onTap: (viewModel.isLoading || _finishing)
                                  ? null
                                  : () => _signIn(viewModel, viewModel.signInWithApple),
                              child: Container(
                                width: 192.w,
                                height: 60.h,
                                decoration: BoxDecoration(
                                  color: AppColor.buttoncolor,
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Center(
                                  child: Image.asset(
                                    "asset/icons/Appleicon.png",
                                    height: 34.h,
                                    width: 88.w,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // The whole screen while the session is being set up — the account
        // chooser closes on the form, and a button-sized spinner there reads
        // as nothing happening. It stays until AuthGate takes over, which is
        // the logo animation and then home.
        if (signingIn) const AppLoadingScreen(message: 'Signing you in…'),
      ],
    );
  }
}
