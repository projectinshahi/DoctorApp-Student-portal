// lib/repository/test_provider.dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/quiz_model.dart' show QuizException, QuizErrorKind;
import '../models/test_model.dart';
import '../services/test_service.dart';

/// How a question looks in the navigator grid.
enum QuestionState { answered, marked, unanswered }

/// One instance per open test paper — created by the attempt screen, never
/// registered globally.
///
/// The attempt lives on the server: every answer is a request, and the clock
/// is the server's. Closing the app mid-paper loses nothing.
class TestProvider extends ChangeNotifier {
  final TestService _service;

  TestProvider({TestService? service}) : _service = service ?? TestService();

  bool isLoading = true;
  QuizException? failure;

  TestAttempt? attempt;

  /// questionId -> selected letter. Holds a resumed attempt's answers too.
  final Map<int, String> answers = {};

  /// The question whose write is in flight, so only its card shows a spinner.
  int? busyQuestionId;

  /// Questions starred to come back to. Deliberately local: there is no
  /// endpoint for it, and it means nothing once the paper is submitted — it
  /// is a note to self for the next 30 minutes, not a bookmark.
  final Set<int> markedForReview = {};

  int currentIndex = 0;
  bool isSubmitting = false;
  String? actionError;

  TestResult? result;
  Leaderboard? leaderboard;

  /// Seconds left, ticked locally between calls and re-synced from every
  /// server response. Local ticking is only to keep the display smooth — the
  /// server's number always wins.
  int secondsRemaining = 0;
  Timer? _ticker;

  /// Fired once, when the countdown reaches zero. The screen uses it to
  /// submit and move on: a paper whose time is up is over, and leaving the
  /// student staring at a frozen sheet they cannot answer is not an ending.
  VoidCallback? onExpired;
  bool _expiredFired = false;

  bool _disposed = false;

  List<TestQuestion> get questions => attempt?.questions ?? const [];

  TestQuestion? get currentQuestion =>
      currentIndex < questions.length ? questions[currentIndex] : null;

  bool get isLastQuestion => currentIndex >= questions.length - 1;

  int get answeredCount => answers.length;
  int get totalQuestions => attempt?.totalQuestions ?? questions.length;
  int get skippedCount => totalQuestions - answeredCount;

  bool get isTimeUp => secondsRemaining <= 0;

  String? selectedOption(int questionId) => answers[questionId];
  bool isBusy(int questionId) => busyQuestionId == questionId;

  bool isMarked(int questionId) => markedForReview.contains(questionId);

  void toggleMark(int questionId) {
    if (!markedForReview.remove(questionId)) markedForReview.add(questionId);
    notifyListeners();
  }

  int get markedCount => markedForReview.length;

  /// What the palette paints each numbered box.
  QuestionState stateAt(int index) {
    if (index < 0 || index >= questions.length) return QuestionState.unanswered;
    final id = questions[index].id;
    if (answers.containsKey(id)) return QuestionState.answered;
    if (markedForReview.contains(id)) return QuestionState.marked;
    return QuestionState.unanswered;
  }

