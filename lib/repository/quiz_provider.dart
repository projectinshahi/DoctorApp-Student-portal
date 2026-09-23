import 'dart:async';
// lib/repository/quiz_provider.dart
import '../core/utils/load_timer.dart';
import 'package:flutter/foundation.dart';

import '../models/selection_content_model.dart' show LessonAttemptInfo;

import '../models/quiz_model.dart';
import '../services/app_analytics.dart';
import '../services/quiz_service.dart';

/// One instance per open quiz — created by QuizScreen, never registered
/// globally.
///
/// The attempt lives on the server, not here. Opening the quiz starts one (or
/// picks up an unfinished one), each answer is posted as it is committed, and
/// finishing scores it. Nothing is cached locally: closing the app mid-quiz
/// loses nothing, and re-opening resumes from the server's copy.
///
/// **Retakes.** Opening a finished quiz shows its review, and the review
/// offers [retake], which starts a fresh attempt. Every attempt stays on the
/// server, so the review lists them all. The *latest* attempt decides what
/// opens: finished → its review, unfinished → resume it.
///
/// No mark is ever computed in this file. The answer key is absent from every
/// response a student could read before committing, so every number here comes
/// back from the API.
class QuizProvider extends ChangeNotifier {
  final QuizService _service;

  QuizProvider({QuizService? service}) : _service = service ?? QuizService();

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

  /// Past attempts on this lesson, newest first. Fetched with any review —
  /// after finishing, or on reopening a finished quiz — which is the only
  /// place it is shown.
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

  /// The counts as the last save reported them.
  ///
  /// Straight off the answer response, never a refetch — asking for the
  /// attempt again is a second round trip for numbers just handed over, and
  /// it is the usual way a fast endpoint stops feeling fast. Null until the
  /// first save lands, and then authoritative: it counts answers from an
  /// earlier sitting that this session never saw.
  int? _serverAnswered;
  int? _serverRemaining;

  int get attemptedCount => _answered.length;
  int get totalQuestions => attempt?.totalQuestions ?? questions.length;

  int get answeredCount => _serverAnswered ?? attemptedCount;
  int get remainingCount =>
      _serverRemaining ?? (totalQuestions - attemptedCount);

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
  /// [known] is the tree's own `attempt` for this lesson, and [treeKnows]
  /// says whether that tree was consulted at all.
  ///
  /// Opening a quiz used to cost two round trips in a row: a history fetch to
  /// find a finished attempt, then startAttempt. The content tree already
  /// carries that state — its own doc says "enough to label the row with no
  /// second call" — so when the caller has it, the history fetch is pure
  /// latency and this drops to one call.
  /// [warmed] is an attempt already fetched by QuizPrefetch. When it is
  /// here there is no call to make at all, so the quiz opens with no spinner.
  ///
  /// [startFresh] is the list's Retest: straight into a new attempt, past the
  /// review of the finished one the student chose not to open.
  Future<void> load(
    int lessonId, {
    LessonAttemptInfo? known,
    bool treeKnows = false,
    QuizAttempt? warmed,
    bool startFresh = false,
  }) async {
    _lessonId = lessonId;
    if (startFresh) return _startFresh();

    failure = null;
    _reset();

    if (warmed != null) {
      attempt = warmed;
      if (warmed.completed) {
        result = warmed.review;
        finished = true;
        // The attempts list under the review. Detached: the review itself is
        // already here and must not wait on it.
        unawaited(_loadHistory());
      } else {
        _seedFrom(warmed);
      }
      // A prefetched attempt reaches the screen without a network call, so
      // without this the key report is silent on the very path that is
      // fastest — and looks like the quiz never loaded.
      _reportKeyAvailability();
      // Never true for a heartbeat: the questions are already here, so a
      // spinner would only flash.
      isLoading = false;
      notifyListeners();
      return;
    }

    isLoading = true;
    notifyListeners();

    try {
      if (treeKnows) {
        if (known != null && known.completed) {
          // Straight to the review. Nothing is started, so a stale tree
          // costs at worst a review of the wrong attempt id, which the GET
          // would reject rather than corrupt.
          await _openReview(known.attemptId);
          isLoading = false;
          notifyListeners();
          return;
        }
        // Not completed, or never attempted: startAttempt resumes the
        // unfinished one or opens a fresh one, and runs the lesson gates on
        // the way. No history call needed to decide that.
        final resumed = await timedLoad(
            'quiz open', () => _service.startAttempt(lessonId),
            detail: (a) => '${a.questions.length} questions');
        attempt = resumed;
        _seedFrom(resumed);
        _reportKeyAvailability();
        isLoading = false;
        notifyListeners();
        return;
      }

      // No tree data — the careful path. The latest attempt decides: if it
      // is finished, open its review. This has to come before startAttempt,
      // which does not fail on a finished quiz — it quietly begins a retake
      // nobody asked for.
      final done = await timedLoad('quiz history', () => _latestIfCompleted(lessonId),
          detail: (d) => d == null ? 'latest attempt unfinished' : 'attempt ${d.attemptId}');
      if (done != null) {
        await _openReview(done.attemptId);
        isLoading = false;
        notifyListeners();
        return;
      }

      // One call: it starts a fresh attempt or resumes the unfinished one, and
      // runs every lesson gate on the way, so a locked lesson still fails here
      // with its plans attached.
      final started = await timedLoad(
          'quiz start', () => _service.startAttempt(lessonId),
          detail: (a) => '${a.questions.length} questions');
      attempt = started;
      _seedFrom(started);
      _reportKeyAvailability();
    } on QuizException catch (e) {
      failure = e;
    }

    isLoading = false;
    notifyListeners();
  }

