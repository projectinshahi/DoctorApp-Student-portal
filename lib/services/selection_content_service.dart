// lib/services/selection_content_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/constant/local_storage.dart';
import '../models/selection_content_model.dart';

class SelectionContentResult {
  final bool isSuccess;
  final SelectionContentModel? content;

  /// The response exactly as it arrived, for writing to disk. The model has
  /// no toJson, and replaying the server's own bytes cannot drift from it.
  final String? rawJson;
  final String? errorMessage;
  final bool sessionExpired; // true when refresh also failed — caller should log out

  SelectionContentResult.success(this.content, {this.rawJson})
      : isSuccess = true,
        errorMessage = null,
        sessionExpired = false;

  SelectionContentResult.failure(this.errorMessage, {this.sessionExpired = false})
      : isSuccess = false,
        content = null,
        rawJson = null;
}

class SelectionContentService {
  static const String _baseUrl = 'https://doctorapp-backend-30gd.onrender.com/api';

  Future<SelectionContentResult> fetchSelectionContent() async {
    var token = await LocalStorage.getAccessToken();

    if (token == null || token.isEmpty) {
      return SelectionContentResult.failure('Not logged in. Please log in again.', sessionExpired: true);
    }

    var response = await _request(token);

    // ── If the access token expired, try refreshing once, then retry the call ──
    if (response.statusCode == 401) {
      final refreshed = await _tryRefreshToken();
      if (!refreshed) {
        return SelectionContentResult.failure('Your session has ended. Please log in again.', sessionExpired: true);
      }

      token = await LocalStorage.getAccessToken();
      response = await _request(token!);

      if (response.statusCode == 401) {
        return SelectionContentResult.failure('Your session has ended. Please log in again.', sessionExpired: true);
      }
    }

    final data = response.body.isNotEmpty ? jsonDecode(response.body) : {};


    if (response.statusCode == 200) {
      return SelectionContentResult.success(
        SelectionContentModel.fromJson(data),
        rawJson: response.body,
      );
    }

    final message = (data is Map && data['error'] is Map)
        ? (data['error']['message'] ?? 'Failed to load selected course content')
        : 'Failed to load selected course content';
    return SelectionContentResult.failure(message);
  }

  Future<http.Response> _request(String token) {
    return http.get(
      Uri.parse('$_baseUrl/users/me/selection/content'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
  }

  /// Calls the refresh-token endpoint and saves the new tokens on success.
  /// Returns true if refresh succeeded, false otherwise.
  Future<bool> _tryRefreshToken() async {
    final refreshToken = await LocalStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      if (response.statusCode != 200) return false;

      final data = jsonDecode(response.body);
      final newAccessToken = data['accessToken'];
      final newRefreshToken = data['refreshToken'];

      if (newAccessToken == null) return false;

      await LocalStorage.saveAccessToken(newAccessToken);
      if (newRefreshToken != null) {
        await LocalStorage.saveRefreshToken(newRefreshToken);
      }

      return true;
    } catch (_) {
      return false;
    }
  }
}