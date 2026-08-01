
import 'package:dr_app/repository/google_sign_in_provider.dart';
import 'package:dr_app/view/Authendication/login/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GoogleSignInIntergration()),
      ],
      child: ScreenUtilInit(
          designSize: const Size(440, 956), // Figma design size
          minTextAdapt: true,
          splitScreenMode: true,
        builder: (context, child){
          return MaterialApp(
              title: 'Flutter Demo',
              debugShowCheckedModeBanner: false,
              home: LoginScreen()
          );
        }

      ),
    );
  }
}
