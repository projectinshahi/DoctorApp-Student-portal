
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
import 'repository/notification_feed_provider.dart';
import 'repository/plan_access_provider.dart';
import 'repository/settings_provider.dart';
import 'services/notification_service.dart';
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

  // And the same for the system bars, for the same reason. Fullscreen video
  // goes immersive and restores edge-to-edge on the way out — a mode the app
  // had never asked for, so the first video of a session quietly changed how
  // much room the system navigation takes and shifted the tab bar down by
  // its height. Set here, before and after a video are the same.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Notification channels, the time zone the study reminder is scheduled
  // in, and course alerts. Before runApp, so a notification that launched
  // the app is caught rather than lost.
  await NotificationService.instance.init();

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
        ChangeNotifierProvider(create: (_) => SavedProvider()),
        ChangeNotifierProvider(create: (_) => QuizPrefetch()),
        ChangeNotifierProvider(create: (_) => RapidRecallProvider()),
        // The student's settings, applied app-wide: course alerts, the
        // study reminder, quiz sounds and analytics consent.
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        // The notification list and the number on the bell. Read by the
        // home header and by the notifications screen.
        ChangeNotifierProvider(create: (_) => NotificationFeedProvider()),
        // Which tabs the student's plan covers.
        ChangeNotifierProvider(create: (_) => PlanAccessProvider()),
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
