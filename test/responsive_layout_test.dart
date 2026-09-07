import 'package:dr_app/repository/daily_quiz_provider.dart';
import 'package:dr_app/repository/google_sign_in_provider.dart';
import 'package:dr_app/repository/profile_provider.dart';
import 'package:dr_app/repository/refresh_api_provider.dart';
import 'package:dr_app/repository/saved_provider.dart';
import 'package:dr_app/repository/selection_content_provider.dart';
import 'package:dr_app/view/Authendication/login/Sign_in_screen.dart';
import 'package:dr_app/view/Authendication/login/sign-up_screen.dart';
import 'package:dr_app/view/Home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Sizes the app actually ships to, in logical pixels.
///
/// The design size is 440x956, and every screen was only ever checked at it.
/// Anything narrower is where fixed widths run off the edge — which is how a
/// pair of 130.w dividers survived until an iPhone ran them.
const _devices = <String, Size>{
  'iPhone 17 Pro': Size(402, 874),
  'iPhone SE': Size(375, 667),
  'design size': Size(440, 956),
};

Future<void> _pump(WidgetTester tester, Size size, Widget screen) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SelectionContentProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => SavedProvider()),
        ChangeNotifierProvider(create: (_) => HomeSummaryProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => GoogleSignInIntergration()),
      ],
      child: ScreenUtilInit(
        designSize: const Size(440, 956),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) => MaterialApp(home: screen),
      ),
    ),
  );
  // Not pumpAndSettle: the loading spinner never stops animating.
  await tester.pump();
}

void main() {
  for (final entry in _devices.entries) {
    group('at ${entry.key} (${entry.value.width.toInt()} wide)', () {
      testWidgets('the sign-up screen has nothing running off the edge',
          (tester) async {
        // "Or sign-Up with" between two fixed 130.w rules. This is the
        // 9.5px overflow an iPhone 17 Pro reported.
        await _pump(tester, entry.value, const SignupScreen());
        expect(tester.takeException(), isNull);
      });

      testWidgets('the sign-in screen has nothing running off the edge',
          (tester) async {
        await _pump(tester, entry.value, const SignInScreen());
        expect(tester.takeException(), isNull);
      });

      testWidgets('the home screen lays out its header and nav bar',
          (tester) async {
        // Two more: the welcome card was a fixed 165.h around growing text,
        // and five nav labels at 18.sp were 156px wider than the bar.
        await _pump(tester, entry.value, const Homescreen());
        expect(tester.takeException(), isNull);
      });
    });
  }
}
