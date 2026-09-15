import 'dart:convert';
// lib/repository/daily_quiz_provider.dart
import '../core/utils/load_timer.dart';
import 'package:flutter/foundation.dart';

import '../models/daily_quiz_model.dart';
import '../core/constant/local_storage.dart';
import '../models/home_summary_model.dart';
import '../services/daily_quiz_service.dart';

/// Everything `/users/me/home` carries. App-wide and deliberately separate
/// from [DailyQuizProvider]: this one only ever reads, and reading must never
/// start the day's attempt.
class HomeSummaryProvider extends ChangeNotifier {
  final DailyQuizService _service;

  HomeSummaryProvider({DailyQuizService? service})
      : _service = service ?? DailyQuizService() {
    _restore();
  }

  /// Paints the last known home screen before the network is asked.
  ///
  /// Measured cold on device, /home took 5459ms — all of it spent on an empty
  /// screen. The stored copy is on screen in milliseconds and the fresh one
  /// swaps in underneath.
  Future<void> _restore() async {
    if (home != null) return;
    try {
      final stored = await LocalStorage.getCached(LocalStorage.homeSummaryKey);
      if (stored == null || stored.isEmpty || home != null) return;
      home = HomeSummary.fromJson(jsonDecode(stored));
      isLoading = false;
      notifyListeners();
    } catch (_) {
      // Written by an older build, or storage unavailable. The fetch already
      // under way covers it — restoring must never break the screen.
    }
  }

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
      home = await timedLoad('home summary', _service.fetchHome,
          detail: (h) => '${h?.inProgressVideos.length ?? 0} in progress');
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

  /// The option tapped but not yet ruled on.
  ///
  /// The answer key is deliberately absent from the question payload — a
  /// student could otherwise read every answer straight out of the response —
  /// so correct or wrong genuinely cannot be known here until the server
  /// says. This is what fills the gap: the choice registers instantly and
  /// only the verdict waits.
  int? pendingOptionId;

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
  /// Paints today's stored set before the network is asked.
  ///
  /// The set is frozen server-side per (course, date), so what was on screen
  /// last time is what is coming back. Restoring it is what lets the question
  /// arrive with the rest of the home screen instead of a second or two
  /// after it.
  ///
  /// The fetch still runs underneath: it is what confirms the date has not
  /// rolled over, and picks up an answer committed elsewhere.
  Future<bool> restoreCached() async {
    if (set != null) return true;
    try {
      final stored = await LocalStorage.getCached(LocalStorage.dailyQuizKey);
      if (stored == null || stored.isEmpty || set != null) return false;

      final wrapper = jsonDecode(stored) as Map<String, dynamic>;
      // Another course's set is not this course's question.
      if (wrapper['courseId'] != courseId) return false;

      final today = DailyQuizSet.fromJson(
          Map<String, dynamic>.from(wrapper['set'] as Map));
      set = today;
      answers
        ..clear()
        ..addAll(today.answers);
      final next = today.questions.indexWhere((q) => !answers.containsKey(q.id));
      currentIndex = next < 0 ? 0 : next;
      isLoading = false;
      notifyListeners();
      return true;
    } catch (_) {
      // Written by an older build, or storage unavailable. The fetch under
      // way covers it.
      return false;
    }
  }

  Future<void> load() async {
    isLoading = set == null;
    failure = null;
    notifyListeners();

    try {
      final today = await timedLoad(
          'daily quiz', () => _service.fetchToday(courseId),
          detail: (t) => '${t.questions.length} questions');
      set = today;
      answers
        ..clear()
        ..addAll(today.answers);

      if (kDebugMode) {
        // Whether the key ships with the questions decides whether the reveal
        // can be instant. Printed rather than assumed.
        final withKey = today.questions
            .where((q) => q.options.any((o) => o.isCorrect != null))
            .length;
        debugPrint('DAILY QUIZ  ${today.questions.length} questions, '
            '$withKey carry the answer key, '
            '${today.answers.length} already answered');
      }

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
    // Recorded before the request, so the tile the student tapped lights up
    // on the same frame as the tap.
    pendingOptionId = optionId;
    actionError = null;

    // If the set shipped with the key, the verdict is already here and there
    // is nothing to wait for. The POST still goes out — it is what records
    // the answer and returns the explanation — but the student sees right or
    // wrong now rather than in three seconds.
    final local = _localVerdict(questionId, optionId);
    if (local != null) {
      answers[questionId] = local;
      pendingOptionId = null;
    }
    notifyListeners();

    var ok = false;
    try {
      final response = await _service.answer(courseId,
          questionId: questionId, optionId: optionId);
      // Overwrites any local verdict: the server's is authoritative and it
      // carries the explanation, which the question payload does not.
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

    pendingOptionId = null;
    isSubmitting = false;
    notifyListeners();
    return ok;
  }

  /// The verdict from the question itself, when the server sent the key with
  /// it. Null when it did not, which is the case the POST exists for.
  DailyQuizAnswer? _localVerdict(int questionId, int optionId) {
    final question =
        questions.where((q) => q.id == questionId).firstOrNull;
    if (question == null) return null;

    // Every option has to carry it. A partial key would let a wrong answer
    // read as right simply because its own flag was missing.
    if (question.options.any((o) => o.isCorrect == null)) return null;

    final correct =
        question.options.where((o) => o.isCorrect == true).firstOrNull;
    if (correct == null) return null;

    final right = correct.id == optionId;
    return DailyQuizAnswer(
      questionId: questionId,
      selectedOptionId: optionId,
      correctOptionId: correct.id,
      isCorrect: right,
      // Not negated: marksIncorrect is already a genuine negative, and
      // flipping it would award marks for a wrong answer.
      marksAwarded: right ? question.marksCorrect : question.marksIncorrect,
      // Deliberately absent. The explanation comes back with the POST, and
      // inventing one would be worse than showing it a moment later.
      explanation: null,
    );
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
