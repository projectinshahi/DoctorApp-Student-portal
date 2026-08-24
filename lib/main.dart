
import 'package:dr_app/repository/course_get_provider.dart';
import 'package:dr_app/repository/google_sign_in_provider.dart';
import 'package:dr_app/repository/plan_provider.dart';
import 'package:dr_app/repository/profile_provider.dart';
import 'package:dr_app/repository/refresh_api_provider.dart';
import 'package:dr_app/repository/selection_content_provider.dart';
import 'package:dr_app/repository/selection_provider.dart';
import 'package:dr_app/view/refresh_gate/auth_gate.dart';
import 'package:dr_app/view/splash/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GoogleSignInIntergration()),
        ChangeNotifierProvider(create: (_) => CourseListGetProvider()),
        ChangeNotifierProvider(create: (_)=> SelectionProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
       ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => PlanProvider()),
        ChangeNotifierProvider(create: (_) => SelectionContentProvider())
      ],
      child: ScreenUtilInit(
          designSize: const Size(440, 956), // Figma design size
          minTextAdapt: true,
          splitScreenMode: true,
        builder: (context, child){
          return MaterialApp(
              title: 'Flutter Demo',
              debugShowCheckedModeBanner: false,
              home: AuthGate()
          );
        }

      ),
    );
  }
}