  /// Seeds a started or resumed attempt.
  ///
  /// The picks come back from the server; the key does not.
  void _seedFrom(QuizAttempt started) {
    _answered.addAll(started.answeredIds);
    answers.addAll(started.answered);
    _resumedCount = started.resumed ? started.answeredIds.length : 0;

    // Open on the first question they haven't answered rather than at Q1 —
    // resuming should feel like continuing, not like starting over.
    final next = questions.indexWhere((q) => !_answered.contains(q.id));
    currentIndex = next < 0 ? 0 : next;
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
    // A new attempt's counts are not the old one's, and a queued save for a
    // question that no longer exists would post into the wrong attempt.
    _serverAnswered = null;
    _serverRemaining = null;
    _pendingSaves.clear();
    _resumedCount = 0;
  }

  // ── Answering ────────────────────────────────────────────────
  /// Tapping an option IS the answer — there is no separate Submit step.
  ///
  /// When the attempt shipped its answer key, the marking happens here and
  /// this returns **without touching the network**. The POST still goes out,
  /// but detached: nothing on screen and no caller waits on it. That is the
  /// whole point — it measured 3254ms for 790 bytes, and none of that was
  /// information the app did not already have.
  ///
  /// Without a key it falls back to asking the server, and then the pick is
  /// kept on screen but NOT marked answered if the call fails: the server
  /// never received it, and pretending otherwise would silently drop it from
  /// the score. Tapping again retries.
  Future<void> answer(int questionId, int optionId) async {
    final attemptId = attempt?.attemptId;
    if (attemptId == null) return;

    // Locked once committed, and one call at a time — a double tap must not
    // race two answers onto the same question.
    if (isAnswered(questionId) || checkingQuestionId != null) return;

    answers[questionId] = optionId;
    submitError = null;

    final local = _localResult(questionId, optionId);
    if (local != null) {
      _checked[questionId] = local;
      _answered.add(questionId);
      checkingQuestionId = null;
      notifyListeners();

      // Detached on purpose. Awaiting it here would put the 3s back — not in
      // front of the reveal, but in front of whatever the caller does next.
      unawaited(_recordInBackground(questionId, optionId));
      return;
    }

    // No key: the server is the only thing that knows, so this one waits.
    checkingQuestionId = questionId;
    notifyListeners();

    try {
      final response = await _service.answerQuestion(
        attemptId,
        questionId: questionId,
        optionId: optionId,
      );

      _answered.add(questionId);
      _checked[questionId] = response.result;
      _serverAnswered = response.answeredCount;
      _serverRemaining = response.remainingCount;
      await _flushPendingSaves();
    } on QuizException catch (e) {
      submitError = '${e.message} Tap your answer again to retry.';
    }

    checkingQuestionId = null;
    notifyListeners();
  }

