// lib/models/quiz_model.dart
//
// Student-side quiz models.
//
// The backend strips the answer key before it reaches the app: `isCorrect`,
// `explanation`, `correctOptionId` and `tags` are NEVER present in student
// responses. Nothing here may depend on them.

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

/// Every failure the quiz endpoints can return. Each one gets its own screen —
/// collapsing them into "something went wrong" would hide the two that are
/// actionable (course selection and the paywall).
enum QuizErrorKind {
  noCourseSelected, // 409 — Select a course before opening a lesson
  lessonNotFound,   // 404 — draft or wrong id
  notInCourse,      // 403 — lesson belongs to another course
  locked,           // 403 — carries requiredPlans, show the paywall
  noQuizLinked,     // 409 — empty state, not an error
  quizInactive,     // 409 — not available right now
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

/// GET /api/users/me/lessons/:id
/// → { lesson, requiredPlans, requiredPlan, unlockOptions }
///
/// A locked lesson still answers 200 with its media stripped, carrying the
/// paywall plans so the sheet has its price without a second call.
class QuizLessonDetail {
  final int id;
  final String title;
  final String type; // video | text | quiz
  final int? quizId;
  final QuizInfo? quiz; // null when the lesson is locked
  final bool locked;

  /// Three shapes of the same thing, in the order the API prefers them.
  /// Read [paywallPlans] instead of picking one by hand.
  final List<RequiredPlanModel> requiredPlans;
  final RequiredPlanModel? requiredPlan;
  final List<RequiredPlanModel> unlockOptions;

  QuizLessonDetail({
    required this.id,
    required this.title,
    required this.type,
    this.quizId,
    this.quiz,
    required this.locked,
    this.requiredPlans = const [],
    this.requiredPlan,
    this.unlockOptions = const [],
  });

  bool get isQuiz => type == 'quiz';

  /// A quiz lesson with no quiz linked to it. Calling the questions endpoint
  /// for one of these returns 409 — check this first and show the empty state.
  bool get hasQuiz => isQuiz && (quizId != null || quiz != null);

  /// Everything that would unlock this lesson, whichever field carried it.
  List<RequiredPlanModel> get paywallPlans {
    if (requiredPlans.isNotEmpty) return requiredPlans;
    if (requiredPlan != null) return [requiredPlan!];
    return unlockOptions;
  }

  static List<RequiredPlanModel> _plans(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((p) => RequiredPlanModel.fromJson(Map<String, dynamic>.from(p)))
        .toList();
  }

  factory QuizLessonDetail.fromJson(Map<String, dynamic> json) {
    final lesson = (json['lesson'] is Map ? json['lesson'] : json) as Map<String, dynamic>;
    final single = json['requiredPlan'];

    return QuizLessonDetail(
      id: _toInt(lesson['id']),
      title: lesson['title']?.toString() ?? '',
      type: lesson['type']?.toString() ?? 'video',
      quizId: lesson['quizId'] == null ? null : _toInt(lesson['quizId']),
      quiz: lesson['quiz'] is Map ? QuizInfo.fromJson(lesson['quiz']) : null,
      locked: lesson['locked'] == true,
      requiredPlans: _plans(json['requiredPlans']),
      requiredPlan: single is Map
          ? RequiredPlanModel.fromJson(Map<String, dynamic>.from(single))
          : null,
      unlockOptions: _plans(json['unlockOptions']),
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

/// GET /api/users/me/lessons/:id/quiz-questions
class QuizQuestionsModel {
  final int lessonId;
  final QuizInfo? quiz;
  final int totalQuestions;
  final double totalMarks;
  final List<QuizQuestionModel> questions;

  QuizQuestionsModel({
    required this.lessonId,
    this.quiz,
    required this.totalQuestions,
    required this.totalMarks,
    required this.questions,
  });

  /// True when at least one question carries negative marking — worth
  /// warning the student about before they start.
  bool get hasNegativeMarking => questions.any((q) => q.marksIncorrect < 0);

  factory QuizQuestionsModel.fromJson(Map<String, dynamic> json) {
    final raw = (json['questions'] as List?) ?? const [];

    return QuizQuestionsModel(
      lessonId: _toInt(json['lessonId']),
      quiz: json['quiz'] is Map ? QuizInfo.fromJson(json['quiz']) : null,
      totalQuestions: _toInt(json['totalQuestions'] ?? raw.length),
      totalMarks: _toDouble(json['totalMarks']),
      questions: raw.map((q) => QuizQuestionModel.fromJson(Map<String, dynamic>.from(q))).toList(),
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

  /// Answer key. Both are null on responses that strip it — the UI must
  /// degrade to "no result available" rather than guessing.
  final String? explanation;
  final int? correctOptionId;

  final List<QuizOptionModel> options;

  QuizQuestionModel({
    required this.id,
    required this.questionText,
    this.questionImageUrl,
    this.difficulty,
    required this.marksCorrect,
    required this.marksIncorrect,
    this.explanation,
    this.correctOptionId,
    required this.options,
  });

  /// The correct option, taken from `correctOptionId` or an option's own
  /// `isCorrect` flag. Null when the answer key wasn't sent.
  QuizOptionModel? get correctOption {
    for (final option in options) {
      if (option.id == correctOptionId || option.isCorrect == true) return option;
    }
    return null;
  }

  bool get hasAnswerKey => correctOption != null;

  factory QuizQuestionModel.fromJson(Map<String, dynamic> json) {
    final raw = (json['options'] as List?) ?? const [];

    return QuizQuestionModel(
      id: _toInt(json['id']),
      questionText: json['questionText']?.toString() ?? '',
      questionImageUrl: json['questionImageUrl']?.toString(),
      difficulty: json['difficulty']?.toString(),
      marksCorrect: _toDouble(json['marksCorrect']),
      marksIncorrect: _toDouble(json['marksIncorrect']),
      explanation: json['explanation']?.toString(),
      correctOptionId:
          json['correctOptionId'] == null ? null : _toInt(json['correctOptionId']),
      // Options arrive pre-sorted by displayOrder — do not re-sort, do not shuffle.
      options: raw.map((o) => QuizOptionModel.fromJson(Map<String, dynamic>.from(o))).toList(),
    );
  }
}

class QuizOptionModel {
  final int id;
  final String optionText;
  final String? optionImageUrl;
  final int displayOrder;

  /// Never sent to students. Nullable on purpose so a model shared with an
  /// admin build doesn't crash on the first parse — do not rely on it.
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
