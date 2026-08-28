// lib/models/saved_model.dart
//
// Bookmarks — saved questions and saved lessons.
//
//   POST   /users/me/saved-questions   { questionId }   upsert, double-tap safe
//   GET    /users/me/saved-questions
//   DELETE /users/me/saved-questions/:id                200 even if not saved
//   …and the same three for /saved-lessons with { lessonId }.
//
// Every response carries `count`, so the bookmark badge updates without a
// second call.
//
// THE RULE THAT SHAPES THIS FILE: a saved question only carries its answer
// when [SavedQuestion.revealed] is true — the student answered it inside a
// finished attempt. Otherwise `correctOptionId`, `explanation` and every
// `options[].isCorrect` come back null, so nobody can save a question
// mid-quiz and read the answer out of their bookmarks. That is why those
// three fields are nullable here; making any of them non-nullable crashes on
// the first unrevealed bookmark.

import 'quiz_model.dart' show QuizOptionModel;

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

/// GET /users/me/saved-questions
class SavedQuestionsResponse {
  final int count;
  final List<SavedQuestion> questions;

  SavedQuestionsResponse({required this.count, required this.questions});

  factory SavedQuestionsResponse.fromJson(Map<String, dynamic> json) {
    final raw = (json['questions'] ?? json['savedQuestions'] ?? json['items']) as List?;
    final items = (raw ?? const [])
        .whereType<Map>()
        .map((q) => SavedQuestion.fromJson(Map<String, dynamic>.from(q)))
        .toList();

    return SavedQuestionsResponse(
      count: json['count'] == null ? items.length : _toInt(json['count']),
      questions: items,
    );
  }
}

class SavedQuestion {
  final int questionId;
  final String questionText;
  final String? questionImageUrl;
  final String? difficulty;
  final double marksCorrect;

  /// A genuine negative. Render as sent, never absolute.
  final double marksIncorrect;

  final int? lessonId;
  final String? lessonTitle;
  final DateTime? savedAt;

  /// True only when this student answered the question inside a finished
  /// attempt. False means the three fields below are deliberately empty.
  final bool revealed;

  /// Null until [revealed]. Never infer the answer from the options either —
  /// their `isCorrect` is stripped in the same way.
  final int? correctOptionId;
  final String? explanation;

  final List<QuizOptionModel> options;

  SavedQuestion({
    required this.questionId,
    required this.questionText,
    this.questionImageUrl,
    this.difficulty,
    required this.marksCorrect,
    required this.marksIncorrect,
    this.lessonId,
    this.lessonTitle,
    this.savedAt,
    required this.revealed,
    this.correctOptionId,
    this.explanation,
    required this.options,
  });

  factory SavedQuestion.fromJson(Map<String, dynamic> json) {
    final raw = (json['options'] as List?) ?? const [];

    return SavedQuestion(
      questionId: _toInt(json['questionId'] ?? json['id']),
      questionText: json['questionText']?.toString() ?? '',
      questionImageUrl: json['questionImageUrl']?.toString(),
      difficulty: json['difficulty']?.toString(),
      marksCorrect: _toDouble(json['marksCorrect']),
      marksIncorrect: _toDouble(json['marksIncorrect']),
      lessonId: json['lessonId'] == null ? null : _toInt(json['lessonId']),
      lessonTitle: json['lessonTitle']?.toString(),
      savedAt: _toDate(json['savedAt']),
      revealed: json['revealed'] == true,
      correctOptionId:
          json['correctOptionId'] == null ? null : _toInt(json['correctOptionId']),
      explanation: json['explanation']?.toString(),
      options: raw
          .whereType<Map>()
          .map((o) => QuizOptionModel.fromJson(Map<String, dynamic>.from(o)))
          .toList(),
    );
  }
}

/// GET /users/me/saved-lessons
class SavedLessonsResponse {
  final int count;
  final List<SavedLesson> lessons;

  SavedLessonsResponse({required this.count, required this.lessons});

  factory SavedLessonsResponse.fromJson(Map<String, dynamic> json) {
    final raw = (json['lessons'] ?? json['savedLessons'] ?? json['items']) as List?;
    final items = (raw ?? const [])
        .whereType<Map>()
        .map((l) => SavedLesson.fromJson(Map<String, dynamic>.from(l)))
        .toList();

    return SavedLessonsResponse(
      count: json['count'] == null ? items.length : _toInt(json['count']),
      lessons: items,
    );
  }
}

class SavedLesson {
  final int lessonId;
  final String title;
  final String? type;
  final String? thumbnailUrl;
  final DateTime? savedAt;

  SavedLesson({
    required this.lessonId,
    required this.title,
    this.type,
    this.thumbnailUrl,
    this.savedAt,
  });

  factory SavedLesson.fromJson(Map<String, dynamic> json) {
    return SavedLesson(
      lessonId: _toInt(json['lessonId'] ?? json['id']),
      title: json['title']?.toString() ?? json['lessonTitle']?.toString() ?? '',
      type: json['type']?.toString(),
      thumbnailUrl: json['thumbnailUrl']?.toString(),
      savedAt: _toDate(json['savedAt']),
    );
  }
}
