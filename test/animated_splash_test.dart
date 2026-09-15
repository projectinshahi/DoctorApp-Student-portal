import 'package:dr_app/view/splash/animated_splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester,
    {String? message, Size size = const Size(440, 956)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(440, 956),
      minTextAdapt: true,
      builder: (context, _) => MaterialApp(
        home: message == null
            ? const AnimatedSplash()
            : AnimatedSplash(message: message),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('shows the wordmark, and the mark above it', (tester) async {
    await _pump(tester);
    await tester.pumpAndSettle();

    expect(find.text("Dr. SKM's Academy"), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a missing logo cannot show a red error box', (tester) async {
    // The asset is in the repo, so this no longer falls back — but a fresh
    // clone before the logo is added would, and the very first screen a
    // developer sees must not be an error box. Assert the guard is wired
    // rather than trying to unload an asset.
    await _pump(tester);
    await tester.pump();

    final logo = tester.widget<Image>(find.byType(Image));
    expect(logo.errorBuilder, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the mark is clipped to a circle', (tester) async {
    // The artwork carries a wide margin around the roundel. Unclipped it
    // either sits small in its box or shows that margin as a pale rectangle
    // on the cream background.
    await _pump(tester);
    await tester.pumpAndSettle();

    expect(
      find.descendant(
          of: find.byType(AnimatedSplash), matching: find.byType(ClipOval)),
      findsOneWidget,
    );
    expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.cover);
  });

  testWidgets('the animation actually runs', (tester) async {
    await _pump(tester);

    // The mark's scale, not a FadeTransition: MaterialApp wraps routes in
    // their own fade, so byType(FadeTransition).first is the route's.
    // By key: route transitions contribute ScaleTransitions of their own, so
    // finding by type is ambiguous.
    double markScale() => tester
        .widget<ScaleTransition>(find.byKey(AnimatedSplash.markKey))
        .scale
        .value;

    final atStart = markScale();
    await tester.pump(const Duration(milliseconds: 300));
    expect(markScale(), isNot(atStart));

    await tester.pumpAndSettle();
    expect(markScale(), 1.0, reason: 'it settles, rather than looping');
  });

  testWidgets('the message is optional', (tester) async {
    await _pump(tester);
    await tester.pumpAndSettle();
    // Just the wordmark on a fast launch.
    expect(find.byType(Text), findsOneWidget);

    await _pump(tester, message: 'Starting up…');
    await tester.pumpAndSettle();
    expect(find.text('Starting up…'), findsOneWidget);
  });

  testWidgets('lays out on a short phone', (tester) async {
    await _pump(tester, size: const Size(375, 667));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the ticker stops when the splash goes away', (tester) async {
    await _pump(tester);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('home'))),
    );
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the wordmark sits at the foot, the mark in the middle',
      (tester) async {
    // WhatsApp's shape: the mark owns the centre, the name sits low.
    await _pump(tester);
    await tester.pumpAndSettle();

    final screen = tester.getSize(find.byType(AnimatedSplash)).height;
    final markY = tester.getCenter(find.byKey(AnimatedSplash.markKey)).dy;
    final textY = tester.getCenter(find.text("Dr. SKM's Academy")).dy;

    expect(markY, lessThan(screen * 0.6));
    expect(textY, greaterThan(screen * 0.8), reason: 'near the bottom');
    expect(textY, greaterThan(markY));
  });

  test('the hold is two seconds', () {
    // A brand moment, not a data wait. Named so the length is one constant
    // rather than a number buried in the gate.
    expect(AnimatedSplash.hold, const Duration(seconds: 2));
  });
}
