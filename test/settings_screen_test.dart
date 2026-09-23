import 'package:dr_app/repository/settings_provider.dart';
import 'package:dr_app/services/notification_service.dart';
import 'package:dr_app/services/quiz_sounds.dart';
import 'package:dr_app/view/Home/profile/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stands in for the plugins, which have no platform side under test, and
/// records what the settings asked of them.
class FakeNotifications extends NotificationService {
  bool available = true;
  bool grant = true;
  final List<String> calls = [];

  @override
  bool get pushAvailable => available;

  @override
  Future<bool> requestPermission() async {
    calls.add('permission');
    return grant;
  }

  @override
  Future<void> subscribePush() async => calls.add('subscribe');

  @override
  Future<void> unsubscribePush() async => calls.add('unsubscribe');

  @override
  Future<void> scheduleDailyReminder(int minutesOfDay) async =>
      calls.add('schedule $minutesOfDay');

  @override
  Future<void> cancelDailyReminder() async => calls.add('cancel');

  @override
  Future<void> registerToken(int studentId) async =>
      calls.add('token $studentId');

  @override
  Future<void> unregisterToken() async => calls.add('unregister');
}

Future<SettingsProvider> _pump(
  WidgetTester tester, {
  FakeNotifications? notifications,
  Size size = const Size(440, 956),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final settings =
      SettingsProvider(notifications: notifications ?? FakeNotifications());
  await settings.ready;

  await tester.pumpWidget(
    ChangeNotifierProvider<SettingsProvider>.value(
      value: settings,
      child: ScreenUtilInit(
        designSize: const Size(440, 956),
        minTextAdapt: true,
        builder: (context, _) => const MaterialApp(home: SettingsScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return settings;
}

Switch _switchFor(WidgetTester tester, String title) => tester.widget<Switch>(
      find.descendant(
        of: find.ancestor(of: find.text(title), matching: find.byType(Row)).first,
        matching: find.byType(Switch),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    QuizSounds.enabled = false;
  });

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

  testWidgets('course alerts start on; everything else starts off',
      (tester) async {
    await _pump(tester);

    expect(_switchFor(tester, 'Push notification').value, isTrue);
    expect(_switchFor(tester, 'Daily study reminder').value, isFalse);
    expect(_switchFor(tester, 'Sound effect').value, isFalse);
    // Consent a student has not given is never the default.
    expect(_switchFor(tester, 'Usage analytics').value, isFalse);
  });

  testWidgets('turning the reminder on schedules it and offers the time',
      (tester) async {
    final notifications = FakeNotifications();
    await _pump(tester, notifications: notifications);
    expect(find.text('Reminder time'), findsNothing);

    await tester.tap(find.byWidget(_switchFor(tester, 'Daily study reminder')));
    await tester.pumpAndSettle();

    expect(notifications.calls, ['permission', 'schedule 1200']);
    expect(_switchFor(tester, 'Daily study reminder').value, isTrue);
    expect(find.text('Reminder time'), findsOneWidget);
    expect(find.text('8:00 PM'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(SettingsKeys.dailyReminder), isTrue);
  });

  testWidgets('a refused permission leaves the reminder off, and says why',
      (tester) async {
    final notifications = FakeNotifications()..grant = false;
    await _pump(tester, notifications: notifications);

    await tester.tap(find.byWidget(_switchFor(tester, 'Daily study reminder')));
    await tester.pumpAndSettle();

    expect(_switchFor(tester, 'Daily study reminder').value, isFalse);
    expect(notifications.calls, isNot(contains('schedule 1200')));
    expect(find.textContaining('Allow them'), findsOneWidget);
  });

  testWidgets('turning course alerts off unsubscribes', (tester) async {
    final notifications = FakeNotifications();
    await _pump(tester, notifications: notifications);

    await tester.tap(find.byWidget(_switchFor(tester, 'Push notification')));
    await tester.pumpAndSettle();

    expect(notifications.calls, ['unsubscribe', 'unregister']);
    expect(_switchFor(tester, 'Push notification').value, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(SettingsKeys.pushNotifications), isFalse);
  });

  testWidgets('the sound switch turns quiz sounds on', (tester) async {
    await _pump(tester);
    expect(QuizSounds.enabled, isFalse);

    await tester.tap(find.byWidget(_switchFor(tester, 'Sound effect')));
    await tester.pumpAndSettle();

    expect(QuizSounds.enabled, isTrue);
  });

  testWidgets('on a phone without push, the switch is disabled and says so',
      (tester) async {
    await _pump(tester, notifications: FakeNotifications()..available = false);

    final push = _switchFor(tester, 'Push notification');
    expect(push.onChanged, isNull);
    expect(push.value, isFalse);
    expect(find.text('Not available on this device yet'), findsWidgets);
  });

  testWidgets('stored values are shown, not the defaults', (tester) async {
    SharedPreferences.setMockInitialValues({
      SettingsKeys.pushNotifications: false,
      SettingsKeys.dailyReminder: true,
      SettingsKeys.reminderMinutes: 7 * 60 + 30,
      SettingsKeys.soundEffects: true,
    });
    await _pump(tester);

    expect(_switchFor(tester, 'Push notification').value, isFalse);
    expect(_switchFor(tester, 'Daily study reminder').value, isTrue);
    expect(_switchFor(tester, 'Sound effect').value, isTrue);
    expect(find.text('7:30 AM'), findsOneWidget);
  });

  testWidgets('lays out on a short phone', (tester) async {
    await _pump(tester, size: const Size(375, 667));
    expect(tester.takeException(), isNull);
  });
}
