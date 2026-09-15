import 'package:dr_app/widget/app_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, double size) async {
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: Center(child: AppLogo(size: size)))),
  );
  await tester.pump();
}

void main() {
  testWidgets('is clipped to a circle and fills its box', (tester) async {
    // The artwork carries a wide margin around the roundel. Unclipped it
    // either sits small in its box or shows that margin as a pale rectangle
    // against the cream background.
    await _pump(tester, 150);

    expect(find.byType(ClipOval), findsOneWidget);
    expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.cover);
    expect(tester.getSize(find.byType(ClipOval)), const Size(150, 150));
  });

  testWidgets('takes the size it is given', (tester) async {
    // Three callers at three sizes: the splash and login at 150, the sign-in
    // loading screen at 110.
    await _pump(tester, 110);
    expect(tester.getSize(find.byType(ClipOval)), const Size(110, 110));
  });

  testWidgets('a missing asset cannot show a red error box', (tester) async {
    // A fresh clone before the logo is added must still launch.
    await _pump(tester, 150);

    expect(tester.widget<Image>(find.byType(Image)).errorBuilder, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
