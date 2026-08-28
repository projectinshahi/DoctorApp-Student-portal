// lib/services/quiz_service.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/constant/api_constant.dart';
import '../models/quiz_model.dart';
import 'refresh_api_services.dart'; // ApiClient + SessionExpiredException

/// The five attempt endpoints. Nothing here computes a mark — every number
/// the student sees comes back from the server, because the answer key is
/// never in a response they could read before committing.
class QuizService {
  static String _attemptsUrl(int lessonId) =>
      '${ApiConstant.baseUrl}/users/me/lessons/$lessonId/quiz-attempts';

  static String _attemptUrl(int attemptId) =>
      '${ApiConstant.baseUrl}/users/me/quiz-attempts/$attemptId';

  static String _answersUrl(int attemptId) => '${_attemptUrl(attemptId)}/answers';

  static String _finishUrl(int attemptId) => '${_attemptUrl(attemptId)}/finish';

  /// 1 — Start, or pick up an unfinished attempt. No body.
  /// 201 = fresh, 200 = resumed; both are success, and `resumed` on the
  /// response says which. This call also runs every lesson gate, so there is
  /// no separate lesson fetch to make first.
  Future<QuizAttempt> startAttempt(int lessonId) async {
    final json = await _post(_attemptsUrl(lessonId), const {});
    _dumpAttempt(lessonId, json);
    return QuizAttempt.fromJson(json);
  }

  /// 2 — Answer one question. Returns that question's key and explanation
  /// straight away. Re-posting the same questionId overwrites the earlier
  /// pick; it is not an error and does not duplicate.
  Future<QuizAnswerResponse> answerQuestion(
    int attemptId, {
    required int questionId,
    required int optionId,
  }) async {
    final json = await _post(
      _answersUrl(attemptId),
      {'questionId': questionId, 'optionId': optionId},
    );
    return QuizAnswerResponse.fromJson(json);
  }

  /// 3 — Score the attempt. Safe to call twice: the second call returns the
  /// same review with the original completedAt.
  Future<QuizAttemptResult> finishAttempt(int attemptId) async {
    return QuizAttemptResult.fromJson(await _post(_finishUrl(attemptId), const {}));
  }

  /// 4 — Resume or review. Branch on `completed`: false gives questions and
  /// the answers so far with no key, true gives the full review.
  Future<QuizAttempt> fetchAttempt(int attemptId) async {
    return QuizAttempt.fromJson(await _get(_attemptUrl(attemptId)));
  }

  /// 5 — Past attempts for this lesson, newest first. Summary rows only.
  Future<List<QuizAttemptSummary>> fetchHistory(int lessonId) async {
    return QuizAttemptSummary.listFromJson(await _get(_attemptsUrl(lessonId)));
  }

  /// 6 — Attempts across the whole course, for the QBank "Continue MCQs"
  /// card. Per-lesson history can't answer "what did they leave half-done
  /// anywhere?" without walking every lesson.
  Future<List<InProgressAttempt>> fetchAttemptsByStatus({
    String status = 'in_progress',
  }) async {
    final json = await _get(
      '${ApiConstant.baseUrl}/users/me/quiz-attempts?status=$status',
    );
    return InProgressAttempt.listFromJson(json);
  }

  /// Debug-only dump of the attempt the server handed back: every question,
  /// its options, and which fields actually arrived. `fields sent` is the
  /// tell — `correctOptionId` and `explanation` are absent here by design,
  /// and only appear once a question is answered.
  static void _dumpAttempt(int lessonId, Map<String, dynamic> json) {
    if (!kDebugMode) return;

    final quiz = json['quiz'];
    final questions = (json['questions'] as List?) ?? const [];

    debugPrint('════════ QUIZ ATTEMPT — lesson $lessonId ════════');
    debugPrint('url            : ${_attemptsUrl(lessonId)}');
    debugPrint('attemptId      : ${json['attemptId']}');
    debugPrint('resumed        : ${json['resumed']}');
    debugPrint('answered       : ${json['answered']}');
    debugPrint('quiz           : ${quiz is Map ? quiz['title'] : '—'}');
    debugPrint('totalQuestions : ${json['totalQuestions'] ?? questions.length}');
    debugPrint('totalMarks     : ${json['totalMarks']}');
    debugPrint('top-level keys : ${json.keys.toList()}');

    for (var i = 0; i < questions.length; i++) {
      final q = Map<String, dynamic>.from(questions[i] as Map);
      final options = (q['options'] as List?) ?? const [];

      debugPrint('');
      debugPrint('── Q${i + 1}  (id ${q['id']}) ──────────────────────────');
      debugPrint('   question       : ${q['questionText']}');
      debugPrint('   difficulty     : ${q['difficulty'] ?? '—'}');
      debugPrint('   marks          : +${q['marksCorrect']} / ${q['marksIncorrect']}');
      debugPrint('   image          : ${q['questionImageUrl'] ?? '—'}');
      debugPrint('   fields sent    : ${q.keys.toList()}');
      debugPrint('   options (${options.length}):');

      for (var j = 0; j < options.length; j++) {
        final o = Map<String, dynamic>.from(options[j] as Map);
        debugPrint('     ${String.fromCharCode(65 + j)}. [id ${o['id']}] ${o['optionText']}');
      }
    }

    debugPrint('═════════════════════════════════════════════════════');
  }

