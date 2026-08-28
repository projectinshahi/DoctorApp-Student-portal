
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

  // ---- Clear all (for sign-out) ----
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    // Note: deviceId is intentionally NOT cleared — it should persist across sign-outs
  }
}