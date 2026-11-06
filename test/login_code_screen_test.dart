import 'package:dr_app/repository/google_sign_in_provider.dart';
import 'package:dr_app/view/Authendication/login/otp_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Future<void> _pump(WidgetTester tester, OtpScreen screen) async {
  await tester.pumpWidget(ChangeNotifierProvider(
    create: (_) => GoogleSignInIntergration(),
    child: ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => MaterialApp(home: screen),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets('an email login asks for its code', (tester) async {
    await _pump(
      tester,
      const OtpScreen(
          email: 'student@example.test', password: 'secret123', isLogin: true),
    );

    expect(find.text('Enter your login code'), findsOneWidget);
    expect(find.textContaining('student@example.test', findRichText: true),
        findsOneWidget);
    expect(find.text('Not you? Change email'), findsOneWidget);
    expect(find.text('Verify and log in'), findsOneWidget);
    expect(find.textContaining('expires in 10 minutes'), findsOneWidget);
  });

  testWidgets('a sign-up keeps its own words', (tester) async {
    await _pump(tester, const OtpScreen(email: 'student@example.test'));

    expect(find.text('Verify your email'), findsOneWidget);
    expect(find.text('Verify'), findsOneWidget);
    expect(find.text('Not you? Change email'), findsNothing);
  });
}