  /// Debug-only: the raw body of every quiz API call, exactly as the server
  /// sent it. Pretty-printed when it's JSON — logcat truncates long lines, so
  /// it goes out one line at a time rather than as one blob.
  static void _dumpResponse(String url, int status, String body) {
    if (!kDebugMode) return;

    debugPrint('┌── API RESPONSE  [$status]  $url');

    if (body.isEmpty) {
      debugPrint('│  (empty body)');
    } else {
      String text;
      try {
        text = const JsonEncoder.withIndent('  ').convert(jsonDecode(body));
      } catch (_) {
        text = body; // not JSON — print it as-is
      }
      for (final line in text.split('\n')) {
        debugPrint('│  $line');
      }
    }

    debugPrint('└── ${body.length} chars');
  }

  Future<Map<String, dynamic>> _post(String url, Map<String, dynamic> body) async {
    dynamic decoded;
    int status;

    try {
      final response = await ApiClient.post(url, body: body);
      status = response.statusCode;
      _dumpResponse(url, response.statusCode, response.body);
      decoded = response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
    } on SessionExpiredException catch (e) {
      throw QuizException(QuizErrorKind.sessionExpired, e.message);
    } catch (_) {
      throw QuizException(
        QuizErrorKind.network,
        'Could not reach the server. Check your connection and try again.',
      );
    }

    // 201 is a fresh attempt, 200 a resumed one. Accepting only 200 here
    // would fail every first-time start.
    if ((status == 200 || status == 201) && decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }

    throw mapError(status, decoded);
  }

  Future<Map<String, dynamic>> _get(String url) async {
    dynamic body;
    int status;

    try {
      final response = await ApiClient.get(url);
      status = response.statusCode;
      _dumpResponse(url, response.statusCode, response.body);
      body = response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
    } on SessionExpiredException catch (e) {
      throw QuizException(QuizErrorKind.sessionExpired, e.message);
    } catch (_) {
      throw QuizException(
        QuizErrorKind.network,
        'Could not reach the server. Check your connection and try again.',
      );
    }

    if (status == 200 && body is Map) {
      return Map<String, dynamic>.from(body);
    }

    throw mapError(status, body);
  }

  /// The complete failure set from the endpoint spec. Anything unmapped falls
  /// through to [QuizErrorKind.network] with the server's own message.
  static QuizException mapError(int status, dynamic body) {
    final map = body is Map ? body : const {};
    final error = map['error'] is Map ? map['error'] as Map : const {};
    final message = (error['message'] ?? map['message'] ?? '').toString();
    final lower = message.toLowerCase();

    final rawPlans = map['requiredPlans'] ?? error['requiredPlans'];
    final plans = rawPlans is List
        ? rawPlans.map((p) => RequiredPlanModel.fromJson(Map<String, dynamic>.from(p))).toList()
        : const <RequiredPlanModel>[];

    if (status == 404) {
      // "Attempt not found" is also what another student's attempt returns —
      // same response, deliberately, so ids can't be probed.
      if (lower.contains('attempt')) {
        return QuizException(
          QuizErrorKind.attemptNotFound,
          message.isEmpty ? 'Attempt not found' : message,
        );
      }
      return QuizException(
        QuizErrorKind.lessonNotFound,
        message.isEmpty ? 'Lesson not found' : message,
      );
    }

    if (status == 403) {
      if (plans.isNotEmpty || lower.contains('locked') || lower.contains('subscribe')) {
        return QuizException(
          QuizErrorKind.locked,
          message.isEmpty ? 'This lesson is locked. Subscribe to unlock it.' : message,
          requiredPlans: plans,
        );
      }
      return QuizException(
        QuizErrorKind.notInCourse,
        message.isEmpty ? 'This lesson is not part of your selected course' : message,
      );
    }

    if (status == 409) {
      if (lower.contains('select a course')) {
        return QuizException(QuizErrorKind.noCourseSelected, message);
      }
      // Order matters: "This quiz has no questions yet" also contains "no
      // quiz" once lowercased in some phrasings, so test the narrower one
      // first or an empty quiz reads as an unlinked one.
      if (lower.contains('no questions')) {
        return QuizException(QuizErrorKind.noQuestions, message);
      }
      if (lower.contains('no quiz')) {
        return QuizException(QuizErrorKind.noQuizLinked, message);
      }
      if (lower.contains('already finished')) {
        return QuizException(QuizErrorKind.attemptFinished, message);
      }
      if (lower.contains('inactive')) {
        return QuizException(QuizErrorKind.quizInactive, message);
      }
    }

    // 400: bad ids. Not recoverable by retrying the same call, but not a
    // dead end either — the screen offers a reload.
    if (status == 400) {
      return QuizException(
        QuizErrorKind.network,
        message.isEmpty ? 'That answer could not be recorded.' : message,
      );
    }

    // 5xx: nothing wrong with the request or the connection — the server
    // itself failed. Saying "check your connection" here sends people
    // chasing a problem that isn't theirs.
    if (status >= 500) {
      return QuizException(
        QuizErrorKind.serverError,
        message.isEmpty ? 'The server could not load this quiz.' : message,
      );
    }

    return QuizException(
      QuizErrorKind.network,
      message.isEmpty ? 'Something went wrong. Please try again.' : message,
    );
  }
}
