// lib/models/daily_quiz_model.dart
//
// MCQ of the Day. Ten questions from the student's course, the same ten for
// everyone, replaced at midnight Gulf time.

int _toInt(dynamic v) =>
    v is int ? v : (v is num ? v.round() : int.tryParse('${v ?? ''}') ?? 0);

int? _toIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.round();
  return int.tryParse(v.toString());
}

double _toDouble(dynamic v) =>
    v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

double? _toDoubleOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

/// What the home card renders. Read-only: it comes from `/users/me/home` and
/// starts nothing.
enum DailyQuizState { notStarted, inProgress, completed }

class DailyQuizSummary {
  final String date;
  final DailyQuizState state;
  final int totalQuestions;
  final int answeredCount;

  /// **Null until completed**, deliberately — a half-finished quiz must not
  /// show a score that is really just "what you have got right so far".
  final int? correctCount;
  final double? score;

  /// Counts back from yesterday until today is done, so an unfinished today
  /// does not zero it. Never render it as lost before the day is over.
  final int currentStreak;

  /// ISO with a real +04:00 offset. The day rolls at midnight Gulf time, not
  /// wherever the device happens to be.
  final DateTime? nextSetAt;

  const DailyQuizSummary({
    required this.date,
    required this.state,
    required this.totalQuestions,
    required this.answeredCount,
    this.correctCount,
    this.score,
    required this.currentStreak,
    this.nextSetAt,
  });

  static DailyQuizState _state(String? raw) => switch (raw) {
        'inProgress' => DailyQuizState.inProgress,
        'completed' => DailyQuizState.completed,
        _ => DailyQuizState.notStarted,
      };

  factory DailyQuizSummary.fromJson(Map<String, dynamic> json) =>
      DailyQuizSummary(
        date: json['date']?.toString() ?? '',
        state: _state(json['state']?.toString()),
        totalQuestions: _toInt(json['totalQuestions']),
        answeredCount: _toInt(json['answeredCount']),
        correctCount: _toIntOrNull(json['correctCount']),
        score: _toDoubleOrNull(json['score']),
        currentStreak: _toInt(json['currentStreak']),
        // Parsed with its offset rather than assumed to be device-local.
        nextSetAt: json['nextSetAt'] == null
            ? null
            : DateTime.tryParse(json['nextSetAt'].toString())?.toLocal(),
      );

  bool get isCompleted => state == DailyQuizState.completed;

  /// Time until the next set, or null when there is nothing to wait for.
  Duration? get timeUntilNextSet {
    final at = nextSetAt;
    if (at == null) return null;
    final left = at.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }
}

class DailyQuizOption {
  final int id;
  final String? optionText;
  final String? optionImageUrl;
  final int displayOrder;

  /// Only present in the finish payload — the answer key does not exist in
  /// the question list.
  final bool? isCorrect;

  const DailyQuizOption({
    required this.id,
    this.optionText,
    this.optionImageUrl,
    this.displayOrder = 0,
    this.isCorrect,
  });

  factory DailyQuizOption.fromJson(Map<String, dynamic> json) => DailyQuizOption(
        id: _toInt(json['id']),
        optionText: json['optionText']?.toString(),
        optionImageUrl: json['optionImageUrl']?.toString(),
        displayOrder: _toInt(json['displayOrder']),
        isCorrect: json['isCorrect'] is bool ? json['isCorrect'] as bool : null,
      );
}

class DailyQuizQuestion {
  final int id;

  /// Nullable — a question can be an image alone.
  final String? questionText;
  final String? questionImageUrl;
  final String? difficulty;
  final double marksCorrect;
  final double marksIncorrect;
  final String? subject;
  final String? topic;
  final List<DailyQuizOption> options;

  const DailyQuizQuestion({
    required this.id,
    this.questionText,
    this.questionImageUrl,
    this.difficulty,
    required this.marksCorrect,
    required this.marksIncorrect,
    this.subject,
    this.topic,
    required this.options,
  });

  static String? _named(dynamic raw) =>
      raw is Map ? raw['name']?.toString() : raw?.toString();

  factory DailyQuizQuestion.fromJson(Map<String, dynamic> json) =>
      DailyQuizQuestion(
        id: _toInt(json['id']),
        questionText: json['questionText']?.toString(),
        questionImageUrl: json['questionImageUrl']?.toString(),
        difficulty: json['difficulty']?.toString(),
        marksCorrect: _toDouble(json['marksCorrect']),
        marksIncorrect: _toDouble(json['marksIncorrect']),
        subject: _named(json['subject']),
        topic: _named(json['topic']),
        options: [
          for (final o in (json['options'] as List?) ?? const [])
            if (o is Map) DailyQuizOption.fromJson(Map<String, dynamic>.from(o)),
        ],
      );
}

