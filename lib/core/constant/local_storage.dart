import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class LocalStorage {
  static const String _deviceIdKey = 'device_id';
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _kHasSelectedExamKey = 'has_selected_exam';

  // ---- Device ID ----
  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_deviceIdKey);

    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString(_deviceIdKey, deviceId);
    }

    return deviceId;
  }

  /// Call this right after a successful PUT /api/selection call.
  static Future<void> setHasSelectedExam(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHasSelectedExamKey, value);
  }

  /// Returns false by default if never set (i.e. brand-new / not yet selected).
  static Future<bool> getHasSelectedExam() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kHasSelectedExamKey) ?? false;
  }

  // ---- Access Token ----
  static Future<void> saveAccessToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, token);
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  // ---- Refresh Token ----
  static Future<void> saveRefreshToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_refreshTokenKey, token);
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  // ---- Quiz progress ----
  // Survives leaving a quiz half-attempted: on the next open only the
  // questions that aren't in here are shown again.
  static String _quizKey(int lessonId) => 'quiz_progress_$lessonId';

  /// [answers] is questionId -> submitted optionId.
  static Future<void> saveQuizProgress(int lessonId, Map<int, int> answers) async {
    final prefs = await SharedPreferences.getInstance();
    if (answers.isEmpty) {
      await prefs.remove(_quizKey(lessonId));
      return;
    }
    await prefs.setString(
      _quizKey(lessonId),
      jsonEncode(answers.map((k, v) => MapEntry(k.toString(), v))),
    );
  }

  static Future<Map<int, int>> getQuizProgress(int lessonId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_quizKey(lessonId));
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(int.parse(k), (v as num).toInt()));
    } catch (_) {
      // Corrupt entry from an older build — start the attempt clean.
      await prefs.remove(_quizKey(lessonId));
      return {};
    }
  }

  static Future<void> clearQuizProgress(int lessonId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_quizKey(lessonId));
  }

  // ---- Clear all (for sign-out) ----
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    // Note: deviceId is intentionally NOT cleared — it should persist across sign-outs
  }
}