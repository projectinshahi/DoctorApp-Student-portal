import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../repository/refresh_api_provider.dart';

import '../../../widget/login_refused_dialog.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../core/theam /app_color.dart';
import '../../../core/constant/app_size.dart';
import '../../../repository/google_sign_in_provider.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

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

  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    print("Hight of the screen : ${size.height}");
    print(" Width of the screen : ${size.width}");

    return Scaffold(
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
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSize.screenHorizontal.w,
            vertical: AppSize.screenVertical.h,
          ),
          child: Column(
            children: [
              SizedBox(height: 380.h),

              SizedBox(
                width: double.infinity,
                height: 134.h,
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
                        child:  TextField(
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
                    SizedBox(height: AppSize.gap),
                    Container(
                      width: double.infinity,
                      height: 60.h,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12.r),
                        color: AppColor.buttoncolor,
                      ),
                      child: Center(
                        child: SizedBox(
                          //height: 20.h,
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
                  ],
                ),
              ),
              SizedBox(height: AppSize.gap),
              
              Center(child: Text("Forgot Password", style: TextStyle(
                fontWeight: FontWeight.w300,
                fontSize: 16.sp,
                letterSpacing: 0,
              ),),),


              SizedBox(height: 80.h),

              SizedBox(
                width: double.infinity,
                height: 20.h,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(width: 130.w, height: 0.5, color: Colors.grey),
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
                    Container(width: 130.w, height: 0.5, color: Colors.grey),
                  ],
                ),
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
                              : () async {
                            setState(() => _finishing = true);
                            final success = await viewModel.signInWithGoogle();

                            if (!context.mounted) return;

                            // A refusal stays on this screen and explains
                            // itself, rather than falling through to the
                            // generic failure snack bar below.
                            final refused = viewModel.refusal;
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
                              if (!context.mounted) return;
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
                          },
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

                    Container(
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