  /// mm:ss, or h:mm:ss for a paper longer than an hour.
  String get formattedTime {
    final seconds = secondsRemaining < 0 ? 0 : secondsRemaining;
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  // ── Loading ──────────────────────────────────────────────────
  Future<void> start(int testId) async {
    isLoading = true;
    failure = null;
    notifyListeners();

    try {
      final started = await _service.startAttempt(testId);
      attempt = started;
      answers
        ..clear()
        ..addAll(started.answered);
      markedForReview.clear();

      // The server's remaining time, NOT durationMinutes. A resumed paper has
      // less time left, and reading the duration would hand out a fresh clock
      // on every reopen.
      _syncClock(started.secondsRemaining);

      _expiredFired = false;

      // Open on the first unanswered question — resuming should feel like
      // continuing, not like starting again.
      final next = questions.indexWhere((q) => !answers.containsKey(q.id));
      currentIndex = next < 0 ? 0 : next;
    } on QuizException catch (e) {
      // `attemptFinished` is not a failure of the request: a paper whose time
      // ran out while the app was closed is auto-submitted by the server, and
      // the screen routes that kind to the marked sheet instead of an error.
      failure = e;
    }

    isLoading = false;
    notifyListeners();
  }

  void _syncClock(int seconds) {
    secondsRemaining = seconds;
    _ticker?.cancel();
    if (seconds <= 0) return;

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      secondsRemaining--;
      if (secondsRemaining <= 0) {
        secondsRemaining = 0;
        _ticker?.cancel();
        // Once only: the ticker is cancelled here, but a late clock sync
        // could start another one.
        if (!_expiredFired) {
          _expiredFired = true;
          onExpired?.call();
        }
      }
      notifyListeners();
    });
  }

  // ── Answering ────────────────────────────────────────────────
  /// Tapping an option commits it. Tapping the selected one again clears it,
  /// which with negative marking is a real move: skipped scores 0 where wrong
  /// scores the negative mark.
  Future<void> select(int questionId, String option) async {
    final attemptId = attempt?.attemptId;
    if (attemptId == null || busyQuestionId != null || isTimeUp) return;

    final clearing = answers[questionId] == option;
    final previous = answers[questionId];

    busyQuestionId = questionId;
    actionError = null;
    // Optimistic, so the paper stays responsive on a slow connection.
    if (clearing) {
      answers.remove(questionId);
    } else {
      answers[questionId] = option;
    }
    notifyListeners();

    try {
      final response = clearing
          ? await _service.clearAnswer(attemptId, questionId: questionId)
          : await _service.answer(attemptId,
              questionId: questionId, selectedOption: option);

      // Re-reading the clock here is what keeps a long paper from drifting
      // away from the server's own count — but only when the response
      // actually carries it. The clear-answer reply does not, and syncing a
      // missing value to 0 would end the paper mid-sitting.
      final seconds = response.secondsRemaining;
      if (seconds != null) _syncClock(seconds);
    } on QuizException catch (e) {
      // Roll back: the server never took it, and leaving it on screen would
      // tell the student an answer is saved when it is not.
      if (previous == null) {
        answers.remove(questionId);
      } else {
        answers[questionId] = previous;
      }
      actionError = '${e.message} Tap again to retry.';
    }

    busyQuestionId = null;
    notifyListeners();
  }

  void goTo(int index) {
    if (index < 0 || index >= questions.length) return;
    currentIndex = index;
    notifyListeners();
  }

  void next() => goTo(currentIndex + 1);
  void previous() => goTo(currentIndex - 1);

  // ── Submitting ───────────────────────────────────────────────
  /// Marks the paper. Safe to call twice — the second call returns the same
  /// sheet — so a retry after a dropped connection cannot double-submit.
  Future<bool> submit() async {
    final attemptId = attempt?.attemptId;
    if (attemptId == null || isSubmitting) return false;

    isSubmitting = true;
    actionError = null;
    notifyListeners();

    var ok = false;
    try {
      result = await _service.submit(attemptId);
      ok = true;
    } on QuizException catch (e) {
      // The server expires attempts lazily — it checks the deadline on the
      // next read or write and closes the paper itself. So it may have
      // submitted this one before we asked. That is the same outcome, not a
      // failure: collect the sheet it already marked.
      if (e.kind == QuizErrorKind.attemptFinished) {
        try {
          result = await _service.fetchResult(attemptId);
          ok = true;
        } on QuizException catch (fetchError) {
          actionError = fetchError.message;
        }
      } else {
        actionError = e.message;
      }
    }

    if (ok) {
      _ticker?.cancel();
      unawaited(loadLeaderboard());
    }

    isSubmitting = false;
    notifyListeners();
    return ok;
  }

  Future<void> loadResult(int attemptId) async {
    isLoading = true;
    failure = null;
    notifyListeners();

    try {
      result = await _service.fetchResult(attemptId);
    } on QuizException catch (e) {
      failure = e;
    }

    isLoading = false;
    notifyListeners();
  }

  /// A leaderboard failure never takes down a result the student has earned.
  Future<void> loadLeaderboard() async {
    final testId = attempt?.testId ?? _leaderboardTestId;
    if (testId == null) return;

    try {
      leaderboard = await _service.fetchLeaderboard(testId);
    } on QuizException {
      leaderboard = null;
    }
    notifyListeners();
  }

  int? _leaderboardTestId;
  set leaderboardTestId(int id) => _leaderboardTestId = id;

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    super.dispose();
  }

  /// Answers, the clock and submit all notify after an await, and the student
  /// can close the paper mid-request.
  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }
}