  /// Records an already-revealed answer, out of the student's way.
  ///
  /// Still essential, just not in front of anything: it is what makes the
  /// attempt survive the app being killed, what the resume flow reads, and
  /// what the admin's per-student stats are built from.
  Future<void> _recordInBackground(int questionId, int optionId) async {
    final attemptId = attempt?.attemptId;
    if (attemptId == null) return;

    try {
      final response = await _service.answerQuestion(
        attemptId,
        questionId: questionId,
        optionId: optionId,
      );

      // The server's row is authoritative. It agrees with the local verdict
      // on right and wrong; what it adds is the counts and any explanation
      // the question payload did not carry.
      _checked[questionId] = response.result;
      _serverAnswered = response.answeredCount;
      _serverRemaining = response.remainingCount;

      await _flushPendingSaves();
      notifyListeners();
    } on QuizException {
      // Queued, not surfaced. The student has their answer and has moved on,
      // and "tap again" is not available to them — the question already
      // counts as answered. finish() flushes this before scoring.
      _pendingSaves[questionId] = optionId;
    }
  }

  /// Answers the student has given that the server has not acknowledged.
  ///
  /// Only reachable when the key was local: without it the reveal itself
  /// failed and the student is told to retry. With it they have moved on, so
  /// the write has to catch up on its own.
  final Map<int, int> _pendingSaves = {};

  @visibleForTesting
  int get pendingSaveCount => _pendingSaves.length;

  /// Re-sends queued answers. The endpoint is an upsert, so re-sending one
  /// that did land is harmless.
  Future<void> _flushPendingSaves() async {
    if (_pendingSaves.isEmpty) return;
    final attemptId = attempt?.attemptId;
    if (attemptId == null) return;

    for (final entry in Map<int, int>.from(_pendingSaves).entries) {
      try {
        final response = await _service.answerQuestion(
          attemptId,
          questionId: entry.key,
          optionId: entry.value,
        );
        _pendingSaves.remove(entry.key);
        _serverAnswered = response.answeredCount;
        _serverRemaining = response.remainingCount;
      } on QuizException {
        // Still down. Leave it queued; finish() tries again.
        break;
      }
    }
  }

  /// Whether this attempt's questions carry their own answer key.
  ///
  /// Printed rather than assumed: the model parses `isCorrect` when it is
  /// there, and whether the server sends it is the difference between an
  /// instant reveal and a 3s wait.
  void _reportKeyAvailability() {
    if (!kDebugMode) return;
    final withKey = questions.where((q) => q.correctOptionId != null).length;
    debugPrint('QBANK QUIZ  ${questions.length} questions, '
        '$withKey carry the answer key');
  }

