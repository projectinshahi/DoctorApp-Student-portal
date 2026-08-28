// lib/models/quiz_model.dart
//
// Student-side quiz models — attempt flow.
//
// Five endpoints, all behind the same auth and the same lesson gates:
//   1. POST /users/me/lessons/:id/quiz-attempts        start or resume
//   2. POST /users/me/quiz-attempts/:id/answers        answer one question
//   3. POST /users/me/quiz-attempts/:id/finish         score the attempt
//   4. GET  /users/me/quiz-attempts/:id                resume / review
//   5. GET  /users/me/lessons/:id/quiz-attempts        history
//
// The answer key is stripped from anything a student could read before
// committing: the start response and an unfinished GET carry NO `isCorrect`,
// `correctOptionId` or `explanation`. They appear only on the answer response
// and on a finished attempt. That is why [QuizOptionModel.isCorrect] is
// nullable — making it required crashes parsing the start response.

double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

DateTime? _toDate(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

/// Every failure the quiz endpoints can return. Each one gets its own screen —
/// collapsing them into "something went wrong" would hide the two that are
/// actionable (course selection and the paywall).
enum QuizErrorKind {
  noCourseSelected, // 409 — Select a course before opening a lesson
  lessonNotFound,   // 404 — draft or wrong id
  notInCourse,      // 403 — lesson belongs to another course
  locked,           // 403 — carries requiredPlans, show the paywall
  noQuizLinked,     // 409 — empty state, not an error
  noQuestions,      // 409 — quiz exists but has no questions yet
  quizInactive,     // 409 — not available right now
  attemptNotFound,  // 404 — also what another student's attempt returns
  attemptFinished,  // 409 — answering an attempt that is already scored
  sessionExpired,   // 401 after refresh
  serverError,      // 5xx — the request was fine, the server failed
  network,          // no connection / unmapped
}

class QuizException implements Exception {
  final QuizErrorKind kind;
  final String message;

  /// Only populated for [QuizErrorKind.locked] — the plans that unlock the
  /// lesson arrive with the 403, so the paywall needs no second call.
  final List<RequiredPlanModel> requiredPlans;

  QuizException(this.kind, this.message, {this.requiredPlans = const []});

  @override
  String toString() => message;
}

class RequiredPlanModel {
  final int id;
  final String title;
  final String? description;
  final double price;
  final int durationDays;

  RequiredPlanModel({
    required this.id,
    required this.title,
    this.description,
    required this.price,
    required this.durationDays,
  });

  factory RequiredPlanModel.fromJson(Map<String, dynamic> json) {
    return RequiredPlanModel(
      id: _toInt(json['id']),
      title: json['title']?.toString() ?? 'Plan',
      description: json['description']?.toString(),
      price: _toDouble(json['price']),
      durationDays: _toInt(json['durationDays'] ?? json['duration_days']),
    );
  }
}

class QuizInfo {
  final int id;
  final String title;
  final int questionCount;
  final String? status;

  QuizInfo({
    required this.id,
    required this.title,
    required this.questionCount,
    this.status,
  });

  factory QuizInfo.fromJson(Map<String, dynamic> json) {
    return QuizInfo(
      id: _toInt(json['id']),
      title: json['title']?.toString() ?? '',
      questionCount: _toInt(json['questionCount'] ?? json['question_count']),
      status: json['status']?.toString(),
    );
  }
}

/// POST /users/me/lessons/:id/quiz-attempts  (201 fresh, 200 resumed)
/// GET  /users/me/quiz-attempts/:attemptId   (branch on [completed])
///
/// One model for both, because they are the same object at two points in its
/// life. A finished GET fills [review]; everything else leaves it null.
class QuizAttempt {
  final int attemptId;

  /// true when an unfinished attempt was picked up instead of a new one being
  /// created. Never start a second attempt on the back of this.
  final bool resumed;

  /// Only a GET reports true. The start endpoint always hands back a live
  /// attempt, so it is false there even when an earlier one was completed.
  final bool completed;

  final int lessonId;
  final QuizInfo? quiz;
  final int totalQuestions;
  final double totalMarks;

  /// questionId -> optionId for everything already answered. Empty on a fresh
  /// attempt; drives the pre-selected option on a resumed one.
  final Map<int, int> answered;

  /// Every question already answered, whichever shape `answered` arrived in —
  /// the server may send bare ids rather than pairs, and then [answered] is
  /// empty while this is not. Test membership here, never `answered.isEmpty`.
  final Set<int> answeredIds;

  /// Server order, already sorted. Never re-sort and never shuffle.
  final List<QuizQuestionModel> questions;

  /// The scored review — present only on a GET of a finished attempt.
  final QuizAttemptResult? review;

  QuizAttempt({
    required this.attemptId,
    required this.resumed,
    required this.completed,
    required this.lessonId,
    this.quiz,
    required this.totalQuestions,
    required this.totalMarks,
    required this.answered,
    required this.answeredIds,
    required this.questions,
    this.review,
  });

  int get answeredCount => answeredIds.length;
  int get remainingCount => totalQuestions - answeredCount;

  /// True when at least one question carries negative marking — worth warning
  /// the student about before they commit an answer.
  bool get hasNegativeMarking => questions.any((q) => q.marksIncorrect < 0);

  /// `answered` is documented as a list, but its element shape is not pinned
  /// down: it may be `[{questionId, optionId}]` or bare `[2, 5]`. Read both
  /// rather than guessing — guessing wrong silently drops a resumed attempt's
  /// selections and the student re-answers work they already did.
  static void _readAnswered(dynamic raw, Map<int, int> into, Set<int> ids) {
    if (raw is! List) return;

    for (final entry in raw) {
      if (entry is Map) {
        final questionId = _toInt(entry['questionId'] ?? entry['id']);
        if (questionId == 0) continue;
        ids.add(questionId);
        final optionId = entry['optionId'] ?? entry['selectedOptionId'];
        if (optionId != null) into[questionId] = _toInt(optionId);
      } else if (entry is num || entry is String) {
        final questionId = _toInt(entry);
        if (questionId != 0) ids.add(questionId);
      }
    }
  }

  factory QuizAttempt.fromJson(Map<String, dynamic> json) {
    final rawQuestions = (json['questions'] as List?) ?? const [];
    final answered = <int, int>{};
    final answeredIds = <int>{};
    _readAnswered(json['answered'], answered, answeredIds);

    final completed = json['completed'] == true;

    return QuizAttempt(
      attemptId: _toInt(json['attemptId'] ?? json['id']),
      resumed: json['resumed'] == true,
      completed: completed,
      lessonId: _toInt(json['lessonId']),
      quiz: json['quiz'] is Map
          ? QuizInfo.fromJson(Map<String, dynamic>.from(json['quiz'] as Map))
          : null,
      totalQuestions: _toInt(json['totalQuestions'] ?? rawQuestions.length),
      totalMarks: _toDouble(json['totalMarks']),
      answered: answered,
      answeredIds: answeredIds,
      questions: rawQuestions
          .whereType<Map>()
          .map((q) => QuizQuestionModel.fromJson(Map<String, dynamic>.from(q)))
          .toList(),
      // A finished GET carries the review inline, in the same shape the finish
      // endpoint returns.
      review: completed ? QuizAttemptResult.fromJson(json) : null,
    );
  }
}

class QuizQuestionModel {
  final int id;
  final String questionText;
  final String? questionImageUrl;
  final String? difficulty;
  final double marksCorrect;

  /// A genuine negative (e.g. -0.5). Render as-is; never take its absolute value.
  final double marksIncorrect;

  final List<QuizOptionModel> options;

  QuizQuestionModel({
    required this.id,
    required this.questionText,
    this.questionImageUrl,
    this.difficulty,
    required this.marksCorrect,
    required this.marksIncorrect,
    required this.options,
  });

  factory QuizQuestionModel.fromJson(Map<String, dynamic> json) {
    final raw = (json['options'] as List?) ?? const [];

    return QuizQuestionModel(
      id: _toInt(json['id'] ?? json['questionId']),
      questionText: json['questionText']?.toString() ?? '',
      questionImageUrl: json['questionImageUrl']?.toString(),
      difficulty: json['difficulty']?.toString(),
      marksCorrect: _toDouble(json['marksCorrect']),
      marksIncorrect: _toDouble(json['marksIncorrect']),
      // Options arrive pre-sorted by displayOrder — do not re-sort, do not shuffle.
      options: raw
          .whereType<Map>()
          .map((o) => QuizOptionModel.fromJson(Map<String, dynamic>.from(o)))
          .toList(),
    );
  }
}

class QuizOptionModel {
  final int id;
  final String optionText;
  final String? optionImageUrl;
  final int displayOrder;

  /// Absent before the student answers, present afterwards. MUST stay
  /// nullable: making it required crashes parsing the start response, which
  /// is the one place it is never sent.
  final bool? isCorrect;

  QuizOptionModel({
    required this.id,
    required this.optionText,
    this.optionImageUrl,
    required this.displayOrder,
    this.isCorrect,
  });

  factory QuizOptionModel.fromJson(Map<String, dynamic> json) {
    return QuizOptionModel(
      id: _toInt(json['id']),
      optionText: json['optionText']?.toString() ?? '',
      optionImageUrl: json['optionImageUrl']?.toString(),
      displayOrder: _toInt(json['displayOrder']),
      isCorrect: json['isCorrect'] is bool ? json['isCorrect'] as bool : null,
    );
  }
}

/// POST /users/me/quiz-attempts/:attemptId/answers
///
/// Scores one question and hands back its key immediately. Re-posting the
/// same questionId overwrites the earlier pick — no error, no duplicate.
class QuizAnswerResponse {
  final int answeredCount;
  final int remainingCount;
  final QuizQuestionResult result;

  QuizAnswerResponse({
    required this.answeredCount,
    required this.remainingCount,
    required this.result,
  });

  factory QuizAnswerResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['result'];

    return QuizAnswerResponse(
      answeredCount: _toInt(json['answeredCount']),
      remainingCount: _toInt(json['remainingCount']),
      result: QuizQuestionResult.fromJson(
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{},
      ),
    );
  }
}

