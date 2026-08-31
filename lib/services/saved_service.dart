// lib/services/saved_service.dart
import 'dart:convert';

import '../core/constant/api_constant.dart';
import '../models/quiz_model.dart' show QuizException, QuizErrorKind;
import '../models/saved_model.dart';
import 'quiz_service.dart' show QuizService;
import 'refresh_api_services.dart'; // ApiClient + SessionExpiredException

/// Bookmarks. POST is an upsert and DELETE on something not saved answers 200,
/// so the UI can toggle optimistically without treating a double tap or a
/// stale state as an error.
class SavedService {
  static String get _questionsUrl => '${ApiConstant.baseUrl}/users/me/saved-questions';
  static String get _lessonsUrl => '${ApiConstant.baseUrl}/users/me/saved-lessons';

  static String get _allUrl => '${ApiConstant.baseUrl}/users/me/saved';

  /// Everything in one call, with the full `counts` set attached.
  ///
  /// `type` accepts all | question | video | text | quiz. NOT `note` — notes
  /// are stored as `text`, and asking for `note` is a 400, not an empty list.
  Future<SavedBundle> fetchAll({String type = 'all'}) async =>
      SavedBundle.fromJson(await _send('GET', '$_allUrl?type=$type'));

  Future<SavedQuestionsResponse> fetchQuestions() async =>
      SavedQuestionsResponse.fromJson(await _send('GET', _questionsUrl));

  /// Returns the new total, so the bookmark badge updates with no extra call.
  Future<int> saveQuestion(int questionId) async {
    final json = await _send('POST', _questionsUrl, body: {'questionId': questionId});
    return _count(json);
  }

  Future<int> unsaveQuestion(int questionId) async =>
      _count(await _send('DELETE', '$_questionsUrl/$questionId'));

  Future<SavedLessonsResponse> fetchLessons() async =>
      SavedLessonsResponse.fromJson(await _send('GET', _lessonsUrl));

  Future<int> saveLesson(int lessonId) async {
    final json = await _send('POST', _lessonsUrl, body: {'lessonId': lessonId});
    return _count(json);
  }

  Future<int> unsaveLesson(int lessonId) async =>
      _count(await _send('DELETE', '$_lessonsUrl/$lessonId'));

  /// `count` is documented on every response. -1 means the server didn't send
  /// one this time — callers refetch rather than displaying a wrong number.
  static int _count(Map<String, dynamic> json) {
    final raw = json['count'];
    if (raw is num) return raw.toInt();
    return int.tryParse('$raw') ?? -1;
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String url, {
    Map<String, dynamic>? body,
  }) async {
    dynamic decoded;
    int status;

    try {
      final response = switch (method) {
        'POST' => await ApiClient.post(url, body: body),
        'DELETE' => await ApiClient.delete(url),
        _ => await ApiClient.get(url),
      };

      status = response.statusCode;
      decoded = response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
    } on SessionExpiredException catch (e) {
      throw QuizException(QuizErrorKind.sessionExpired, e.message);
    } catch (_) {
      throw QuizException(
        QuizErrorKind.network,
        'Could not reach the server. Check your connection and try again.',
      );
    }

    // 204 is a legal DELETE response and carries no body — not a failure.
    if (status == 204) return const {};
    if (status >= 200 && status < 300 && decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }

    // Bookmarks run the same gates as every other lesson call, so they reuse
    // the quiz error mapping rather than inventing a second vocabulary for
    // the identical 403s and 5xx.
    throw QuizService.mapError(status, decoded);
  }
}
