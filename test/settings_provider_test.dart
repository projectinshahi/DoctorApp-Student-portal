import 'package:dr_app/repository/settings_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_screen_test.dart' show FakeNotifications;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('starting a session', () {
    test('course alerts on and allowed: subscribes', () async {
      final notifications = FakeNotifications();
      await SettingsProvider(notifications: notifications).applyForSession();

      expect(notifications.calls, ['permission', 'subscribe']);
    });

    test('with a student signed in, the token goes to the backend', () async {
      final notifications = FakeNotifications();
      await SettingsProvider(notifications: notifications)
          .applyForSession(studentId: 41);

      expect(notifications.calls, ['permission', 'subscribe', 'token 41']);
    });

    test('refused at the prompt: no token is sent either', () async {
      final notifications = FakeNotifications()..grant = false;
      await SettingsProvider(notifications: notifications)
          .applyForSession(studentId: 41);

      expect(notifications.calls, isNot(contains('token 41')));
    });

    test('refused at the prompt: push is stored off, so the switch is true',
        () async {
      final notifications = FakeNotifications()..grant = false;
      final settings = SettingsProvider(notifications: notifications);
      await settings.applyForSession();

      expect(settings.push, isFalse);
      expect(notifications.calls, isNot(contains('subscribe')));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(SettingsKeys.pushNotifications), isFalse);
    });

    test('a phone without push is not asked about it', () async {
      final notifications = FakeNotifications()..available = false;
      await SettingsProvider(notifications: notifications).applyForSession();

      expect(notifications.calls, isEmpty);
    });

    test('a reminder that was on is scheduled again', () async {
      SharedPreferences.setMockInitialValues({
        SettingsKeys.pushNotifications: false,
        SettingsKeys.dailyReminder: true,
        SettingsKeys.reminderMinutes: 6 * 60,
      });
      final notifications = FakeNotifications();
      await SettingsProvider(notifications: notifications).applyForSession();

      expect(notifications.calls, ['schedule 360']);
    });
  });

  test('signing out stops alerts and the reminder', () async {
    final notifications = FakeNotifications();
    await SettingsProvider(notifications: notifications).clearForSignOut();

    // The token is deleted, not just forgotten: the backend still holds it
    // against this student, and the next one to sign in here would get
    // their notifications.
    expect(notifications.calls, ['unsubscribe', 'unregister', 'cancel']);
  });

  group('the push switch and the token', () {
    test('off withdraws the token; on sends it again for the same student',
        () async {
      final notifications = FakeNotifications();
      final settings = SettingsProvider(notifications: notifications);
      await settings.applyForSession(studentId: 41);
      notifications.calls.clear();

      await settings.setPush(false);
      expect(notifications.calls, ['unsubscribe', 'unregister']);

      notifications.calls.clear();
      await settings.setPush(true);
      expect(notifications.calls, ['permission', 'subscribe', 'token 41']);
    });

    test('after sign-out, turning push on sends no token', () async {
      final notifications = FakeNotifications();
      final settings = SettingsProvider(notifications: notifications);
      await settings.applyForSession(studentId: 41);
      await settings.clearForSignOut();
      notifications.calls.clear();

      await settings.setPush(true);
      expect(notifications.calls, isNot(contains('token 41')));
    });
  });

  group('the reminder time', () {
    test('moves a reminder that is on', () async {
      final notifications = FakeNotifications();
      final settings = SettingsProvider(notifications: notifications);
      await settings.setDailyReminder(true);
      notifications.calls.clear();

      await settings.setReminderTime(21 * 60 + 15);

      expect(notifications.calls, ['schedule 1275']);
      expect(settings.reminderMinutes, 1275);
    });

    test('is only remembered while the reminder is off', () async {
      final notifications = FakeNotifications();
      final settings = SettingsProvider(notifications: notifications);

      await settings.setReminderTime(9 * 60);

      expect(notifications.calls, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(SettingsKeys.reminderMinutes), 540);
    });
  });
}
