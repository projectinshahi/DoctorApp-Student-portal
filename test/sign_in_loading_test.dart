import 'package:dr_app/repository/google_sign_in_provider.dart';
import 'package:dr_app/repository/refresh_api_provider.dart';
import 'package:dr_app/view/Authendication/login/Sign_in_screen.dart';
import 'package:dr_app/view/Authendication/login/login_screen.dart';
import 'package:dr_app/view/Authendication/login/sign-up_screen.dart';
import 'package:dr_app/widget/app_loading_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester, Widget screen,
    {required bool signingIn}) async {
  tester.view.physicalSize = const Size(440, 956);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(
            create: (_) => GoogleSignInIntergration()..isLoading = signingIn),
      ],
      child: ScreenUtilInit(
        designSize: const Size(440, 956),
        minTextAdapt: true,
        builder: (context, _) => MaterialApp(home: screen),
      ),
    ),
  );
  // Not pumpAndSettle: the loading screen's logo pulses forever.
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the email to sign in with', () {
    // The plan is bought on the website and tied to that address. Signing in
    // with another one makes a second account with no plan, and the app then
    // tells them their learning plan is not active — with no hint as to why.
    for (final entry in <String, Widget>{
      'the login screen': const LoginScreen(),
      'the sign-up screen': SignupScreen(),
      'the sign-in screen': SignInScreen(),
    }.entries) {
      testWidgets('${entry.key} says to use the website address',
          (tester) async {
        await _pump(tester, entry.value, signingIn: false);

        expect(find.textContaining('registered with on our website'),
            findsOneWidget);
      });
    }
  });

  group('picking a Google account', () {
    testWidgets('the sign-up screen waits on a full screen, not a button',
        (tester) async {
      // The account chooser closes back onto the form, and a button-sized
      // spinner there reads as nothing having happened.
      await _pump(tester, const SignupScreen(), signingIn: true);

      expect(find.byType(AppLoadingScreen), findsOneWidget);
      expect(find.text('Signing you in…'), findsOneWidget);
    });

    testWidgets('the sign-in screen does the same', (tester) async {
      await _pump(tester, const SignInScreen(), signingIn: true);

      expect(find.byType(AppLoadingScreen), findsOneWidget);
    });

    testWidgets('the form is on show when nothing is signing in',
        (tester) async {
      await _pump(tester, const SignupScreen(), signingIn: false);

      expect(find.byType(AppLoadingScreen), findsNothing);
    });
  });
}
