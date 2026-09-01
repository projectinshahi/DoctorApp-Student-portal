
import 'package:dr_app/repository/course_get_provider.dart';
import 'package:dr_app/repository/google_sign_in_provider.dart';
import 'package:dr_app/repository/plan_provider.dart';
import 'package:dr_app/repository/profile_provider.dart';
import 'package:dr_app/repository/saved_provider.dart';
import 'package:dr_app/repository/refresh_api_provider.dart';
import 'package:dr_app/repository/selection_content_provider.dart';
import 'package:dr_app/repository/selection_provider.dart';
import 'package:dr_app/view/refresh_gate/auth_gate.dart';
import 'package:dr_app/widget/screenshot_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'core/utils/refresh_on_visible.dart';
import 'widget/integrity_gate.dart';

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
        ChangeNotifierProvider(create: (_) => SelectionContentProvider()),
        // App-wide: the QBank badge, the toggle inside a quiz and the saved
        // list all read the same counts, so there is one instance, not three.
        // Primed from HomeScreen, which is the first place a token exists.
        ChangeNotifierProvider(create: (_) => SavedProvider())
      ],
      child: ScreenUtilInit(
          designSize: const Size(440, 956), // Figma design size
          minTextAdapt: true,
          splitScreenMode: true,
        builder: (context, child){
          return MaterialApp(
            // Screens mix in RefreshOnVisible to refetch when they appear.
            // Without this line that mixin is silently inert.
            navigatorObservers: [routeObserver],
              title: "Dr. SKM's Academy",
              debugShowCheckedModeBanner: false,
              // Wrapped here, not per screen: `builder` sits above the
              // Navigator, so every route — dialogs, the video player and the
              // quiz included — is blocked by this one switch.
              builder: (context, child) => ScreenshotGuard(child: child!),
              // Before AuthGate on purpose: a compromised device must not
              // reach a sign-in form, because the credentials it collects are
              // the next thing to be read out of memory.
              home: const IntegrityGate(child: AuthGate())
          );
        }

      ),
    );
  }
}
