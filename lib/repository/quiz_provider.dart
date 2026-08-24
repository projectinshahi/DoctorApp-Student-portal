// lib/repository/quiz_provider.dart
import 'package:flutter/foundation.dart';

import '../core/constant/local_storage.dart';
import '../models/quiz_model.dart';
import '../services/quiz_service.dart';

/// One instance per open quiz — created by QuizScreen, never registered
/// globally. A filter-based quiz resolves fresh on every open, so its
/// questions must not be cached across sessions.
///
/// Flow: no intro screen. The first question is on screen immediately.
/// Each question is answered, then *submitted* — submitting locks it and
/// reveals the correct answer + explanation. Leaving mid-attempt keeps the
/// submitted answers, so re-opening shows only what's left.
class QuizProvider extends ChangeNotifier {
  final QuizService _service = QuizService();

  int _lessonId = 0;

  bool isLoading = true;
  QuizException? failure;

  QuizLessonDetail? lesson;
  QuizQuestionsModel? questions;

  /// questionId -> selected optionId. Holds both the pending selection on the
  /// current question and every answer already submitted.
  final Map<int, int> answers = {};

  /// Submitted during THIS visit — kept on screen with their feedback.
  final Set<int> _submittedNow = {};

  /// Submitted during an earlier visit — dropped from [visibleQuestions] so a
  /// resumed attempt only shows the remaining questions.
  final Set<int> _carriedOver = {};

  int currentIndex = 0;
  bool finished = false;

  // ── Question lists ──
  List<QuizQuestionModel> get allQuestions => questions?.questions ?? const [];

  List<QuizQuestionModel> get visibleQuestions =>
      allQuestions.where((q) => !_carriedOver.contains(q.id)).toList();

  QuizQuestionModel? get currentQuestion =>
      currentIndex < visibleQuestions.length ? visibleQuestions[currentIndex] : null;

  bool get isLastQuestion => currentIndex >= visibleQuestions.length - 1;

  /// True when this open is continuing an attempt that was left half-done.
  bool get isResumed => _carriedOver.isNotEmpty;
  int get carriedOverCount => _carriedOver.length;

  // ── Per-question state ──
  bool isSubmitted(int questionId) =>
      _submittedNow.contains(questionId) || _carriedOver.contains(questionId);

  int? selectedOption(int questionId) => answers[questionId];

  /// Everything the student has actually committed, this visit or before.
  Map<int, int> get _committed => {
        for (final entry in answers.entries)
          if (isSubmitted(entry.key)) entry.key: entry.value,
      };

  int get attemptedCount => _committed.length;
  int get skippedCount => allQuestions.length - attemptedCount;

  // ── Scoring. Null answers / a missing answer key never guess. ──
  bool get hasAnswerKey => allQuestions.any((q) => q.hasAnswerKey);

  /// null = unanswered, or the API didn't send the answer key for it.
  bool? resultFor(QuizQuestionModel question) {
    final correct = question.correctOption;
    final picked = _committed[question.id];
    if (correct == null || picked == null) return null;
    return picked == correct.id;
  }

  int get correctCount => allQuestions.where((q) => resultFor(q) == true).length;
  int get wrongCount => allQuestions.where((q) => resultFor(q) == false).length;

  double get scoredMarks {
    var total = 0.0;
    for (final question in allQuestions) {
      final result = resultFor(question);
      if (result == null) continue;
      total += result ? question.marksCorrect : question.marksIncorrect;
    }
    return total;
  }

  // ── Loading ──
  Future<void> load(int lessonId) async {
    _lessonId = lessonId;
    isLoading = true;
    failure = null;
    notifyListeners();

    try {
      final detail = await _service.fetchLesson(lessonId);
      lesson = detail;

      if (detail.locked) {
        // Locked lesson — the paywall plans came with the detail call, and the
        // questions endpoint must not be called at all.
        failure = QuizException(
          QuizErrorKind.locked,
          'This lesson is locked. Subscribe to unlock it.',
          requiredPlans: detail.paywallPlans,
        );
      } else if (!detail.hasQuiz) {
        // Either not a quiz lesson at all, or a quiz lesson with quizId null
        // (lesson 31 "Pulmanology"). Both answer 409 from the questions
        // endpoint — show the empty state instead of making the call.
        failure = QuizException(
          QuizErrorKind.noQuizLinked,
          'This lesson has no quiz linked',
        );
      } else {
        questions = await _service.fetchQuestions(lessonId);

        // Resume: keep old answers for the final score, hide their questions.
        final saved = await LocalStorage.getQuizProgress(lessonId);
        final live = allQuestions.map((q) => q.id).toSet();
        saved.removeWhere((questionId, _) => !live.contains(questionId));
        answers.addAll(saved);
        _carriedOver.addAll(saved.keys);
        currentIndex = 0;
      }
    } on QuizException catch (e) {
      failure = e;
    }

    isLoading = false;
    notifyListeners();
  }

  // ── Answering ──
  void select(int questionId, int optionId) {
    if (isSubmitted(questionId)) return; // locked once submitted
    answers[questionId] = optionId;
    notifyListeners();
  }

  /// Locks the current question and reveals its feedback. No-op until an
  /// option is picked.
  Future<void> submitCurrent() async {
    final question = currentQuestion;
    if (question == null) return;
    if (answers[question.id] == null || isSubmitted(question.id)) return;

    _submittedNow.add(question.id);
    notifyListeners();
    await LocalStorage.saveQuizProgress(_lessonId, _committed);
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

  void goTo(int index) {
    if (index < 0 || index >= visibleQuestions.length) return;
    currentIndex = index;
    finished = false;
    notifyListeners();
  }

  /// Final submit. Ends the attempt, clears the saved progress (so the next
  /// open starts fresh) and prints the score to the terminal.
  Future<void> finish() async {
    finished = true;
    notifyListeners();
    await LocalStorage.clearQuizProgress(_lessonId);
    printScore();
  }

  void printScore() {
    final title = questions?.quiz?.title ?? lesson?.title ?? 'Quiz';
    final total = allQuestions.length;

    debugPrint('──────── QUIZ SUBMITTED ────────');
    debugPrint('Quiz      : $title (lesson $_lessonId)');
    debugPrint('Attempted : $attemptedCount of $total');
    debugPrint('Skipped   : $skippedCount');
    if (hasAnswerKey) {
      debugPrint('Correct   : $correctCount');
      debugPrint('Wrong     : $wrongCount');
      debugPrint('TOTAL MARKS: $scoredMarks of ${questions?.totalMarks ?? 0}');
    } else {
      debugPrint('TOTAL MARKS: unavailable — the API did not send the answer key '
          '(isCorrect / correctOptionId).');
    }
    debugPrint('────────────────────────────────');
  }

  /// Wipes the attempt, saved progress included, and starts over from Q1.
  Future<void> retakeFromStart() async {
    answers.clear();
    _submittedNow.clear();
    _carriedOver.clear();
    currentIndex = 0;
    finished = false;
    notifyListeners();
    await LocalStorage.clearQuizProgress(_lessonId);
  }

  // TODO(attempts): POST the answers once the backend has an attempts endpoint.
}
