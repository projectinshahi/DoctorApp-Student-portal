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
  /// Called when the session is definitively over. The message is the
  /// server's own — "You were signed out because your account was accessed on
  /// another device" tells the student something a generic "session expired"
  /// does not, and it is the whole reason the backend distinguishes these
  /// codes.
  static void Function(String message)? onSessionExpired;

  /// Fired the first time an authenticated request actually succeeds.
  ///
  /// This is what separates "the session died while you were using the app"
  /// from "you opened the app and the token was already dead". A cold start
  /// with a revoked session never gets a 200, so it never fires — and the
  /// student is not met by a modal before touching anything.
  static void Function()? onAuthenticatedSuccess;

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
      _handleSessionExpired("Please log in to continue.");
      throw SessionExpiredException("Not logged in");
    }

    var response = await requestFn(accessToken);

    // 403 is its own ending: the account is disabled, and no amount of
    // refreshing fixes that. Without this the response fell through as if it
    // were ordinary data.
    if (response.statusCode == 403) {
      final blocked = _errorCode(response) == "ACCOUNT_BLOCKED";
      if (blocked) {
        await LocalStorage.clearAll();
        final message = _errorMessage(response) ??
            "This account has been disabled. Please contact support.";
        _handleSessionExpired(message);
        throw SessionExpiredException(message);
      }
      // Any other 403 is a permission answer about one resource — a locked
      // lesson, someone else's comment — and belongs to the caller.
      return response;
    }

    if (response.statusCode != 401) {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        onAuthenticatedSuccess?.call();
      }
      return response;
    }

    // Got a 401 — three different things share that status, and only one of
    // them is worth a refresh.
    final code = _errorCode(response);

    // These mean the session is definitively dead. Refreshing here is the bug
    // this design exists to prevent: /refresh answers 401 too, so the app
    // would spin instead of telling the student why they were signed out.
    if (code == "SESSION_ENDED" ||
        code == "SESSION_NOT_FOUND" ||
        code == "REFRESH_TOKEN_REUSED") {
      await LocalStorage.clearAll();
      final message = _errorMessage(response) ??
          "Your session has ended. Please log in again.";
      _handleSessionExpired(message);
      throw SessionExpiredException(message);
    }

    // Otherwise assume the access token just expired naturally — refresh and retry once
    try {
      final newAccessToken = await _refreshAccessToken();
      response = await requestFn(newAccessToken);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        onAuthenticatedSuccess?.call();
      }
      return response;
    } on SessionExpiredException catch (e) {
      _handleSessionExpired(e.message);
      rethrow;
    } catch (e) {
      await LocalStorage.clearAll();
      const message = "Session expired. Please log in again.";
      _handleSessionExpired(message);
      throw SessionExpiredException(message);
    }
  }

  /// The server's `error.code`, or null on a body that is not the usual
  /// envelope.
  static String? _errorCode(http.Response response) =>
      _error(response)?["code"]?.toString();

  static String? _errorMessage(http.Response response) {
    final message = _error(response)?["message"]?.toString();
    return (message == null || message.isEmpty) ? null : message;
  }

  static Map<String, dynamic>? _error(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body["error"] is Map) {
        return Map<String, dynamic>.from(body["error"] as Map);
      }
    } catch (_) {
      // A gateway error page is not JSON. Not knowing the code is fine; it
      // just means no special handling.
    }
    return null;
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

  static void _handleSessionExpired(String message) {
    onSessionExpired?.call(message);
  }
}


// lib/exceptions/session_expired_exception.dart
class SessionExpiredException implements Exception {
  final String message;
  SessionExpiredException(this.message);

  @override
  String toString() => message;
}