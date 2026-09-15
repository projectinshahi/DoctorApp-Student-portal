import 'package:dr_app/widget/home_loading.dart';
import 'package:dr_app/widget/loading_wave.dart';
import 'package:dr_app/widget/quiz_loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget child, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(440, 956),
      minTextAdapt: true,
      builder: (context, _) => MaterialApp(home: Scaffold(body: child)),
    ),
  );
  // Not pumpAndSettle: the wave repeats forever, so settling never returns.
  await tester.pump();
}

void main() {
  testWidgets('the home skeleton lays out at three device sizes',
      (tester) async {
    for (final size in [
      const Size(440, 956), // design
      const Size(402, 874), // iPhone 17 Pro
      const Size(375, 667), // iPhone SE — much shorter
    ]) {
      await _pump(tester, const HomeLoading(), size);
      expect(tester.takeException(), isNull, reason: 'at $size');
    }
  });

  testWidgets('the wave moves', (tester) async {
    await _pump(tester, const HomeLoading(), const Size(440, 956));

    // The lift is what the colour is derived from, so reading it directly
    // says the animation is running without depending on how a bar paints.
    List<double> lifts() =>
        tester.widgetList<WaveBar>(find.byType(WaveBar)).map((b) => b.lift).toList();

    final before = lifts();
    expect(before, isNotEmpty);

    // Part way through the cycle — far enough that a static skeleton and an
    // animated one cannot look the same.
    await tester.pump(const Duration(milliseconds: 380));
    expect(lifts(), isNot(before));
  });

  testWidgets('both loaders share one ticker each, and release it',
      (tester) async {
    // A leaked ticker animates a screen nobody is looking at and trips the
    // binding's pending-timer check.
    for (final loader in [const HomeLoading(), const QuizLoading()]) {
      await _pump(tester, loader, const Size(440, 956));
      expect(find.byType(LoadingWave), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('loaded'))),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('the wave runs at the shared duration', (tester) async {
    // One cycle, one constant. If a screen ever wants its own pace it passes
    // `duration` rather than the animation quietly differing per screen.
    await _pump(tester, const HomeLoading(), const Size(440, 956));

    final wave = tester.widget<LoadingWave>(find.byType(LoadingWave));
    expect(wave.duration, const Duration(milliseconds: 1100));
  });

  testWidgets('every skeleton in the app runs on the shared wave',
      (tester) async {
    // One animation, one pace. A screen that quietly rolled its own spinner
    // back in — or its own duration — would show up here.
    for (final loader in [const HomeLoading(), const QuizLoading()]) {
      await _pump(tester, loader, const Size(440, 956));

      expect(find.byType(LoadingWave), findsOneWidget, reason: '$loader');
      expect(find.byType(CircularProgressIndicator), findsNothing,
          reason: '$loader must not fall back to a spinner');
    }
  });
}
