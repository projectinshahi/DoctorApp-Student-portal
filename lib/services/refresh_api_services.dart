// lib/services/api_client.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/constant/api_constant.dart';
import '../core/constant/local_storage.dart';

class ApiClient {
  // Prevents multiple simultaneous refresh calls if several requests
  // fail with 401 at the same time (e.g. parallel API calls on one screen)
  static Future<String>? _refreshInFlight;

  // Optional: set this from AuthProvider so ApiClient can notify it
  // when the session dies (see AuthProvider below for wiring)
  static void Function()? onSessionExpired;

  static Future<http.Response> get(String url) =>
      _sendWithAuth((token) => http.get(Uri.parse(url), headers: _headers(token)));

  static Future<http.Response> post(String url, {Map<String, dynamic>? body}) =>
      _sendWithAuth((token) => http.post(
        Uri.parse(url),
        headers: _headers(token),
        body: jsonEncode(body ?? {}),
      ));

  static Future<http.Response> put(String url, {Map<String, dynamic>? body}) =>
      _sendWithAuth((token) => http.put(
        Uri.parse(url),
        headers: _headers(token),
        body: jsonEncode(body ?? {}),
      ));

  static Future<http.Response> patch(String url, {Map<String, dynamic>? body}) =>
      _sendWithAuth((token) => http.patch(
        Uri.parse(url),
        headers: _headers(token),
        body: jsonEncode(body ?? {}),
      ));

  static Future<http.Response> delete(String url) =>
      _sendWithAuth((token) => http.delete(Uri.parse(url), headers: _headers(token)));

  static Map<String, String> _headers(String token) => {
    "Content-Type": "application/json",
    "Authorization": "Bearer $token",
  };

  static Future<http.Response> _sendWithAuth(
      Future<http.Response> Function(String accessToken) requestFn,
      ) async {
    final accessToken = await LocalStorage.getAccessToken();

    if (accessToken == null) {
      _handleSessionExpired();
      throw SessionExpiredException("Not logged in");
    }

    var response = await requestFn(accessToken);

    if (response.statusCode != 401) {
      return response;
    }

    // Got a 401 — inspect why
    Map<String, dynamic> body = {};
    try {
      body = jsonDecode(response.body);
    } catch (_) {}
    final code = body["error"]?["code"];

    // These mean the session is definitively dead — don't bother refreshing
    if (code == "SESSION_ENDED" ||
        code == "SESSION_NOT_FOUND" ||
        code == "REFRESH_TOKEN_REUSED") {
      await LocalStorage.clearAll();
      _handleSessionExpired();
      throw SessionExpiredException(
        body["error"]?["message"] ?? "Your session has ended. Please log in again.",
      );
    }

    // Otherwise assume the access token just expired naturally — refresh and retry once
    try {
      final newAccessToken = await _refreshAccessToken();
      response = await requestFn(newAccessToken);
      return response;
    } on SessionExpiredException {
      _handleSessionExpired();
      rethrow;
    } catch (e) {
      await LocalStorage.clearAll();
      _handleSessionExpired();
      throw SessionExpiredException("Session expired. Please log in again.");
    }
  }

  static Future<String> _refreshAccessToken() {
    // Dedup: if a refresh is already in progress (from a parallel request),
    // reuse its result instead of firing a second /refresh call
    _refreshInFlight ??= _doRefresh();
    return _refreshInFlight!.whenComplete(() => _refreshInFlight = null);
  }

  static Future<String> _doRefresh() async {
    final refreshToken = await LocalStorage.getRefreshToken();

    if (refreshToken == null) {
      throw SessionExpiredException("No refresh token found. Please log in again.");
    }

    final response = await http.post(
      Uri.parse(ApiConstant.refresh),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"refreshToken": refreshToken}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // Save BOTH — backend rotates the refresh token on every use
      await LocalStorage.saveAccessToken(data["accessToken"]);
      await LocalStorage.saveRefreshToken(data["refreshToken"]);

      return data["accessToken"];
    }

    final body = jsonDecode(response.body);
    throw SessionExpiredException(
      body["error"]?["message"] ?? "Session expired. Please log in again.",
    );
  }

  static void _handleSessionExpired() {
    if (onSessionExpired != null) {
      onSessionExpired!();
    }
  }
}


// lib/exceptions/session_expired_exception.dart
class SessionExpiredException implements Exception {
  final String message;
  SessionExpiredException(this.message);

  @override
  String toString() => message;
}