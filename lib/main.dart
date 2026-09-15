
import 'package:dr_app/repository/course_get_provider.dart';
import 'package:dr_app/repository/daily_quiz_provider.dart';
import 'package:dr_app/repository/google_sign_in_provider.dart';
import 'package:dr_app/repository/plan_provider.dart';
import 'package:dr_app/repository/profile_provider.dart';
import 'package:dr_app/repository/quiz_prefetch.dart';
import 'package:dr_app/repository/saved_provider.dart';
import 'package:dr_app/repository/refresh_api_provider.dart';
import 'package:dr_app/repository/selection_content_provider.dart';
import 'package:dr_app/repository/selection_provider.dart';
import 'package:dr_app/view/refresh_gate/auth_gate.dart';
import 'package:dr_app/widget/screenshot_guard.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import 'repository/rapid_recall_provider.dart';
import 'core/theam /app_theme.dart';
import 'core/utils/app_navigator.dart';
import 'core/utils/refresh_on_visible.dart';
import 'widget/integrity_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Started before runApp, because anything Firebase-backed needs it ready.
  // Guarded: a missing or mismatched google-services.json must not stop the
  // app opening — everything that matters today (the course, the quizzes,
  // sign-in) runs against the app's own backend, not Firebase.
  try {
    await Firebase.initializeApp();
  } catch (error) {
    if (kDebugMode) debugPrint('FIREBASE  not initialised: $error');
  }

  // Portrait everywhere. The one exception is fullscreen video, which asks
  // for landscape on the way in and puts this back on the way out — both
  // FullscreenVideoPage and youtube_player_flutter restore exactly this
  // value, so there is a single orientation the app returns to.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

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
        ChangeNotifierProvider(create: (_) => SavedProvider()),
        ChangeNotifierProvider(create: (_) => QuizPrefetch()),
        // Rapid Recall. One list for all four of its screens — four copies
        // would each fetch their own.
        ChangeNotifierProvider(create: (_) => RapidRecallProvider()),
        // The home card's read-only summary. Separate from the quiz provider
        // on purpose: this one never starts the day's attempt.
        ChangeNotifierProvider(create: (_) => HomeSummaryProvider())
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
            // Lets the session watcher reset the stack from outside any
            // screen — see AuthGate.
            navigatorKey: navigatorKey,
              title: "Dr. SKM's Academy",
              debugShowCheckedModeBanner: false,
              // One theme for every screen. Without it, anything a screen
              // did not style itself fell back to Flutter's blue and purple
              // — which is how the course picker ended up grey and black.
              theme: AppTheme.light,
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
