// lib/repository/settings_provider.dart
//
// The student's settings, and where each one takes effect.
//
// The settings screen only shows this. Turning push on subscribes to course
// alerts; the reminder schedules a daily notification; sound and analytics
// switch their services on or off. Everything is stored per phone, so it
// survives a restart and a sign-out.
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/app_analytics.dart';
import '../services/notification_service.dart';
import '../services/quiz_sounds.dart';

/// Namespaced so a later feature cannot collide with them.
class SettingsKeys {
  static const pushNotifications = 'settings.pushNotifications';
  static const dailyReminder = 'settings.dailyReminder';
  static const reminderMinutes = 'settings.reminderMinutes';
  static const soundEffects = 'settings.soundEffects';
  static const usageAnalytics = 'settings.usageAnalytics';
}

class SettingsProvider extends ChangeNotifier {
  final NotificationService _notifications;

  SettingsProvider({NotificationService? notifications})
      : _notifications = notifications ?? NotificationService.instance {
    _ready = _load();
  }

  late final Future<void> _ready;

  /// Completes once the stored values are in.
  Future<void> get ready => _ready;

  SharedPreferences? _prefs;
  bool loaded = false;

  /// On by default: course announcements are how a student hears about a
  /// new course at all. The permission prompt still decides — see
  /// [applyForSession].
  bool push = true;

  bool dailyReminder = false;

  /// Minutes after midnight. 8:00 PM unless the student picks otherwise.
  int reminderMinutes = 20 * 60;

  bool sound = false;

  /// Off by default: consent a student has not given is the wrong default.
  bool analytics = false;

  /// The signed-in student, for the backend's copy of this phone's token.
  /// Null while signed out.
  int? _studentId;

  /// True while the permission is being asked for and this device is being
  /// registered. Home shows it: the prompt is a system dialog, and what
  /// follows it — subscribing, sending the token — is invisible otherwise.
  bool isActivating = false;

  bool get pushAvailable => _notifications.pushAvailable;
  bool get analyticsAvailable => AppAnalytics.available;

  /// What to say when the phone has notifications blocked for the app.
  static const String blockedMessage =
      "Notifications are blocked for Dr. SKM's Academy. Allow them in your "
      "phone's settings, then try again.";

  Future<void> _load() async {
    final prefs = _prefs = await SharedPreferences.getInstance();
    push = prefs.getBool(SettingsKeys.pushNotifications) ?? true;
    dailyReminder = prefs.getBool(SettingsKeys.dailyReminder) ?? false;
    reminderMinutes = prefs.getInt(SettingsKeys.reminderMinutes) ?? 20 * 60;
    sound = prefs.getBool(SettingsKeys.soundEffects) ?? false;
    analytics = prefs.getBool(SettingsKeys.usageAnalytics) ?? false;

    QuizSounds.enabled = sound;
    await AppAnalytics.setEnabled(analytics);

    loaded = true;
    notifyListeners();
  }

  /// Returns a message when the change could not be made — permission denied —
  /// so the screen can say why the switch did not stay on.
  Future<String?> setPush(bool on) async {
    await _ready;
    if (on) {
      if (!await _notifications.requestPermission()) return blockedMessage;
      await _notifications.subscribePush();
      final studentId = _studentId;
      if (studentId != null) await _notifications.registerToken(studentId);
    } else {
      await _notifications.unsubscribePush();
      // Push off means off for notifications aimed at this student too.
      await _notifications.unregisterToken();
    }
    push = on;
    await _prefs?.setBool(SettingsKeys.pushNotifications, on);
    notifyListeners();
    return null;
  }

  Future<String?> setDailyReminder(bool on) async {
    await _ready;
    if (on) {
      if (!await _notifications.requestPermission()) return blockedMessage;
      await _notifications.scheduleDailyReminder(reminderMinutes);
    } else {
      await _notifications.cancelDailyReminder();
    }
    dailyReminder = on;
    await _prefs?.setBool(SettingsKeys.dailyReminder, on);
    notifyListeners();
    return null;
  }

  Future<void> setReminderTime(int minutesOfDay) async {
    await _ready;
    reminderMinutes = minutesOfDay;
    await _prefs?.setInt(SettingsKeys.reminderMinutes, minutesOfDay);
    // Scheduling again replaces the old time; with the reminder off there is
    // nothing to move.
    if (dailyReminder) {
      await _notifications.scheduleDailyReminder(minutesOfDay);
    }
    notifyListeners();
  }

  Future<void> setSound(bool on) async {
    await _ready;
    sound = on;
    QuizSounds.enabled = on;
    await _prefs?.setBool(SettingsKeys.soundEffects, on);
    notifyListeners();
  }

  Future<void> setAnalytics(bool on) async {
    await _ready;
    analytics = on;
    await AppAnalytics.setEnabled(on);
    await _prefs?.setBool(SettingsKeys.usageAnalytics, on);
    notifyListeners();
  }

  /// Applies the stored settings for a signed-in student. Called once per
  /// session, when home first appears.
  ///
  /// This is where the notification prompt first shows — after sign-in, with
  /// the app on screen, rather than at launch. If it is refused, push is
  /// stored off so the switch tells the truth.
  ///
  /// [studentId] is who the backend files this phone's FCM token under.
  Future<void> applyForSession({int? studentId}) async {
    await _ready;
    _studentId = studentId;

    if (!push || !pushAvailable) {
      // Nothing to ask for and nothing to register: no point saying so.
      if (dailyReminder) {
        await _notifications.scheduleDailyReminder(reminderMinutes);
      }
      return;
    }

    isActivating = true;
    notifyListeners();

    if (await _notifications.requestPermission()) {
      await _notifications.subscribePush();
      if (studentId != null) await _notifications.registerToken(studentId);
    } else {
      push = false;
      await _prefs?.setBool(SettingsKeys.pushNotifications, false);
    }

    // Scheduled again each session: harmless when it is already set, and it
    // restores a reminder the system dropped.
    if (dailyReminder) {
      await _notifications.scheduleDailyReminder(reminderMinutes);
    }

    isActivating = false;
    notifyListeners();
  }

  /// A signed-out phone stops receiving course news and study reminders. The
  /// choices themselves are kept for whoever signs in next on this phone.
  Future<void> clearForSignOut() async {
    _studentId = null;
    await _notifications.unsubscribePush();
    await _notifications.unregisterToken();
    await _notifications.cancelDailyReminder();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }
}
