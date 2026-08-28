// lib/models/selection_content_model.dart
//
// GET /api/users/me/selection/content — the whole student tree in one call:
//   Course → CourseType → Chapter → Lesson
// There is no "subject" in this hierarchy. Subject/Topic belong to the
// question bank; the two meet only at a quiz-type lesson, via quizId.
//
// Chapters and lessons arrive already sorted by displayOrder. Do NOT re-sort.
// Drafts are filtered server-side, so nothing here checks `status`.
//
// locked == true means the server already stripped the media: videoUrl,
// noteUrl, content and quiz all come back null. Show the lock badge and the
// paywall from `plans` — never try to load anything.

import 'quiz_model.dart' show QuizInfo, RequiredPlanModel;

class SelectionContentModel {
  final SelectedCourseInfo? course;
  final SelectedCourseTypeInfo? courseType;
  final bool hasPaid;
  final List<StudentChapterModel> chapters;

  SelectionContentModel({
    this.course,
    this.courseType,
    this.hasPaid = false,
    required this.chapters,
  });

  static List<dynamic> _readChapterList(Map<String, dynamic> json) {
    if (json['chapters'] != null) return json['chapters'] as List<dynamic>;
    if (json['course'] is Map && json['course']['chapters'] != null) {
      return json['course']['chapters'] as List<dynamic>;
    }
    if (json['selectedCourse'] is Map && json['selectedCourse']['chapters'] != null) {
      return json['selectedCourse']['chapters'] as List<dynamic>;
    }
    if (json['data'] is Map && json['data']['chapters'] != null) {
      return json['data']['chapters'] as List<dynamic>;
    }
    return const [];
  }

  factory SelectionContentModel.fromJson(Map<String, dynamic> json) {
    final chapters = _readChapterList(json);

    return SelectionContentModel(
      course: json['course'] != null ? SelectedCourseInfo.fromJson(json['course']) : null,
      courseType: json['courseType'] != null ? SelectedCourseTypeInfo.fromJson(json['courseType']) : null,
      hasPaid: json['hasPaid'] ?? false,
      chapters: chapters.map((c) => StudentChapterModel.fromJson(c)).toList(),
    );
  }

  bool get hasSelection => course != null;

  /// Every lesson in the tree, chapter order preserved.
  List<StudentLessonModel> get allLessons =>
      [for (final chapter in chapters) ...chapter.lessons];
}

class SelectedCourseInfo {
  final int id;
  final String title;
  final String? thumbnail;
  final String accessType;

  SelectedCourseInfo({
    required this.id,
    required this.title,
    this.thumbnail,
    required this.accessType,
  });

  factory SelectedCourseInfo.fromJson(Map<String, dynamic> json) {
    return SelectedCourseInfo(
      id: json['id'],
      title: json['title'] ?? '',
      thumbnail: json['thumbnail'],
      accessType: json['accessType'] ?? 'free',
    );
  }

  bool get isPremium => accessType == 'premium';
}

class SelectedCourseTypeInfo {
  final int id;
  final String title;
  final String? description;
  final String accessType;

  SelectedCourseTypeInfo({
    required this.id,
    required this.title,
    this.description,
    required this.accessType,
  });

  factory SelectedCourseTypeInfo.fromJson(Map<String, dynamic> json) {
    return SelectedCourseTypeInfo(
      id: json['id'],
      title: json['title'] ?? '',
      description: json['description'],
      accessType: json['accessType'] ?? 'free',
    );
  }
}

class StudentChapterModel {
  final int id;
  final String title;
  final int displayOrder;
  final List<StudentLessonModel> lessons;

  StudentChapterModel({
    required this.id,
    required this.title,
    required this.displayOrder,
    required this.lessons,
  });

  factory StudentChapterModel.fromJson(Map<String, dynamic> json) {
    // Server order is authoritative — mapped as-is, never sorted.
    final lessons = (json['lessons'] ?? json['lesson'] ?? json['items'] ?? []) as List<dynamic>;

    return StudentChapterModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      displayOrder: json['displayOrder'] ?? json['display_order'] ?? 0,
      lessons: lessons.map((l) => StudentLessonModel.fromJson(l)).toList(),
    );
  }

  /// Quiz lessons only — what the QBank listing shows.
  List<StudentLessonModel> get quizLessons =>
      lessons.where((l) => l.isQuiz).toList();
}

class StudentLessonModel {
  final int id;
  final String title;
  final String? description;
  final String type; // video | text | quiz
  final String? content;
  final String? videoUrl;
  final String? thumbnailUrl;
  final String? noteUrl;
  final String? noteFileType;
  final int displayOrder;
  final bool isFreePreview;
  final String accessType;
  final bool locked;

  /// Present on quiz lessons. `quiz` carries the questionCount when the
  /// server sends the nested object; `quizQuestionCount` is null when it
  /// doesn't — null means "unknown", not "zero".
  final int? quizId;
  final QuizInfo? quiz;
  final int? quizQuestionCount;

  /// The plans that unlock this lesson. Populated on locked lessons so the
  /// paywall has its prices without a second call. `planIds` is the same
  /// list reduced to ids, for when only membership matters.
  final List<RequiredPlanModel> plans;
  final List<int> planIds;