/// POST /users/me/quiz-attempts/:attemptId/finish — and the same shape
/// inlined into a completed GET. Safe to request twice: the second call
/// returns the same review with the original completedAt.
class QuizAttemptResult {
  /// Achieved marks. Genuinely negative when negative marking bites — render
  /// as sent, never absolute.
  final double score;

  /// The perfect score, not the achieved one.
  final double totalMarks;

  final int totalQuestions;
  final int correctCount;
  final int wrongCount;
  final int skippedCount;

  final DateTime? startedAt;
  final DateTime? completedAt;

  /// One entry per question. Look them up by id — do not assume this matches
  /// the order the questions were shown in.
  final List<QuizQuestionResult> results;

  QuizAttemptResult({
    required this.score,
    required this.totalMarks,
    required this.totalQuestions,
    required this.correctCount,
    required this.wrongCount,
    required this.skippedCount,
    this.startedAt,
    this.completedAt,
    required this.results,
  });

  QuizQuestionResult? forQuestion(int questionId) {
    for (final result in results) {
      if (result.questionId == questionId) return result;
    }
    return null;
  }

  factory QuizAttemptResult.fromJson(Map<String, dynamic> json) {
    final raw = (json['results'] as List?) ?? const [];

    return QuizAttemptResult(
      score: _toDouble(json['score']),
      totalMarks: _toDouble(json['totalMarks']),
      totalQuestions: _toInt(json['totalQuestions']),
      correctCount: _toInt(json['correctCount']),
      wrongCount: _toInt(json['wrongCount']),
      skippedCount: _toInt(json['skippedCount']),
      startedAt: _toDate(json['startedAt']),
      completedAt: _toDate(json['completedAt']),
      results: raw
          .whereType<Map>()
          .map((r) => QuizQuestionResult.fromJson(Map<String, dynamic>.from(r)))
          .toList(),
    );
  }
}

