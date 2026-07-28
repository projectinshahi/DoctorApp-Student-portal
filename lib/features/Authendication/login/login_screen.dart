import 'package:dr_app/core/constant/app_color.dart';
import 'package:flutter/cupertino.dart';
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
              Padding(
                padding:  EdgeInsets.only(
                  top: 190.h,
                  //left: 100.w,
                ),
                child: SizedBox(
                  width: 234.w,
                  height: 214.h,

                  child: Column(
                    children: [
                      Container(
                        width: 150.w,
                        height: 150.h,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24.r),
                          color: AppColor.buttoncolor
                        ),
                      ),

                      SizedBox(height: AppSize.gap,),

                      SizedBox(
                        height: 40.h,
                        width: 234.w,
                        child: Text("Educational LMS",style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 31.sp,
                          letterSpacing: 0,

                        ),),
                      )

                    ],
                  ),


                ),
              ),

              SizedBox(height: 230.h),

              SizedBox(
                width: 400.w,
                height: 134.h,
                child: Column(
                  children: [
                    Container(
                      width: 400.w,
                      height: 60.h,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12.r),
                        color: AppColor.buttoncolor,
                      ),
                   child:  Center(
                     child: SizedBox(
                       height: 20.h,
                       child: Text("Sign up with E.mail",style: TextStyle(
                         fontWeight: FontWeight.w500,
                         fontSize: 16.sp,
                         letterSpacing: 0,
                       ),),
                     ),
                   ),
                    ),
                    SizedBox(height: 10.h,),

                    Container(
                      width: 400.w,
                      height: 60.h,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12.r),
                        color: AppColor.buttoncolor,
                      ),
                      child: Center(
                        child: SizedBox(
                          height: 20.h,
                          child: Text("Already have an account? Log in",style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 16.sp,
                            letterSpacing: 0,
                          ),),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 30.h,),
              Text(
                "By signing up, you accept to the\nTerms and Conditions and Privacy Policy",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.grey,
                  height: 1.5,
                ),
              )


            ],
          ),
        ),
      ),
    );
  }
}
