import 'package:dr_app/view/Home/home_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
  @override
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
                width: 400.w,
                height: 134.h,
                child: Column(
                  children: [
                    Container(
                      width: 400.w,
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
                      width: 400.w,
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
                width: 400.w,
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
                width: 400.w,
                height: 60.h,
                child: Row(
                  children: [
                    // ---- GOOGLE SIGN-IN BUTTON ----
                    Consumer<GoogleSignInIntergration>(
                      builder: (context, viewModel, child) {
                        return GestureDetector(
                          onTap: viewModel.isLoading
                              ? null
                              : () async {
                            final success = await viewModel.signInWithGoogle();

                            if (!context.mounted) return;

                            if (success) {
                              final resposn ;
                              final result = viewModel.authResult!;

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    result.isNewUser
                                        ? 'Welcome, ${result.user.name}!'
                                        : 'Welcome back, ${result.user.name}!',
                                  ),
                                ),
                              );

                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => Homescreen(
                                    //authResult: result,
                                  ),
                                ),
                              );
                            } else {
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
                              child: viewModel.isLoading
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
