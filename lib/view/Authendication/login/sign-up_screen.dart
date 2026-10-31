import 'package:flutter/material.dart';


import '../../../widget/app_loading_screen.dart';

import '../../../repository/refresh_api_provider.dart';

import '../../../widget/login_refused_dialog.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:dr_app/core/constant/app_size.dart';
import '../../../core/theam /app_color.dart';
import '../../../repository/google_sign_in_provider.dart';
import 'otp_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  bool _isSigningIn = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _registering = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _say(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  /// Creates the account, then asks for the code the server just emailed.
  Future<void> _register() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // The server checks these too; asking here saves a round trip.
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return _say('Enter a valid email address.');
    }
    if (password.length < 8) {
      return _say('Password must be at least 8 characters.');
    }

    setState(() => _registering = true);
    final refused = await context
        .read<GoogleSignInIntergration>()
        .registerWithEmail(email, password);
    if (!mounted) return;
    setState(() => _registering = false);

    // "Already registered — log in" and friends: the server's words fit.
    if (refused != null) return _say(refused.message);

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OtpScreen(email: email)),
    );
  }

  /// Shared by the Google and Apple buttons: the server's reply, and so
  /// everything after it, is the same for both.
  Future<void> _signIn(
    GoogleSignInIntergration viewModel,
    Future<bool> Function() signIn,
  ) async {
    setState(() => _isSigningIn = true);

    final success = await signIn();

    // The server turned it away for a stated reason —
    // in use elsewhere, blocked, a bound device. Each
    // needs different words, and the code is what
    // decides. Staying put is the point: there is no
    // force-sign-in to offer.
    final refused = viewModel.refusal;
    if (refused != null && mounted) {
      setState(() => _isSigningIn = false);
      await showLoginRefusedDialog(context, refused);
      return;
    }

    if (!mounted) return;

    // Deliberately still signing in: adoptSession has
    // a /selection/content call to make, and clearing
    // this here put the form back on screen for the
    // length of it.
    final result = viewModel.authResult;

    if (success && result != null) {
      // No "Welcome back" toast. The home screen
      // already greets them by name, and a snack bar
      // riding in over the transition just competes
      // with the notice shown when another device was
      // signed out.

      // Hand the session to AuthProvider, which is
      // what AuthGate watches. Without this the
      // tokens were stored but the gate went on
      // showing the login screen until some later
      // rebuild — the flicker between signing in and
      // landing on home.
      await context
          .read<AuthProvider>()
          .adoptSession(result);

      if (!mounted) return;
      // Left spinning until now on purpose:
      // adoptSession still had a /selection/content
      // call to make after the 200 landed.
      setState(() => _isSigningIn = false);

      // No navigation of our own. AuthGate swaps its
      // root — to the course picker for a new
      // account, to home otherwise.
      //
      // pushReplacement removed AuthGate from the
      // tree, taking the session watcher with it, and
      // it pushed ExamSelectionScreen with three empty
      // strings for the tokens it needs.
      Navigator.of(context).popUntil((r) => r.isFirst);
    } else {
      // Back to the form, or the button stays disabled
      // and they cannot try again.
      setState(() => _isSigningIn = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            viewModel.errorMessage ?? 'Sign-in failed',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {

    final signingIn = _isSigningIn ||
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
                  // A Spacer, not SizedBox(height: 400.h). A fixed spacer that
                  // large claims 42% of the design height whatever the screen
                  // actually is — it overflowed on short devices and left a gap
                  // on tall ones. This takes whatever is left instead.
                  const Spacer(),

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
                              color: Colors.grey.shade300,
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
                                hintText: "Sign up with E.mail",
                                hintStyle: TextStyle(
                                  fontWeight: FontWeight.w500,
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
                              color: Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 15.h, horizontal: 20.w),
                            child: TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                fontWeight: FontWeight.w300,
                                fontSize: 16.sp,
                                letterSpacing: 0,
                              ),
                              decoration: InputDecoration(
                                hintText: "Create a password (8+ characters)",
                                hintStyle: TextStyle(
                                  fontWeight: FontWeight.w500,
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
                                  onPressed: () => setState(
                                      () => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: AppSize.gap.h),
                        GestureDetector(
                          onTap: _registering ? null : _register,
                          child: Container(
                            width: double.infinity,
                            height: 60.h,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12.r),
                              color: AppColor.buttoncolor,
                            ),
                            child: Center(
                              child: _registering
                                  ? const CircularProgressIndicator()
                                  : Text(
                                      "Next",
                                      style: TextStyle(
                                        color: AppColor.Buttontextcolor,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 16.sp,
                                        letterSpacing: 0,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
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
                              onTap: (viewModel.isLoading || _isSigningIn)
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
                                  child: (viewModel.isLoading || _isSigningIn)
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
                              onTap: (viewModel.isLoading || _isSigningIn)
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