// lib/repository/quiz_provider.dart
import 'package:flutter/foundation.dart';

import '../models/quiz_model.dart';
import '../services/quiz_service.dart';

/// One instance per open quiz — created by QuizScreen, never registered
/// globally.
///
/// The attempt lives on the server, not here. Opening the quiz starts one (or
/// picks up an unfinished one), each answer is posted as it is committed, and
/// finishing scores it. Nothing is cached locally: closing the app mid-quiz
/// loses nothing, and re-opening resumes from the server's copy.
///
/// **One attempt per quiz.** Opening a quiz that has already been finished
/// reopens it read-only as a review — no new attempt is started. The API
/// itself allows retakes, so this file is the only thing enforcing the rule.
///
/// No mark is ever computed in this file. The answer key is absent from every
/// response a student could read before committing, so every number here comes
/// back from the API.
class QuizProvider extends ChangeNotifier {
  final QuizService _service = QuizService();

  int _lessonId = 0;

  bool isLoading = true;
  QuizException? failure;

  QuizAttempt? attempt;

  /// questionId -> selected optionId. Holds the pending selection on the
  /// current question as well as every answer already committed.
  final Map<int, int> answers = {};

  /// Questions committed to the server. Locked — re-answering is possible on
  /// the API, but letting a student change a revealed answer would make the
  /// score meaningless.
  final Set<int> _answered = {};

  /// Per-question reveals, keyed by questionId, filled as each answer is
  /// posted. A resumed attempt has answers here with no reveal: the key is
  /// not sent for an unfinished attempt, so those stay blank until finish.
  final Map<int, QuizQuestionResult> _checked = {};

  /// The question currently in flight, so only its card shows a spinner.
  int? checkingQuestionId;


  int currentIndex = 0;
  bool finished = false;

  /// The scored attempt, from the finish call.
  QuizAttemptResult? result;
  bool isSubmitting = false;
  String? submitError;

  /// Past attempts on this lesson, newest first. Fetched after finishing —
  /// that's the only place it is shown.
  List<QuizAttemptSummary> history = const [];

  // ── Questions ────────────────────────────────────────────────
  /// Every question, in server order. Unlike the old flow this never hides
  /// answered ones: the server sends the whole attempt back on resume, so
  /// hiding them would throw away context the student can now navigate to.
  List<QuizQuestionModel> get questions => attempt?.questions ?? const [];

  QuizQuestionModel? get currentQuestion =>
      currentIndex < questions.length ? questions[currentIndex] : null;

  bool get isLastQuestion => currentIndex >= questions.length - 1;

  /// How many answers this attempt already had when it was picked up. Fixed
  /// at load on purpose: counting live would make the "already answered"
  /// banner tick up with the student's current work and stop meaning
  /// anything. Zero unless the server actually handed back answers — it
  /// reports `resumed: true` for any attempt it reused, including an empty
  /// one someone opened and closed, and "continuing — 0 already answered" is
  /// a lie.
  int _resumedCount = 0;
  bool get isResumed => _resumedCount > 0;
  int get resumedCount => _resumedCount;

  // ── Per-question state ───────────────────────────────────────
  bool isAnswered(int questionId) => _answered.contains(questionId);

  int? selectedOption(int questionId) => answers[questionId];

  bool isChecking(int questionId) => checkingQuestionId == questionId;

  /// This question's outcome: the finished attempt's verdict if it has been
  /// scored, otherwise the reveal from when the answer was posted. Null when
  /// neither has happened — including a resumed answer, whose key the server
  /// deliberately withholds until the attempt is finished.
  QuizQuestionResult? resultFor(QuizQuestionModel question) =>
      result?.forQuestion(question.id) ?? _checked[question.id];

  int get attemptedCount => _answered.length;
  int get totalQuestions => attempt?.totalQuestions ?? questions.length;
  int get remainingCount => totalQuestions - attemptedCount;