/// One question's outcome. Three states, never two: correct, wrong, skipped.
/// A skipped question is NOT a wrong one — it scores 0 and carries no penalty.
class QuizQuestionResult {
  final int questionId;
  final String questionText;
  final String? questionImageUrl;

  /// null when the student skipped this question.
  final int? selectedOptionId;

  /// The answer. Use this rather than scanning [options] — and test it BEFORE
  /// [selectedOptionId] when colouring, or a correct answer (which matches
  /// both) gets painted red.
  final int correctOptionId;

  final bool isCorrect;

  /// false = skipped. Distinct from wrong.
  final bool answered;

  /// marksCorrect, marksIncorrect, or 0 when skipped. Can be negative.
  final double marksAwarded;

  /// Nullable — plenty of questions have none. Don't reserve space for it.
  final String? explanation;

  /// These carry `isCorrect`, unlike the ones on the start response.
  final List<QuizOptionModel> options;

  QuizQuestionResult({
    required this.questionId,
    required this.questionText,
    this.questionImageUrl,
    this.selectedOptionId,
    required this.correctOptionId,
    required this.isCorrect,
    required this.answered,
    required this.marksAwarded,
    this.explanation,
    required this.options,
  });

  bool get isSkipped => !answered;
  bool get isWrong => answered && !isCorrect;

