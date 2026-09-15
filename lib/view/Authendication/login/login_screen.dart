import '../../../widget/app_logo.dart';
import 'package:dr_app/core/theam%20/app_color.dart';
import 'package:dr_app/view/Authendication/login/Sign_in_screen.dart';
import 'package:dr_app/view/Authendication/login/sign-up_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../repository/refresh_api_provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/constant/app_size.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;



    return Scaffold(
      backgroundColor: AppColor.Screenbackground,
      body: SafeArea(
        child: Padding(
          padding:  EdgeInsets.symmetric(
            horizontal: AppSize.screenHorizontal.w,
            vertical: AppSize.screenVertical.h,
          ),
          child: Column(
            children: [

              SizedBox(height: size.height * .20),

              Container(
               // width: 234.w,
                //color: Colors.yellow,
                child: Column(
                  children: [

                    AppLogo(size: 150.w),

                    SizedBox(height: 20.h),
                    Text(
                      "Dr. SKM's Academy",
                      style: TextStyle(
                        fontSize: 31.sp,
                        fontWeight: FontWeight.w400,
                      ),
                    )

                  ],
                ),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                child: Column(
                  children: [
                    // Why they are here, above the button they are about to
                    // press. This used to be a dialog on launch, which fired
                    // on every cold start with a dead session and interrupted
                    // a student who had not touched anything yet.
                    Consumer<AuthProvider>(
                      builder: (context, auth, _) {
                        final message = auth.sessionMessage;
                        if (message == null) return const SizedBox.shrink();

                        return Container(
                          width: double.infinity,
                          margin: EdgeInsets.only(bottom: 14.h),
                          padding: EdgeInsets.symmetric(
                              horizontal: 14.w, vertical: 12.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8A33D)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                                color: const Color(0xFFE8A33D)
                                    .withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline_rounded,
                                  size: 16.sp,
                                  color: const Color(0xFF8A5B18)),
                              SizedBox(width: 9.w),
                              Expanded(
                                child: Text(
                                  // The server's wording, unchanged.
                                  message,
                                  style: TextStyle(
                                      fontSize: 12.sp,
                                      height: 1.4,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF8A5B18)),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    SizedBox(
                      width: double.infinity,
                      height: 60.h,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColor.buttoncolor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SignupScreen(),
                            ),
                          );
                        },
                        child: Text(
                          "Sign up with E.mail",
                          style: TextStyle(fontSize: 16.sp, color: AppColor.Buttontextcolor),
                        ),
                      ),
                    ),

                    SizedBox(height: 12.h),

                    SizedBox(
                      width: double.infinity,
                      height: 60.h,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColor.buttoncolor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SignInScreen(),
                            ),
                          );
                        },
                        child: Text(
                          "Already have an account? Log in",
                          style: TextStyle(fontSize: 16.sp, color: AppColor.Buttontextcolor),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 25.h),

              Text(
                "By signing up, you accept to the\nTerms and Conditions and Privacy Policy",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.black38,
                  height: 1.5,
                ),
              ),

              SizedBox(height: 15.h),
            ],
          )
        ),
      ),
    );
  }
}
