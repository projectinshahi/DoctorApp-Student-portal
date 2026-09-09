import 'dart:async';
// lib/services/daily_quiz_service.dart
import 'dart:convert';

import '../core/constant/local_storage.dart';

import 'package:flutter/foundation.dart';

import '../core/constant/api_constant.dart';
import '../models/daily_quiz_model.dart';
import '../models/home_summary_model.dart';
import 'refresh_api_services.dart'; // ApiClient + SessionExpiredException

enum DailyQuizErrorKind {
  signedOut,

  /// 409 — already answered this question, or already finished today.
  alreadyDone,

  /// 400 — that question is not in today's set.
  invalid,

  network,
}

class DailyQuizException implements Exception {
  final DailyQuizErrorKind kind;
  final String message;

  const DailyQuizException(this.kind, this.message);

  @override
  String toString() => message;
}

class DailyQuizService {
  static String get _base => '${ApiConstant.baseUrl}/users/me';

  /// The home payload. **Read-only** — this is the one call the home screen
  /// makes, precisely because it starts nothing.
  ///
  /// Carries the daily-quiz summary and the in-progress videos together,
  /// each video with its own `videoUrl`, so a Continue Watching card can
  /// start playing without a second request.
  Future<HomeSummary> fetchHome() async {
    final json = await _send('GET', '$_base/home');
    // Written for the *next* launch, not awaited: the caller has its data.
    unawaited(
        LocalStorage.saveCached(LocalStorage.homeSummaryKey, jsonEncode(json)));
    return HomeSummary.fromJson(json);
  }

  /// Today's set.
  ///
  /// **This call creates the attempt.** Only ever call it when the student
  /// has chosen to open the quiz — never on app boot and never from the home
  /// screen, or a student who merely opened the app ends the day with an
  /// unfinished quiz and a broken streak.
  ///
  /// Safe to call repeatedly: the set is frozen by (courseId, date), so a
  /// refetch returns the identical ten. Pull-to-refresh cannot reroll it.
  Future<DailyQuizSet> fetchToday(int courseId) async =>
      DailyQuizSet.fromJson(await _send('GET', '$_base/courses/$courseId/daily-quiz'));

  /// Answers one question. The key comes back here and only here.
  Future<DailyQuizAnswerResult> answer(
    int courseId, {
    required int questionId,
    required int optionId,
  }) async =>
      DailyQuizAnswerResult.fromJson(await _send(
        'POST',
        '$_base/courses/$courseId/daily-quiz/answers',
        body: {'questionId': questionId, 'optionId': optionId},
      ));

  /// Marks the day. Safe to call twice — it returns the same sheet rather
  /// than a 409, which matters because finishing the last question and
  /// tapping Finish can both happen.
  Future<DailyQuizResult> finish(int courseId) async => DailyQuizResult.fromJson(
      await _send('POST', '$_base/courses/$courseId/daily-quiz/finish'));

  Future<DailyQuizHistory> fetchHistory(int courseId, {int days = 30}) async =>
      DailyQuizHistory.fromJson(await _send(
          'GET', '$_base/courses/$courseId/daily-quiz/history?days=$days'));

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
        _ => await ApiClient.get(url),
      };

      status = response.statusCode;
      _dump(method, url, status, response.body);
      decoded = response.body.isNotEmpty
          ? jsonDecode(response.body)
          : <String, dynamic>{};
    } on SessionExpiredException catch (e) {
      throw DailyQuizException(DailyQuizErrorKind.signedOut, e.message);
    } catch (_) {
      throw const DailyQuizException(
        DailyQuizErrorKind.network,
        'Could not reach the server. Check your connection and try again.',
      );
    }

    if ((status == 200 || status == 201) && decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }

    throw mapError(status, decoded);
  }

  @visibleForTesting
  static DailyQuizException mapError(int status, dynamic body) {
    final message = (body is Map && body['error'] is Map)
        ? (body['error']['message']?.toString() ?? '')
        : (body is Map ? body['message']?.toString() ?? '' : '');

    if (status == 401) {
      return DailyQuizException(DailyQuizErrorKind.signedOut,
          message.isEmpty ? 'Sign in to take today\'s quiz.' : message);
    }
    if (status == 409) {
      // Covers "already answered", "already finished" and "open the quiz
      // first" — all of them mean the app and the server disagree about
      // where the student is, and a refetch is the cure.
      return DailyQuizException(DailyQuizErrorKind.alreadyDone,
          message.isEmpty ? 'That is already done.' : message);
    }
    if (status == 400) {
      return DailyQuizException(DailyQuizErrorKind.invalid,
          message.isEmpty ? 'That question is not in today\'s set.' : message);
    }

    return DailyQuizException(DailyQuizErrorKind.network,
        message.isEmpty ? 'Something went wrong. Please try again.' : message);
  }

  static void _dump(String method, String url, int status, String body) {
    if (!kDebugMode) return;
    debugPrint('┌── DAILY QUIZ  $method [$status]  $url');
    debugPrint('│  ${body.length > 300 ? '${body.substring(0, 300)}…' : body}');
    debugPrint('└── ${body.length} chars');
  }
}