  QuizOptionModel? get correctOption {
    for (final option in options) {
      if (option.id == correctOptionId) return option;
    }
    return null;
  }

  factory QuizQuestionResult.fromJson(Map<String, dynamic> json) {
    final raw = (json['options'] as List?) ?? const [];

    return QuizQuestionResult(
      questionId: _toInt(json['questionId'] ?? json['id']),
      questionText: json['questionText']?.toString() ?? '',
      questionImageUrl: json['questionImageUrl']?.toString(),
      selectedOptionId:
          json['selectedOptionId'] == null ? null : _toInt(json['selectedOptionId']),
      correctOptionId: _toInt(json['correctOptionId']),
      isCorrect: json['isCorrect'] == true,
      answered: json['answered'] == true,
      marksAwarded: _toDouble(json['marksAwarded']),
      explanation: json['explanation']?.toString(),
      options: raw
          .whereType<Map>()
          .map((o) => QuizOptionModel.fromJson(Map<String, dynamic>.from(o)))
          .toList(),
    );
  }
}

/// GET /users/me/lessons/:id/quiz-attempts — summary rows, newest first.
/// Server order is the display order; never re-sort.
class QuizAttemptSummary {
  final int attemptId;
  final bool completed;
  final int totalQuestions;
  final int answeredCount;
  final int correctCount;
  final double score;

  QuizAttemptSummary({
    required this.attemptId,
    required this.completed,
    required this.totalQuestions,
    required this.answeredCount,
    required this.correctCount,
    required this.score,
  });

  factory QuizAttemptSummary.fromJson(Map<String, dynamic> json) {
    return QuizAttemptSummary(
      attemptId: _toInt(json['attemptId'] ?? json['id']),
      completed: json['completed'] == true,
      totalQuestions: _toInt(json['totalQuestions']),
      answeredCount: _toInt(json['answeredCount']),
      correctCount: _toInt(json['correctCount']),
      score: _toDouble(json['score']),
    );
  }

  static List<QuizAttemptSummary> listFromJson(Map<String, dynamic> json) {
    final raw = (json['attempts'] as List?) ?? const [];
    return raw
        .whereType<Map>()
        .map((a) => QuizAttemptSummary.fromJson(Map<String, dynamic>.from(a)))
        .toList();
  }
}

/// GET /users/me/quiz-attempts?status=in_progress  (also `completed`, `all`)
///
/// Carries lessonId and lessonTitle, so the QBank "Continue MCQs" card can
/// label a row and deep-link straight into the quiz.
class InProgressAttempt {
  final int attemptId;
  final int lessonId;
  final String lessonTitle;
  final String? chapterTitle;
  final int answeredCount;
  final int totalQuestions;
  final bool completed;
  final DateTime? startedAt;

  InProgressAttempt({
    required this.attemptId,
    required this.lessonId,
    required this.lessonTitle,
    this.chapterTitle,
    required this.answeredCount,
    required this.totalQuestions,
    required this.completed,
    this.startedAt,
  });

  int get remainingCount => totalQuestions - answeredCount;

  factory InProgressAttempt.fromJson(Map<String, dynamic> json) {
    return InProgressAttempt(
      attemptId: _toInt(json['attemptId'] ?? json['id']),
      lessonId: _toInt(json['lessonId']),
      lessonTitle: json['lessonTitle']?.toString() ?? 'Quiz',
      chapterTitle: json['chapterTitle']?.toString(),
      answeredCount: _toInt(json['answeredCount']),
      totalQuestions: _toInt(json['totalQuestions']),
      completed: json['completed'] == true,
      startedAt: _toDate(json['startedAt']),
    );
  }

  static List<InProgressAttempt> listFromJson(Map<String, dynamic> json) {
    final raw = (json['attempts'] as List?) ?? const [];
    return raw
        .whereType<Map>()
        .map((a) => InProgressAttempt.fromJson(Map<String, dynamic>.from(a)))
        .toList();
  }
}
