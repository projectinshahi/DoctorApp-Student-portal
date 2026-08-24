// lib/services/quiz_service.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/constant/api_constant.dart';
import '../models/quiz_model.dart';
import 'refresh_api_services.dart'; // ApiClient + SessionExpiredException

class QuizService {
  static String _lessonUrl(int lessonId) =>
      '${ApiConstant.baseUrl}/users/me/lessons/$lessonId';

  static String _questionsUrl(int lessonId) =>
      '${ApiConstant.baseUrl}/users/me/lessons/$lessonId/quiz-questions';

  /// Step 1 — detect a quiz lesson. Also carries `locked` / `requiredPlans`.
  Future<QuizLessonDetail> fetchLesson(int lessonId) async {
    return QuizLessonDetail.fromJson(await _get(_lessonUrl(lessonId)));
  }

  /// Step 2 — the questions. Never call this for a locked lesson.
  Future<QuizQuestionsModel> fetchQuestions(int lessonId) async {
    final json = await _get(_questionsUrl(lessonId));
    _dumpQuestions(lessonId, json);
    return QuizQuestionsModel.fromJson(json);
  }

  /// Debug-only dump of exactly what the API returned: every question, its
  /// options, and which fields were actually sent. `fields sent` is the tell —
  /// if `correctOptionId` / `explanation` aren't in that list, the app was
  /// never given the answer key and cannot reveal or score anything.
  static void _dumpQuestions(int lessonId, Map<String, dynamic> json) {
    if (!kDebugMode) return;

    final quiz = json['quiz'];
    final questions = (json['questions'] as List?) ?? const [];

    debugPrint('════════ QUIZ API RESPONSE — lesson $lessonId ════════');
    debugPrint('url            : ${_questionsUrl(lessonId)}');
    debugPrint('quiz           : ${quiz is Map ? quiz['title'] : '—'}');
    debugPrint('totalQuestions : ${json['totalQuestions'] ?? questions.length}');
    debugPrint('totalMarks     : ${json['totalMarks']}');
    debugPrint('top-level keys : ${json.keys.toList()}');

    var withKey = 0;

    for (var i = 0; i < questions.length; i++) {
      final q = Map<String, dynamic>.from(questions[i] as Map);
      final options = (q['options'] as List?) ?? const [];
      final hasKey = q['correctOptionId'] != null ||
          options.any((o) => o is Map && o['isCorrect'] == true);
      if (hasKey) withKey++;

      debugPrint('');
      debugPrint('── Q${i + 1}  (id ${q['id']}) ──────────────────────────');
      debugPrint('   question       : ${q['questionText']}');
      debugPrint('   difficulty     : ${q['difficulty'] ?? '—'}');
      debugPrint('   marks          : +${q['marksCorrect']} / ${q['marksIncorrect']}');
      debugPrint('   correctOptionId: ${q['correctOptionId'] ?? '✗ NOT SENT'}');
      debugPrint('   explanation    : ${q['explanation'] ?? '✗ NOT SENT'}');
      debugPrint('   image          : ${q['questionImageUrl'] ?? '—'}');
      debugPrint('   fields sent    : ${q.keys.toList()}');
      debugPrint('   options (${options.length}):');

      for (var j = 0; j < options.length; j++) {
        final o = Map<String, dynamic>.from(options[j] as Map);
        final letter = String.fromCharCode(65 + j);
        final flag = o['isCorrect'] == true ? '   ← CORRECT' : '';
        debugPrint('     $letter. [id ${o['id']}] ${o['optionText']}$flag');
      }

      if (options.isNotEmpty) {
        final first = Map<String, dynamic>.from(options.first as Map);
        debugPrint('   option fields  : ${first.keys.toList()}');
      }
    }

    debugPrint('');
    debugPrint('answer key present on $withKey of ${questions.length} questions');
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
      if (lower.contains('no quiz')) {
        return QuizException(QuizErrorKind.noQuizLinked, message);
      }
      if (lower.contains('inactive')) {
        return QuizException(QuizErrorKind.quizInactive, message);
      }
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