/// One already-submitted answer, replayed when resuming a half-done day.
class DailyQuizAnswer {
  final int questionId;
  final int? selectedOptionId;
  final int? correctOptionId;
  final bool isCorrect;
  final double marksAwarded;
  final String? explanation;

  const DailyQuizAnswer({
    required this.questionId,
    this.selectedOptionId,
    this.correctOptionId,
    required this.isCorrect,
    required this.marksAwarded,
    this.explanation,
  });

  factory DailyQuizAnswer.fromJson(Map<String, dynamic> json) => DailyQuizAnswer(
        questionId: _toInt(json['questionId']),
        selectedOptionId: _toIntOrNull(json['selectedOptionId']),
        correctOptionId: _toIntOrNull(json['correctOptionId']),
        isCorrect: json['isCorrect'] == true,
        marksAwarded: _toDouble(json['marksAwarded']),
        explanation: json['explanation']?.toString(),
      );
}

/// Today's frozen set.
class DailyQuizSet {
  /// False for a course whose bank is empty. A real state, not an error.
  final bool available;
  final String? reason;

  final String date;
  final int totalQuestions;
  final int answeredCount;
  final int remainingCount;
  final bool completed;
  final int currentStreak;
  final DateTime? nextSetAt;
  final List<DailyQuizQuestion> questions;

  /// questionId -> what was already submitted today.
  final Map<int, DailyQuizAnswer> answers;

  const DailyQuizSet({
    required this.available,
    this.reason,
    required this.date,
    required this.totalQuestions,
    required this.answeredCount,
    required this.remainingCount,
    required this.completed,
    required this.currentStreak,
    this.nextSetAt,
    required this.questions,
    required this.answers,
  });

  factory DailyQuizSet.fromJson(Map<String, dynamic> json) => DailyQuizSet(
        // Absent means available: only the empty-bank case sends it false.
        available: json['available'] != false,
        reason: json['reason']?.toString(),
        date: json['date']?.toString() ?? '',
        totalQuestions: _toInt(json['totalQuestions']),
        answeredCount: _toInt(json['answeredCount']),
        remainingCount: _toInt(json['remainingCount']),
        completed: json['completed'] == true,
        currentStreak: _toInt(json['currentStreak']),
        nextSetAt: json['nextSetAt'] == null
            ? null
            : DateTime.tryParse(json['nextSetAt'].toString())?.toLocal(),
        questions: [
          for (final q in (json['questions'] as List?) ?? const [])
            if (q is Map)
              DailyQuizQuestion.fromJson(Map<String, dynamic>.from(q)),
        ],
        answers: {
          for (final a in (json['answers'] as List?) ?? const [])
            if (a is Map)
              _toInt(a['questionId']):
                  DailyQuizAnswer.fromJson(Map<String, dynamic>.from(a)),
        },
      );
}

/// What POST /answers returns — the key, and only here.
class DailyQuizAnswerResult {
  final int questionId;
  final int? selectedOptionId;
  final int? correctOptionId;
  final bool isCorrect;
  final String? explanation;
  final double marksAwarded;
  final int answeredCount;
  final int remainingCount;

  /// True when the last question just went in — go straight to the result.
  final bool allAnswered;

  const DailyQuizAnswerResult({
    required this.questionId,
    this.selectedOptionId,
    this.correctOptionId,
    required this.isCorrect,
    this.explanation,
    required this.marksAwarded,
    required this.answeredCount,
    required this.remainingCount,
    required this.allAnswered,
  });

  factory DailyQuizAnswerResult.fromJson(Map<String, dynamic> json) =>
      DailyQuizAnswerResult(
        questionId: _toInt(json['questionId']),
        selectedOptionId: _toIntOrNull(json['selectedOptionId']),
        correctOptionId: _toIntOrNull(json['correctOptionId']),
        isCorrect: json['isCorrect'] == true,
        explanation: json['explanation']?.toString(),
        marksAwarded: _toDouble(json['marksAwarded']),
        answeredCount: _toInt(json['answeredCount']),
        remainingCount: _toInt(json['remainingCount']),
        allAnswered: json['allAnswered'] == true,
      );

  DailyQuizAnswer get asAnswer => DailyQuizAnswer(
        questionId: questionId,
        selectedOptionId: selectedOptionId,
        correctOptionId: correctOptionId,
        isCorrect: isCorrect,
        marksAwarded: marksAwarded,
        explanation: explanation,
      );
}

