import 'package:dr_app/view/Home/profile/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester,
    {Size size = const Size(440, 956)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(440, 956),
      minTextAdapt: true,
      builder: (context, _) => const MaterialApp(home: SettingsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows the three sections and every row', (tester) async {
    await _pump(tester);

    for (final label in ['Notifications', 'Privacy', 'Support']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    for (final row in [
      'Push notification',
      'Daily study reminder',
      'Sound effect',
      'Usage analytics',
      'Help & support',
      'Rate the app',
    ]) {
      expect(find.text(row), findsOneWidget, reason: row);
    }
    expect(find.textContaining('App version'), findsOneWidget);
  });

  testWidgets('every switch starts off', (tester) async {
    // Analytics especially: consent a student has not given is the wrong
    // default, and nothing here should be on before they say so.
    await _pump(tester);

    for (final s in tester.widgetList<Switch>(find.byType(Switch))) {
      expect(s.value, isFalse);
    }
  });

  testWidgets('a flipped switch is written to storage', (tester) async {
    // The point of the screen: the choice survives a restart, whether or not
    // a feature reads it yet.
    await _pump(tester);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(SettingsKeys.pushNotifications), isTrue);
  });

  testWidgets('stored values are shown, not the defaults', (tester) async {
    SharedPreferences.setMockInitialValues({
      SettingsKeys.dailyReminder: true,
      SettingsKeys.soundEffects: true,
    });
    await _pump(tester);

    final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect(switches[0].value, isFalse, reason: 'push, never set');
    expect(switches[1].value, isTrue, reason: 'reminder');
    expect(switches[2].value, isTrue, reason: 'sound');
  });

  testWidgets('lays out on a short phone', (tester) async {
    await _pump(tester, size: const Size(375, 667));
    expect(tester.takeException(), isNull);
  });
}
