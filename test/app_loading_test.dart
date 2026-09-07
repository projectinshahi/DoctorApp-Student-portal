import 'package:dr_app/widget/app_loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(440, 956);
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
  await tester.pump();
}

void main() {
  testWidgets('fills a Scaffold body when given no height', (tester) async {
    await _pump(tester, const AppLoading());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('takes the height it is given inside a card', (tester) async {
    await _pump(tester, Center(child: AppLoading(height: 180.h)));

    // The inline slots — the MCQ card, the comment list — reserve a fixed
    // block so the card does not resize when the content lands.
    expect(tester.getSize(find.byType(AppLoading)).height, 180.h);
  });

  testWidgets('lays out inside a scroll view without an infinite height',
      (tester) async {
    // A height-less AppLoading in an unbounded parent is the one way to
    // break it, so the inline form must be the one used there.
    await _pump(
      tester,
      SingleChildScrollView(child: AppLoading(height: 120.h)),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a message when one is given, and nothing when not',
      (tester) async {
    await _pump(tester, const AppLoading(message: 'Loading questions…'));
    expect(find.text('Loading questions…'), findsOneWidget);

    await _pump(tester, const AppLoading());
    expect(find.byType(Text), findsNothing);
  });
}
