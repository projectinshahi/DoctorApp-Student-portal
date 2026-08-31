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
import 'selection_content_model.dart' show StudentLessonModel;

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
        .map((e) => SavedLesson.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return SavedLessonsResponse(
      count: json['count'] is int ? json['count'] as int : items.length,
      lessons: items,
    );
  }
}

/// One bookmarked lesson.
///
/// The row the server sends IS a lesson — id, type, videoUrl, locked, plans,
/// attempt, lastPositionSeconds and all — so it is parsed with the same model
/// the content tree uses. That keeps one parser for one shape, and means a
/// bookmark can open the lesson screen with nothing missing.
class SavedLesson {
  final StudentLessonModel lesson;

  /// Shown as the card's subtitle. Only the saved list carries it; the tree
  /// nests lessons under their chapter instead.
  final String? chapterTitle;

  final DateTime? savedAt;

  SavedLesson({required this.lesson, this.chapterTitle, this.savedAt});

  factory SavedLesson.fromJson(Map<String, dynamic> json) {
    final chapter = json['chapter'];
    return SavedLesson(
      lesson: StudentLessonModel.fromJson(json),
      chapterTitle: chapter is Map ? chapter['title']?.toString() : null,
      savedAt: _toDate(json['savedAt']),
    );
  }

  int get lessonId => lesson.id;
  String get title => lesson.title;
  String get type => lesson.type;
}

/// Everything `GET /users/me/saved?type=…` returns in one call.
class SavedBundle {
  /// Always the FULL set of counts, whatever `type` was asked for. The filter
  /// chips bind to this, never to a list's length — filtering to videos must
  /// not make the MCQ chip read zero.
  final Map<String, int> counts;

  final List<SavedQuestion> questions;
  final List<SavedLesson> lessons;

  const SavedBundle({
    required this.counts,
    required this.questions,
    required this.lessons,
  });

  static const empty = SavedBundle(counts: {}, questions: [], lessons: []);

  factory SavedBundle.fromJson(Map<String, dynamic> json) {
    final rawCounts = json['counts'];
    return SavedBundle(
      counts: rawCounts is Map
          ? {
              for (final entry in rawCounts.entries)
                entry.key.toString(): _toInt(entry.value),
            }
          : const {},
      questions: SavedQuestionsResponse.fromJson(json).questions,
      lessons: SavedLessonsResponse.fromJson(json).lessons,
    );
  }

  int countOf(String type) => counts[type] ?? 0;

  /// Lessons of one type. `note` is not a server filter — notes are `text` —
  /// so the split happens here rather than in a second request.
  List<SavedLesson> lessonsOfType(String type) =>
      lessons.where((saved) => saved.type == type).toList();
}