  /// The review rows, in the order the questions were shown when that order
  /// is known, and in the server's own order when it isn't — a review opened
  /// cold has no served list to align against.
  List<QuizQuestionResult> get reviewResults {
    final scored = result;
    if (scored == null) return const [];
    if (questions.isEmpty) return scored.results;

    final ordered = <QuizQuestionResult>[];
    for (final question in questions) {
      final outcome = scored.forQuestion(question.id);
      if (outcome != null) ordered.add(outcome);
    }
    // Anything the served list didn't cover still belongs in the review.
    for (final outcome in scored.results) {
      if (!ordered.contains(outcome)) ordered.add(outcome);
    }
    return ordered;
  }

  // ── Scoring — all server numbers ─────────────────────────────
  int get correctCount => result?.correctCount ?? 0;
  int get wrongCount => result?.wrongCount ?? 0;
  int get skippedCount => result?.skippedCount ?? remainingCount;
  double get scoredMarks => result?.score ?? 0;
  double get totalMarks => result?.totalMarks ?? attempt?.totalMarks ?? 0;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Every notify in this file happens after an await, and the student can
  /// close the quiz while a call is still in the air — the screen's provider
  /// is disposed with the response yet to land. Dropping the notify is the
  /// right answer: there is no longer a screen to rebuild.
  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  // ── Loading ──────────────────────────────────────────────────
  /// Starts an attempt, or picks up the unfinished one the server is holding.
  /// This single call also runs every lesson gate — locked, wrong course, no
  /// quiz linked — so there is no lesson fetch to make first.
  Future<void> load(int lessonId) async {
    _lessonId = lessonId;
    isLoading = true;
    failure = null;
    _reset();
    notifyListeners();

    try {
      // One attempt only: a finished one reopens as a review. This has to come
      // before startAttempt, because startAttempt on a finished quiz does not
      // fail — it cheerfully opens attempt #2.
      final done = await _findCompletedAttempt(lessonId);
      if (done != null) {
        await _openReview(done.attemptId);
        isLoading = false;
        notifyListeners();
        return;
      }

      // One call: it starts a fresh attempt or resumes the unfinished one, and
      // runs every lesson gate on the way, so a locked lesson still fails here
      // with its plans attached.
      final started = await _service.startAttempt(lessonId);
      attempt = started;

      // Seed a resumed attempt: the picks come back, the key does not.
      _answered.addAll(started.answeredIds);
      answers.addAll(started.answered);
      _resumedCount = started.resumed ? started.answeredIds.length : 0;

      // Open on the first question they haven't answered rather than at Q1 —
      // resuming should feel like continuing, not like starting over.
      final next = questions.indexWhere((q) => !_answered.contains(q.id));
      currentIndex = next < 0 ? 0 : next;
    } on QuizException catch (e) {
      failure = e;
    }

    isLoading = false;
    notifyListeners();
  }

  void _reset() {
    attempt = null;
    answers.clear();
    _answered.clear();
    _checked.clear();
    checkingQuestionId = null;
    currentIndex = 0;
    finished = false;
    result = null;
    submitError = null;
    history = const [];
    _resumedCount = 0;
  }

  // ── Answering ────────────────────────────────────────────────
  /// Tapping an option IS the answer — there is no separate Submit step.
  /// The response carries this question's correct option and explanation, so
  /// the reveal happens on the same tap.
  ///
  /// On failure the pick is kept on screen but NOT marked answered: the
  /// server never received it, and pretending otherwise would silently drop
  /// it from the score. Tapping again retries.
  Future<void> answer(int questionId, int optionId) async {
    final attemptId = attempt?.attemptId;
    if (attemptId == null) return;

    // Locked once committed, and one call at a time — a double tap must not
    // race two answers onto the same question.
    if (isAnswered(questionId) || checkingQuestionId != null) return;

    answers[questionId] = optionId;
    checkingQuestionId = questionId;
    submitError = null;
    notifyListeners();

    try {
      final response = await _service.answerQuestion(
        attemptId,
        questionId: questionId,
        optionId: optionId,
      );

      _answered.add(questionId);
      _checked[questionId] = response.result;
    } on QuizException catch (e) {
      submitError = '${e.message} Tap your answer again to retry.';
    }

    checkingQuestionId = null;
    notifyListeners();
  }

  void next() {
    if (isLastQuestion) return;
    currentIndex++;
    notifyListeners();
  }

