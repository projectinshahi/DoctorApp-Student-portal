// lib/services/app_analytics.dart
//
// Usage analytics, sent only with the student's consent from Settings.
//
// Off until then — the Android manifest also starts collection disabled, so
// nothing leaves the phone before the stored choice is read. Events carry ids
// and counts only: never a name, an email, or anything typed.
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class AppAnalytics {
  const AppAnalytics._();

  static bool _enabled = false;

  /// Firebase is configured for Android only.
  static bool get available {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setEnabled(bool on) async {
    _enabled = on;
    if (!available) return;
    try {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(on);
    } catch (error) {
      if (kDebugMode) debugPrint('ANALYTICS  not switched: $error');
    }
  }

  /// Records one event, if the student has agreed. Never awaited by callers:
  /// an analytics call must not slow down what the student is doing.
  static void log(String name, [Map<String, Object>? parameters]) {
    if (!_enabled || !available) return;
    () async {
      try {
        await FirebaseAnalytics.instance
            .logEvent(name: name, parameters: parameters);
      } catch (_) {
        // Lost events are acceptable; a crash over one is not.
      }
    }();
  }
}
