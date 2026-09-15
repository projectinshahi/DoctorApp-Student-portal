import 'package:dr_app/widget/loading_wave.dart';
import 'package:dr_app/widget/quiz_loading.dart';
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
        home: Scaffold(
          body: message == null
              ? const QuizLoading()
              : QuizLoading(message: message),
        ),
      ),
    ),
  );
  // Not pumpAndSettle: the wave repeats forever, so settling never returns.
  await tester.pump();
}

void main() {
  testWidgets('says what it is preparing', (tester) async {
    await _pump(tester);
    expect(find.text('Preparing your questions…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the wave actually moves', (tester) async {
    await _pump(tester);

    // The lift is what the colour is derived from, so reading it directly
    // says the animation is running without depending on how a bar paints.
    List<double> lifts() => tester
        .widgetList<WaveBar>(find.byType(WaveBar))
        .map((b) => b.lift)
        .toList();

    final before = lifts();
    expect(before, isNotEmpty);

    // Part way through the cycle — far enough that a static skeleton and an
    // animated one cannot look the same.
    await tester.pump(const Duration(milliseconds: 380));
    expect(lifts(), isNot(before));
  });

  testWidgets('lays out at phone size and at a short one', (tester) async {
    for (final size in [const Size(440, 956), const Size(375, 667)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(440, 956),
          minTextAdapt: true,
          builder: (context, child) =>
              const MaterialApp(home: Scaffold(body: QuizLoading())),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'at $size');
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('the ticker stops when the screen goes away', (tester) async {
    // A leaked ticker keeps animating a screen nobody is looking at, and
    // trips the binding's pending-timer check.
    await _pump(tester);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('questions'))),
    );
    await tester.pumpAndSettle();

    expect(find.text('questions'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
