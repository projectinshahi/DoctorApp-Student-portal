import 'package:dr_app/widget/app_loading_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, {String? message}) async {
  tester.view.physicalSize = const Size(440, 956);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(440, 956),
      minTextAdapt: true,
      builder: (context, child) => MaterialApp(
        home: message == null
            ? const AppLoadingScreen()
            : AppLoadingScreen(message: message),
      ),
    ),
  );
  // Not pumpAndSettle: the pulse repeats forever, so settling never returns.
  await tester.pump();
}

void main() {
  testWidgets('shows a spinner and says what it is waiting on',
      (tester) async {
    await _pump(tester, message: 'Loading your course…');

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading your course…'), findsOneWidget);
    expect(find.text("Dr. SKM's Academy"), findsOneWidget);
  });

  testWidgets('has a default message rather than an empty line',
      (tester) async {
    await _pump(tester);
    expect(find.text('Just a moment…'), findsOneWidget);
  });

  testWidgets('lays out clean at phone size', (tester) async {
    await _pump(tester, message: 'Signing you in…');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the animation stops when the screen goes away', (tester) async {
    await _pump(tester, message: 'x');

    // Swapping it out must dispose the controller. A leaked ticker keeps
    // animating a screen nobody is looking at, and trips the test binding's
    // pending-timer check.
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(440, 956),
        builder: (context, child) =>
            const MaterialApp(home: Scaffold(body: Text('next'))),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('next'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
