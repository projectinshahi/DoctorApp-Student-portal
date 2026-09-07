// lib/repository/daily_quiz_provider.dart
import 'package:flutter/foundation.dart';

import '../models/daily_quiz_model.dart';
import '../models/home_summary_model.dart';
import '../services/daily_quiz_service.dart';

/// Everything `/users/me/home` carries. App-wide and deliberately separate
/// from [DailyQuizProvider]: this one only ever reads, and reading must never
/// start the day's attempt.
class HomeSummaryProvider extends ChangeNotifier {
  final DailyQuizService _service;

  HomeSummaryProvider({DailyQuizService? service})
      : _service = service ?? DailyQuizService();

  bool isLoading = false;
  HomeSummary? home;

  DailyQuizSummary? get summary => home?.dailyQuiz;

  /// The Continue Watching row. Empty hides the whole section — a "nothing
  /// in progress" placeholder on a home screen is noise.
  List<InProgressVideo> get inProgressVideos =>
      home?.inProgressVideos ?? const [];

  bool _disposed = false;

  /// Reads `/users/me/home`. Verified to leave the attempts table empty —
  /// nothing starts until the student opens the quiz itself.
  Future<void> load() async {
    isLoading = home == null;
    notifyListeners();

    try {
      home = await _service.fetchHome();
    } on DailyQuizException {
      // The sections simply do not render. A failed summary is not worth an
      // error banner across a home screen that is otherwise fine.
      home = null;
    }

    isLoading = false;
    notifyListeners();
  }

  /// Drops a video from the row the moment the player reports it finished.
  ///
  /// The progress write already answers with `completed`, so waiting for the
  /// next `/home` would leave a finished video sitting in Continue Watching
  /// for the rest of the session.
  void dropCompleted(int lessonId) {
    final current = home;
    if (current == null) return;
    if (!current.inProgressVideos.any((v) => v.lessonId == lessonId)) return;

    home = HomeSummary(
      dailyQuiz: current.dailyQuiz,
      inProgressVideos: [
        for (final v in current.inProgressVideos)
          if (v.lessonId != lessonId) v,
      ],
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }
}

/// One open quiz. Created by the quiz screen, never registered globally —
/// creating it is what starts the day.
class DailyQuizProvider extends ChangeNotifier {
  final DailyQuizService _service;
  final int courseId;

  DailyQuizProvider({required this.courseId, DailyQuizService? service})
      : _service = service ?? DailyQuizService();

  bool isLoading = true;
  bool isSubmitting = false;
  DailyQuizException? failure;
  String? actionError;

  DailyQuizSet? set;
  DailyQuizResult? result;

  /// questionId -> the revealed answer. Seeded from the set's own `answers`
  /// so a half-done day resumes with its reveals intact.
  final Map<int, DailyQuizAnswer> answers = {};

  int currentIndex = 0;

  bool _disposed = false;

  List<DailyQuizQuestion> get questions => set?.questions ?? const [];
  DailyQuizQuestion? get current =>
      currentIndex < questions.length ? questions[currentIndex] : null;

  bool get isLast => currentIndex >= questions.length - 1;
  int get answeredCount => answers.length;
  int get totalQuestions => set?.totalQuestions ?? questions.length;
  int get currentStreak => result?.currentStreak ?? set?.currentStreak ?? 0;

  DailyQuizAnswer? answerFor(int questionId) => answers[questionId];
  bool isAnswered(int questionId) => answers.containsKey(questionId);

  /// Opens today's set. Safe to call again — the set is frozen server-side.
  Future<void> load() async {
    isLoading = set == null;
    failure = null;
    notifyListeners();

    try {
      final today = await _service.fetchToday(courseId);
      set = today;
      answers
        ..clear()
        ..addAll(today.answers);

      // Resume where they stopped rather than at question one.
      final next = today.questions.indexWhere((q) => !answers.containsKey(q.id));
      currentIndex = next < 0 ? 0 : next;

      // Already finished today: go straight to the sheet.
      if (today.completed) await _loadResult();
    } on DailyQuizException catch (e) {
      failure = e;
    }

    isLoading = false;
    notifyListeners();
  }

  /// Commits one answer and reveals the key.
  ///
  /// One shot per question: the options are disabled afterwards, because
  /// re-answering is a 409 and because being able to change your mind after
  /// seeing the explanation is what would make the score meaningless.
  Future<bool> answer(int questionId, int optionId) async {
    if (isSubmitting || isAnswered(questionId)) return false;

    isSubmitting = true;
    actionError = null;
    notifyListeners();

    var ok = false;
    try {
      final response = await _service.answer(courseId,
          questionId: questionId, optionId: optionId);
      answers[questionId] = response.asAnswer;
      ok = true;

      // The server says when the last one landed; no counting here.
      if (response.allAnswered) await _loadResult();
    } on DailyQuizException catch (e) {
      // A 409 means the server already has an answer we do not. Refetching
      // is the cure, and it cannot reroll the set.
      if (e.kind == DailyQuizErrorKind.alreadyDone) {
        await load();
      } else {
        actionError = e.message;
      }
    }

    isSubmitting = false;
    notifyListeners();
    return ok;
  }

  void next() => goTo(currentIndex + 1);
  void previous() => goTo(currentIndex - 1);

  void goTo(int index) {
    if (index < 0 || index >= questions.length) return;
    currentIndex = index;
    notifyListeners();
  }

  /// Marks the day. Safe to call twice, which is why the last-question path
  /// and the Finish button can both reach it.
  Future<bool> finish() async {
    if (isSubmitting) return result != null;

    isSubmitting = true;
    actionError = null;
    notifyListeners();

    final ok = await _loadResult();
    if (!ok) actionError = 'Could not finish today\'s quiz. Try again.';

    isSubmitting = false;
    notifyListeners();
    return ok;
  }

  Future<bool> _loadResult() async {
    try {
      result = await _service.finish(courseId);
      return true;
    } on DailyQuizException {
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Every notify above follows an await, and the student can close the quiz
  /// mid-request.
  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }
}