  void previous() {
    if (currentIndex > 0) currentIndex--;
    notifyListeners();
  }

  // ── Finishing ────────────────────────────────────────────────
  /// Scores the attempt and prints the totals to the terminal. Returns false
  /// when it failed, so the screen stays put and the student can retry rather
  /// than losing the attempt.
  Future<bool> finish() async {
    final attemptId = attempt?.attemptId;
    if (attemptId == null || isSubmitting) return false;

    isSubmitting = true;
    submitError = null;
    notifyListeners();

    try {
      result = await _service.finishAttempt(attemptId);
      finished = true;
      isSubmitting = false;
      notifyListeners();

      printScore();
      await _loadHistory();
      return true;
    } on QuizException catch (e) {
      isSubmitting = false;

      if (e.kind == QuizErrorKind.attemptFinished) {
        // Already scored — a double tap, or a finish that succeeded on the
        // server after the response was lost. Read the review back instead of
        // showing a failure for something that actually worked.
        await _recoverFinished(attemptId);
        return result != null;
      }

      submitError = e.message;
      notifyListeners();
      return false;
    }
  }

  /// The attempt is finished server-side but we never got the review — a
  /// double tap, or a finish that succeeded after the response was lost.
  /// Fetch it: a completed GET carries the same body the finish call returns.
  Future<void> _recoverFinished(int attemptId) async {
    try {
      final fetched = await _service.fetchAttempt(attemptId);
      if (fetched.review != null) {
        result = fetched.review;
        finished = true;
        printScore();
        await _loadHistory();
      } else {
        submitError = 'This attempt is already finished.';
      }
    } on QuizException catch (e) {
      submitError = e.message;
    }
    notifyListeners();
  }

  /// History is a nicety, not part of the score — a failure here must never
  /// take down a review the student has already earned.
  Future<void> _loadHistory() async {
    try {
      history = await _service.fetchHistory(_lessonId);
    } on QuizException {
      history = const [];
    }
    notifyListeners();
  }

  /// This lesson's finished attempt, if it has one.
  ///
  /// Deliberately not `history.first`: a student can abandon an empty attempt
  /// on top of a completed one, and keying off the newest row would let that
  /// unlock the quiz again.
  ///
  /// Fails open. If the history call itself fails we start an attempt rather
  /// than locking someone out of a quiz they may never have taken — a lost
  /// retake-block is a smaller harm than a quiz that will not open.
  Future<QuizAttemptSummary?> _findCompletedAttempt(int lessonId) async {
    try {
      history = await _service.fetchHistory(lessonId);
    } on QuizException {
      history = const [];
      return null;
    }
    return firstCompleted(history);
  }

  /// The finished attempt in a history list, or null.
  ///
  /// Deliberately not `history.first`. History is newest-first, and an empty
  /// abandoned attempt sits on top of the completed one it followed — reading
  /// the newest row would report "not finished" and unlock the quiz again.
  @visibleForTesting
  static QuizAttemptSummary? firstCompleted(List<QuizAttemptSummary> history) {
    for (final past in history) {
      if (past.completed) return past;
    }
    return null;
  }

  /// Reopens a finished attempt read-only. The GET carries the whole review,
  /// key and explanations included, so there is nothing to score here.
  Future<void> _openReview(int attemptId) async {
    final reopened = await _service.fetchAttempt(attemptId);
    attempt = reopened;
    result = reopened.review;
    finished = true;
  }

  void printScore() {
    final scored = result;
    if (scored == null) return;

    final title = attempt?.quiz?.title ?? 'Quiz';

    debugPrint('──────── QUIZ FINISHED ────────');
    debugPrint('Quiz      : $title (lesson $_lessonId)');
    debugPrint('Attempt   : ${attempt?.attemptId}');
    debugPrint('Attempted : $attemptedCount of ${scored.totalQuestions}');
    debugPrint('Correct   : ${scored.correctCount}');
    debugPrint('Wrong     : ${scored.wrongCount}');
    debugPrint('Skipped   : ${scored.skippedCount}');
    debugPrint('TOTAL MARKS: ${scored.score} of ${scored.totalMarks}');
    debugPrint('───────────────────────────────');
  }
}
