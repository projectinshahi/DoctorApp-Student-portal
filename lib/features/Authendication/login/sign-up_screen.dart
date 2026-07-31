import 'package:dr_app/core/constant/app_size.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constant/app_color.dart';



class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  @override
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
          padding:  EdgeInsets.symmetric(
            horizontal: AppSize.screenHorizontal.w,
            vertical: AppSize.screenVertical.h,
          ),
          child: Column(

            children: [
              SizedBox(height: 400.h,),

              SizedBox(
                width: 400.w,
                height: 134.h,
                //color: Colors.black,
                child: Column(
                  children: [
                    Container(
                      width: 400.w,
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

                     SizedBox(height: AppSize.gap,),

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
                          child: Text("Next",style: TextStyle(
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

              SizedBox(height: 80.h,),

              SizedBox(
                width: 400.w,
                height: 20.h,

                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 130.w,
                      height: 0.5,
                      color: Colors.grey,
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
                    Container(
                      width: 130.w,
                      height: 0.5,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),

              SizedBox(height: 40.h,),


              SizedBox(
                width: 400.w,
                height: 60.h,
                child: Row(
                  children: [
                    Container(
                      width: 192.w,
                      height: 60.h,
                      decoration: BoxDecoration(
                        color: AppColor.buttoncolor,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Center(
                        child: Center(
                          child: Row(
                           mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset("asset/icons/googleicon.png", height: 24.h,width: 24.w,),
                              SizedBox(width: 10.w,),
                               Text("Google",
                               style: TextStyle(color: AppColor.Textcolor, fontSize: 16.sp, fontWeight: FontWeight.w500),),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Spacer(),

                    Container(
                      width: 192.w,
                      height: 60.h,
                      decoration: BoxDecoration(
                        color: AppColor.buttoncolor,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Center(
                        child: Center(
                          child: Image.asset("asset/icons/Appleicon.png", height: 34.h,width: 88.w,),
                        ),
                      ),
                    ),
                  ],
                ),
              )

            ],
          )
        ),
      ),
    );
  }
}