/// One row of the review.
class DailyQuizResultRow {
  final int questionId;
  final String? questionText;
  final String? subject;
  final String? topic;
  final List<DailyQuizOption> options;
  final int? selectedOptionId;
  final int? correctOptionId;

  /// False means skipped. Skipped scores 0, not the negative mark — it is
  /// its own state and must not be painted as wrong.
  final bool answered;

  final bool isCorrect;
  final double marksAwarded;
  final String? explanation;

  const DailyQuizResultRow({
    required this.questionId,
    this.questionText,
    this.subject,
    this.topic,
    required this.options,
    this.selectedOptionId,
    this.correctOptionId,
    required this.answered,
    required this.isCorrect,
    required this.marksAwarded,
    this.explanation,
  });

  factory DailyQuizResultRow.fromJson(Map<String, dynamic> json) =>
      DailyQuizResultRow(
        questionId: _toInt(json['questionId']),
        questionText: json['questionText']?.toString(),
        subject: json['subject']?.toString(),
        topic: json['topic']?.toString(),
        options: [
          for (final o in (json['options'] as List?) ?? const [])
            if (o is Map) DailyQuizOption.fromJson(Map<String, dynamic>.from(o)),
        ],
        selectedOptionId: _toIntOrNull(json['selectedOptionId']),
        correctOptionId: _toIntOrNull(json['correctOptionId']),
        answered: json['answered'] == true,
        isCorrect: json['isCorrect'] == true,
        marksAwarded: _toDouble(json['marksAwarded']),
        explanation: json['explanation']?.toString(),
      );
}

class DailyQuizResult {
  final String date;
  final int totalQuestions;
  final int answeredCount;
  final int correctCount;
  final int wrongCount;
  final int skippedCount;

  /// Can be negative with negative marking. Rendered as sent.
  final double score;

  /// Out of what was **answered**, not out of ten — so answering one and
  /// getting it right is 100%. Shown beside answeredCount for that reason.
  final int accuracy;

  final int currentStreak;
  final List<DailyQuizResultRow> results;

  const DailyQuizResult({
    required this.date,
    required this.totalQuestions,
    required this.answeredCount,
    required this.correctCount,
    required this.wrongCount,
    required this.skippedCount,
    required this.score,
    required this.accuracy,
    required this.currentStreak,
    required this.results,
  });

  factory DailyQuizResult.fromJson(Map<String, dynamic> json) => DailyQuizResult(
        date: json['date']?.toString() ?? '',
        totalQuestions: _toInt(json['totalQuestions']),
        answeredCount: _toInt(json['answeredCount']),
        correctCount: _toInt(json['correctCount']),
        wrongCount: _toInt(json['wrongCount']),
        skippedCount: _toInt(json['skippedCount']),
        score: _toDouble(json['score']),
        accuracy: _toInt(json['accuracy']),
        currentStreak: _toInt(json['currentStreak']),
        results: [
          for (final r in (json['results'] as List?) ?? const [])
            if (r is Map)
              DailyQuizResultRow.fromJson(Map<String, dynamic>.from(r)),
        ],
      );
}

/// One day in the streak calendar.
class DailyQuizHistoryDay {
  final String date;
  final bool attempted;
  final bool completed;
  final int? correctCount;
  final double? score;

  const DailyQuizHistoryDay({
    required this.date,
    required this.attempted,
    required this.completed,
    this.correctCount,
    this.score,
  });

  factory DailyQuizHistoryDay.fromJson(Map<String, dynamic> json) =>
      DailyQuizHistoryDay(
        date: json['date']?.toString() ?? '',
        attempted: json['attempted'] == true,
        completed: json['completed'] == true,
        correctCount: _toIntOrNull(json['correctCount']),
        score: _toDoubleOrNull(json['score']),
      );
}

class DailyQuizHistory {
  final int currentStreak;

  /// Every day in the window, missed ones included — the gaps are the point
  /// of a calendar. Newest first.
  final List<DailyQuizHistoryDay> days;

  const DailyQuizHistory({required this.currentStreak, required this.days});

  factory DailyQuizHistory.fromJson(Map<String, dynamic> json) =>
      DailyQuizHistory(
        currentStreak: _toInt(json['currentStreak']),
        days: [
          for (final d in (json['history'] as List?) ?? const [])
            if (d is Map)
              DailyQuizHistoryDay.fromJson(Map<String, dynamic>.from(d)),
        ],
      );
}
