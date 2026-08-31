// lib/services/test_service.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/constant/api_constant.dart';
import '../models/quiz_model.dart' show QuizException, QuizErrorKind;
import '../models/test_model.dart';
import 'refresh_api_services.dart'; // ApiClient + SessionExpiredException

/// The six grand-test endpoints.
///
/// Errors are reported with [QuizException] rather than a second exception
/// type: the screens already know how to render one, and a test failing is
/// not a different kind of event from a quiz failing.
class TestService {
  static String get _base => '${ApiConstant.baseUrl}/users/me';

  /// 1 — Published tests for a course, with `lastAttempt` attached so the
  /// list can pick Start / Resume / View result without a second call.
  Future<List<TestSummary>> fetchTests(int courseId) async =>
      TestSummary.listFromJson(await _send('GET', '$_base/courses/$courseId/tests'));

  /// 2 — Start or resume. 201 is a fresh attempt, 200 a resumed one; both are
  /// success, and `resumed` on the body says which.
  Future<TestAttempt> startAttempt(int testId) async =>
      TestAttempt.fromJson(await _send('POST', '$_base/tests/$testId/attempts'));

  /// 3 — Answer one question. Re-sending overwrites rather than duplicating.
  Future<TestAnswerResponse> answer(
    int attemptId, {
    required int questionId,
    required String selectedOption,
  }) async =>
      TestAnswerResponse.fromJson(await _send(
        'PATCH',
        '$_base/test-attempts/$attemptId/answers/$questionId',
        body: {'selectedOption': selectedOption},
      ));

  /// Clears an answer, putting the question back to skipped.
  ///
  /// Worth having rather than forcing a guess: with negative marking, skipped
  /// scores 0 and wrong scores -0.25, so un-answering is a real move.
  Future<TestAnswerResponse> clearAnswer(
    int attemptId, {
    required int questionId,
  }) async =>
      TestAnswerResponse.fromJson(await _send(
        'DELETE',
        '$_base/test-attempts/$attemptId/answers/$questionId',
      ));

  /// 4 — Mark the paper. Safe to call twice; the second call returns the same
  /// sheet.
  Future<TestResult> submit(int attemptId) async =>
      TestResult.fromJson(await _send('POST', '$_base/test-attempts/$attemptId/submit'));

  /// Re-open a marked paper.
  Future<TestResult> fetchResult(int attemptId) async =>
      TestResult.fromJson(await _send('GET', '$_base/test-attempts/$attemptId/result'));

  /// 5 — Leaderboard. `me` comes back separately from the top N.
  Future<Leaderboard> fetchLeaderboard(int testId, {int limit = 50}) async =>
      Leaderboard.fromJson(
          await _send('GET', '$_base/tests/$testId/leaderboard?limit=$limit'));

  // ── transport ────────────────────────────────────────────────
  Future<Map<String, dynamic>> _send(
    String method,
    String url, {
    Map<String, dynamic>? body,
  }) async {
    dynamic decoded;
    int status;

    try {
      final response = switch (method) {
        'POST' => await ApiClient.post(url, body: body ?? const {}),
        'PATCH' => await ApiClient.patch(url, body: body ?? const {}),
        'DELETE' => await ApiClient.delete(url),
        _ => await ApiClient.get(url),
      };

      status = response.statusCode;
      _dump(method, url, status, response.body);
      decoded = response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
    } on SessionExpiredException catch (e) {
      throw QuizException(QuizErrorKind.sessionExpired, e.message);
    } catch (_) {
      throw QuizException(
        QuizErrorKind.network,
        'Could not reach the server. Check your connection and try again.',
      );
    }

    // 201 is a fresh attempt and 200 a resumed one — accepting only 200 here
    // would fail every first start.
    if ((status == 200 || status == 201) && decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }

    throw mapError(status, decoded);
  }

  /// A 409 on a running attempt means its time ran out and the server has
  /// just auto-submitted it. That is the designed path, not a failure, so it
  /// gets its own kind for the UI to route to the result sheet.
  static QuizException mapError(int status, dynamic body) {
    final message = (body is Map && body['error'] is Map)
        ? (body['error']['message']?.toString() ?? '')
        : (body is Map ? body['message']?.toString() ?? '' : '');
    final lower = message.toLowerCase();

    if (status == 401) {
      return QuizException(QuizErrorKind.sessionExpired,
          message.isEmpty ? 'Your session has expired. Please sign in again.' : message);
    }
    if (status == 403) {
      return QuizException(QuizErrorKind.locked,
          message.isEmpty ? 'This test is not available on your plan.' : message);
    }
    if (status == 404) {
      return QuizException(QuizErrorKind.lessonNotFound,
          message.isEmpty ? 'This test could not be found.' : message);
    }
    if (status == 409 && (lower.contains('expire') || lower.contains('submit') || lower.contains('time'))) {
      return QuizException(QuizErrorKind.attemptFinished,
          message.isEmpty ? 'Time is up — this attempt was submitted.' : message);
    }
    if (status == 409) {
      return QuizException(QuizErrorKind.noQuestions,
          message.isEmpty ? 'This test has no questions yet.' : message);
    }

    return QuizException(QuizErrorKind.network,
        message.isEmpty ? 'Something went wrong. Please try again.' : message);
  }

  /// Debug-only. Papers are large, so this prints the envelope rather than
  /// every question.
  static void _dump(String method, String url, int status, String body) {
    if (!kDebugMode) return;
    debugPrint('┌── TEST API  $method [$status]  $url');
    debugPrint('│  ${body.length > 400 ? '${body.substring(0, 400)}…' : body}');
    debugPrint('└── ${body.length} chars');
  }
}