  /// This student's latest attempt on this lesson's quiz, embedded in the
  /// content tree so the QBank listing needs no per-lesson call.
  ///
  /// Null on every non-quiz lesson AND on a quiz never started — nullable
  /// everywhere, not just on video lessons.
  final LessonAttemptInfo? attempt;

  StudentLessonModel({
    required this.id,
    required this.title,
    this.description,
    required this.type,
    this.content,
    this.videoUrl,
    this.thumbnailUrl,
    this.noteUrl,
    this.noteFileType,
    required this.displayOrder,
    required this.isFreePreview,
    required this.accessType,
    required this.locked,
    this.quizId,
    this.quiz,
    this.quizQuestionCount,
    this.plans = const [],
    this.planIds = const [],
    this.attempt,
  });

  static List<RequiredPlanModel> _readPlans(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((p) => RequiredPlanModel.fromJson(Map<String, dynamic>.from(p)))
        .toList();
  }

  static List<int> _readPlanIds(dynamic raw, List<RequiredPlanModel> plans) {
    if (raw is List) {
      return raw
          .map((e) => e is num ? e.toInt() : int.tryParse(e.toString()))
          .whereType<int>()
          .toList();
    }
    return plans.map((p) => p.id).toList();
  }

  factory StudentLessonModel.fromJson(Map<String, dynamic> json) {
    final typeValue = json['type'] ?? json['lessonType'] ?? 'video';
    final videoUrlValue = json['videoUrl'] ?? json['video_url'] ?? json['video'];
    final thumbnailUrlValue = json['thumbnailUrl'] ?? json['thumbnail_url'] ?? json['thumbnail'];
    final noteUrlValue = json['noteUrl'] ?? json['note_url'] ?? json['notesUrl'];
    final accessTypeValue = json['accessType'] ?? json['access_type'] ?? 'free';
    final freePreviewValue = json['isFreePreview'] ?? json['is_free_preview'] ?? false;
    final lockedValue = json['locked'] ?? json['is_locked'] ?? false;
    final quizValue = json['quiz'] is Map
        ? QuizInfo.fromJson(Map<String, dynamic>.from(json['quiz'] as Map))
        : null;
    final plansValue = _readPlans(json['plans']);

    return StudentLessonModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? json['summary'],
      type: typeValue,
      content: json['content'] ?? json['body'],
      videoUrl: videoUrlValue,
      thumbnailUrl: thumbnailUrlValue,
      noteUrl: noteUrlValue,
      noteFileType: json['noteFileType'] ?? json['note_file_type'],
      displayOrder: json['displayOrder'] ?? json['display_order'] ?? 0,
      isFreePreview: freePreviewValue,
      accessType: accessTypeValue,
      locked: lockedValue,
      quizId: json['quizId'] ?? json['quiz_id'] ?? quizValue?.id,
      quiz: quizValue,
      quizQuestionCount: json['questionCount'] ?? quizValue?.questionCount,
      plans: plansValue,
      planIds: _readPlanIds(json['planIds'], plansValue),
      attempt: json['attempt'] is Map
          ? LessonAttemptInfo.fromJson(Map<String, dynamic>.from(json['attempt'] as Map))
          : null,
    );
  }

  bool get isQuiz => type == 'quiz';

  /// A quiz lesson with no quiz attached. The questions endpoint answers 409
  /// for these, so the app must show the empty state instead of calling it.
  bool get hasQuiz => isQuiz && quizId != null;

  bool get hasVideo => videoUrl != null && videoUrl!.isNotEmpty;
  bool get hasNote => noteUrl != null && noteUrl!.isNotEmpty;
  bool get hasMedia => hasVideo || hasNote;

  /// Belongs in the video/notes lists. Quizzes live in QBank, never here.
  /// `locked` is kept in: the server strips videoUrl/noteUrl on locked
  /// lessons, so filtering on media alone would hide exactly the paid
  /// content these lists exist to advertise.
  bool get isWatchable => !isQuiz && (hasMedia || locked);

  bool get isPremium => accessType == 'premium';
}

/// The `attempt` object the content tree carries on each quiz lesson. Enough
/// to label the row — Start / Continue / Review — with no second call.
class LessonAttemptInfo {
  final int attemptId;
  final bool completed;
  final int answeredCount;
  final int remainingCount;
  final int correctCount;

  /// Genuinely negative when negative marking bites. Render as sent.
  final double score;

  /// How many attempts this student has made. The app allows one, but the
  /// API does not enforce that, so this can legitimately be more than 1.
  final int attemptCount;

  LessonAttemptInfo({
    required this.attemptId,
    required this.completed,
    required this.answeredCount,
    required this.remainingCount,
    required this.correctCount,
    required this.score,
    required this.attemptCount,
  });

  /// Half-finished and actually worth resuming. An attempt with nothing
  /// answered reads as "Start", because that is what continuing it would be.
  bool get isInProgress => !completed && answeredCount > 0;

  factory LessonAttemptInfo.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    int toInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

    return LessonAttemptInfo(
      attemptId: toInt(json['attemptId']),
      completed: json['completed'] == true,
      answeredCount: toInt(json['answeredCount']),
      remainingCount: toInt(json['remainingCount']),
      correctCount: toInt(json['correctCount']),
      score: toDouble(json['score']),
      attemptCount: toInt(json['attemptCount']),
    );
  }
}