  /// The verdict from the question itself, when the key came with it.
  ///
  /// Null when it did not — which is what the POST is for. Guessing would be
  /// wrong as often as it was right.
  /// QBANK ONLY. Grand Tests must never mark locally.
  ///
  /// This is safe here because QBank attempts are not ranked and feed no
  /// leaderboard, so there is nothing to cheat at. Grand Tests are ranked,
  /// timed and compared between students; their key is released only by
  /// /submit, and their models (test_model.dart, optionA..optionD) carry no
  /// key at all so this code cannot be reused there.
  ///
  /// **If a leaderboard is ever added to the QBank, revert this first.**
  QuizQuestionResult? _localResult(int questionId, int optionId) {
    final question = questions.where((q) => q.id == questionId).firstOrNull;
    if (question == null) return null;

    // correctOptionId, not options[].isCorrect: that field is false by
    // default, so a payload with the key stripped — a bookmarked question —
    // would read as "every option is wrong" and mark a correct answer wrong.
    final correctId = question.correctOptionId;
    if (correctId == null) return null;

    final right = correctId == optionId;
    return QuizQuestionResult(
      questionId: questionId,
      questionText: question.questionText,
      questionImageUrl: question.questionImageUrl,
      selectedOptionId: optionId,
      correctOptionId: correctId,
      isCorrect: right,
      answered: true,
      // Not negated: marksIncorrect is already a genuine negative, and
      // flipping it would award marks for a wrong answer.
      marksAwarded: right ? question.marksCorrect : question.marksIncorrect,
      // Now shipped with the question, so the explanation appears with the
      // verdict rather than a round trip later.
      explanation: question.explanation,
      options: question.options,
    );
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

    // Last chance for anything the network swallowed. A queued save that
    // never lands is a question the server thinks is unanswered — and the
    // review below comes from the server, so it would show as skipped.
    await _flushPendingSaves();

    try {
      result = await _service.finishAttempt(attemptId);
      finished = true;
      AppAnalytics.log('quiz_finished', {
        'lesson_id': _lessonId,
        'correct': correctCount,
        'total': totalQuestions,
      });
      isSubmitting = false;
      notifyListeners();

      printScore();
      // Detached. The review is already in this response; history is a
      // section at the foot of it, shown from the second attempt on. Waiting
      // on it put a measured 1541ms between Submit and the score.
      unawaited(_loadHistory());
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
        unawaited(_loadHistory());
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
      // Arrives after the review is already on screen, so it has to announce
      // itself — nothing else will rebuild for it.
      notifyListeners();
    } on QuizException {
      history = const [];
    }
    notifyListeners();
  }

  /// The latest attempt on this lesson when it is finished, else null.
  ///
  /// Fails open. If the history call itself fails we start (or resume) an
  /// attempt rather than lock someone out of a quiz — at worst a retake they
  /// did not ask for, which is a smaller harm than a quiz that will not open.
  Future<QuizAttemptSummary?> _latestIfCompleted(int lessonId) async {
    try {
      history = await _service.fetchHistory(lessonId);
    } on QuizException {
      history = const [];
      return null;
    }
    return latestCompleted(history);
  }

  /// The newest attempt that counts, if it is finished.
  ///
  /// History is newest first. An attempt with no answers is skipped: a quiz
  /// opened and closed is not a retake under way, and letting it sit on top
  /// would hide the finished attempt beneath it. An unfinished attempt *with*
  /// answers is a retake under way, and gives null so that it resumes.
  @visibleForTesting
  static QuizAttemptSummary? latestCompleted(List<QuizAttemptSummary> history) {
    for (final past in history) {
      if (past.completed) return past;
      if (past.answeredCount > 0) return null;
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
    // The list of attempts under the review, detached like after finishing.
    // Skipped when the careful path already fetched it to get here.
    if (history.isEmpty) unawaited(_loadHistory());
  }

  /// Starts a fresh attempt on a quiz whose review is open.
  ///
  /// startAttempt does the deciding: with the latest attempt finished it
  /// opens a new one, and if a retake was left half-done it resumes that
  /// instead of starting a third — which is the right answer either way. The
  /// finished attempt is untouched and stays in history.
  Future<void> retake() async {
    if (isLoading || isSubmitting) return;
    await _startFresh();
  }

  /// Starts an attempt without looking for a finished one first. Shared by
  /// Retest on the review and Retest on the list — the list's version runs
  /// while the provider is still in its initial loading state, which is why
  /// the guard lives in [retake] and not here.
  Future<void> _startFresh() async {
    failure = null;
    _reset();
    isLoading = true;
    notifyListeners();

    try {
      final started = await timedLoad(
          'quiz retake', () => _service.startAttempt(_lessonId),
          detail: (a) => '${a.questions.length} questions');
      attempt = started;
      AppAnalytics.log('quiz_retest', {'lesson_id': _lessonId});
      _seedFrom(started);
      _reportKeyAvailability();
    } on QuizException catch (e) {
      failure = e;
    }

    isLoading = false;
    notifyListeners();
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
