
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/device_id_helper.dart';

class LocalStorage {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _kHasSelectedExamKey = 'has_selected_exam';

  /// The last course tree, as the server sent it.
  ///
  /// Kept so the app paints chapters on launch instead of a spinner. It is
  /// content, not credentials — but it is *this account's* content, so it
  /// goes with the tokens in clearAll().
  static const String _kCourseTreeKey = 'course_tree_json';

  /// Other screens' last-known payloads, same idea as the tree: paint what we
  /// had, refresh underneath. Measured cold on device, /home took 5459ms and
  /// /saved 5010ms — the whole of which the student spent on a spinner.
  static const String homeSummaryKey = 'cache_home_summary';
  static const String savedKey = 'cache_saved';


  /// Everything written by [saveCached], so clearAll can take them all.
  static const List<String> _cacheKeys = [homeSummaryKey, savedKey];

  // ---- Device ID ----
  /// Delegates to [DeviceIdHelper], which is the single source of truth.
  ///
  /// This used to mint its own UUID, so the value the splash screen printed
  /// and the value login actually sent could be different — and only one of
  /// them is what the server binds the account to.
  static Future<String> getDeviceId() => DeviceIdHelper.getDeviceId();

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
  /// Content caches. Never credentials — these are cleared with the tokens
  /// because they are *this account's* content.
  static Future<void> saveCached(String key, String json) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, json);
    } catch (_) {
      // Caching is an optimisation; a storage failure must not fail the call
      // that produced the data.
    }
  }

  static Future<String?> getCached(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveCourseTree(String json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCourseTreeKey, json);
  }

  static Future<String?> getCourseTree() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kCourseTreeKey);
  }

  static Future<void> clearCourseTree() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCourseTreeKey);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);

    // Cached content belongs to the account that just left. Without this the
    // next student on this phone would open on the previous one's chapters,
    // home screen and bookmarks.
    await prefs.remove(_kCourseTreeKey);
    for (final key in _cacheKeys) {
      await prefs.remove(key);
    }

    // Goes with the tokens, because it answers a question about the
    // *account*, not the phone: "has this student picked a course?".
    //
    // Leaving it behind meant the next person to sign in on this device
    // inherited the previous student's answer — a fresh account, or one that
    // backed out of the picker, went straight to an empty home screen.
    // signOut() reset the field in memory but not the stored value, so it
    // came back on the next launch.
    await prefs.remove(_kHasSelectedExamKey);

    // deviceId is deliberately kept: it identifies the phone, not the
    // session, and regenerating it makes a reinstall look like a new device.
  }
}