import 'package:dr_app/core/theam%20/app_color.dart';
import 'package:dr_app/view/Authendication/login/Sign_in_screen.dart';
import 'package:dr_app/view/Authendication/login/sign-up_screen.dart';
import 'package:flutter/material.dart';
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
    print("Hight of the screen : ${size.height}");
    print(" Width of the screen : ${size.width}");



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

                    Container(
                      width: 150.w,
                      height: 150.w,
                      decoration: BoxDecoration(
                        color: AppColor.buttoncolor,
                        borderRadius: BorderRadius.circular(24.r),
                      ),
                    ),

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
