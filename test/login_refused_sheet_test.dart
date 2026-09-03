import 'package:dr_app/services/Auth_services.dart' show LoginRefusedException;
import 'package:dr_app/widget/login_refused_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _show(WidgetTester tester, LoginRefusedException refused) async {
  tester.view.physicalSize = const Size(440, 956);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(440, 956),
      minTextAdapt: true,
      builder: (context, child) => MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showLoginRefusedDialog(context, refused),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the wait is spelled out when the server gives one',
      (tester) async {
    await _show(
      tester,
      const LoginRefusedException(
        code: 'SESSION_ACTIVE_ELSEWHERE',
        message: 'This account is signed in on another device. Sign out there '
            'first, or try again in a few minutes.',
        retryAfterMinutes: 30,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Already signed in'), findsOneWidget);
    // The server's sentence, verbatim.
    expect(find.textContaining('signed in on another device'), findsOneWidget);
    // Plus the concrete next step, with the real number in it.
    expect(find.textContaining('about 30 minutes'), findsOneWidget);

    // No retry and no override: an immediate retry fails identically, and
    // the API has no force-sign-in flag to back such a button.
    expect(find.text('Try again'), findsNothing);
    expect(find.text('Sign in anyway'), findsNothing);
    expect(find.text('Got it'), findsOneWidget);
  });

  testWidgets('without a window it still says what to do', (tester) async {
    await _show(
      tester,
      const LoginRefusedException(
        code: 'SESSION_ACTIVE_ELSEWHERE',
        message: 'This account is signed in on another device.',
      ),
    );

    // Never "about null minutes".
    expect(find.textContaining('null'), findsNothing);
    expect(find.textContaining('Sign out on your other device'), findsOneWidget);
  });

  testWidgets('a blocked account is a different conversation', (tester) async {
    await _show(
      tester,
      const LoginRefusedException(
        code: 'ACCOUNT_BLOCKED',
        message: 'This account has been disabled.',
      ),
    );

    expect(find.text('Account disabled'), findsOneWidget);
    expect(find.textContaining('contact support'), findsOneWidget);
    // Not the sign-in-elsewhere wording.
    expect(find.text('Already signed in'), findsNothing);
  });

  testWidgets('an unknown code falls back without crashing', (tester) async {
    await _show(
      tester,
      const LoginRefusedException(
        code: null,
        message: 'Could not sign in. Please try again.',
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Could not sign in'), findsOneWidget);
  });

  testWidgets('it closes, leaving the login screen behind it', (tester) async {
    await _show(
      tester,
      const LoginRefusedException(
        code: 'SESSION_ACTIVE_ELSEWHERE',
        message: 'x',
        retryAfterMinutes: 5,
      ),
    );

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    expect(find.text('Already signed in'), findsNothing);
    expect(find.text('go'), findsOneWidget);
  });
}
