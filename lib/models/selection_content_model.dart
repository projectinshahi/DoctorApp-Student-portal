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

  /// Whole-course progress, same shape as a chapter's.
  final ProgressInfo? progress;

  SelectionContentModel({
    this.course,
    this.courseType,
    this.hasPaid = false,
    required this.chapters,
    this.progress,
  });

  /// Same tree with new chapters. Used to patch one lesson's progress in
  /// place; the course-level rollup is the server's and is left alone until
  /// the next fetch corrects it.
  SelectionContentModel withChapters(List<StudentChapterModel> chapters) =>
      SelectionContentModel(
        course: course,
        courseType: courseType,
        hasPaid: hasPaid,
        chapters: chapters,
        progress: progress,
      );

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
      progress: ProgressInfo.maybeFrom(json['progress']),
    );
  }

  bool get hasSelection => course != null;

  /// Every lesson in the tree, chapter order preserved.
  List<StudentLessonModel> get allLessons =>
      [for (final chapter in chapters) ...chapter.lessons];

  /// Chapters finished, for the home screen's counter.
  ///
  /// A module is a chapter, so this is NOT the course-level `progress` block —
  /// that one counts lessons ("4 of 6"), and printing it as modules would
  /// claim four chapters were done when there are only three.
  ///
  /// `percent` is capped at 99 by the server until a chapter is genuinely
  /// finished, so `isComplete` needs no other check.
  int get completedModules =>
      chapters.where((chapter) => chapter.progress?.isComplete == true).length;
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

  /// How far through this chapter the student is. Null when the server did
  /// not send it — which is not the same as zero, so callers must not print
  /// "0%" for an absent block.
  final ProgressInfo? progress;

  StudentChapterModel({
    required this.id,
    required this.title,
    required this.displayOrder,
    required this.lessons,
    this.progress,
  });

  StudentChapterModel withLessons(List<StudentLessonModel> lessons) =>
      StudentChapterModel(
        id: id,
        title: title,
        displayOrder: displayOrder,
        lessons: lessons,
        progress: progress,
      );

  factory StudentChapterModel.fromJson(Map<String, dynamic> json) {
    // Server order is authoritative — mapped as-is, never sorted.
    final lessons = (json['lessons'] ?? json['lesson'] ?? json['items'] ?? []) as List<dynamic>;

    return StudentChapterModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      displayOrder: json['displayOrder'] ?? json['display_order'] ?? 0,
      lessons: lessons.map((l) => StudentLessonModel.fromJson(l)).toList(),
      progress: ProgressInfo.maybeFrom(json['progress']),
    );
  }
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

  /// Where this student stopped watching, in seconds. 0 means "never played",
  /// which is also what a lesson with no video reports.
  ///
  /// This SURVIVES the lock strip: a locked lesson comes back with
  /// `videoUrl: null` but keeps its position, so someone who lets a
  /// subscription lapse and renews has not lost their place. Never read
  /// `locked: true` as "no progress".
  final int lastPositionSeconds;

  /// Whether this lesson is bookmarked, sent on every lesson everywhere —
  /// the tree, a single lesson, the saved list. Read this instead of
  /// searching the saved list for the id.
  final bool isSaved;

  /// Server's verdict on whether this lesson is done — for a video because
  /// the player said so, for a quiz because an attempt was submitted.
  ///
  /// One flag for both. Do not branch on `type` to work it out; the server
  /// has already decided, and re-deriving it here is how the two answers
  /// drift apart.
  final bool completed;

  /// How much of the video the server has seen reported, 0-100.
  ///
  /// **Nullable, and null is not zero.** Null means the video's length is not
  /// known yet, so no percentage can be computed — rendering that as a 0% bar
  /// would read as "never watched" for a lesson the student is halfway
  /// through. Always null on notes and quizzes; only videos have a share.
  final int? watchedPercent;

  /// The video's length, once the server has it. Null on an older upload
  /// nobody has played since duration reporting started.
  final int? durationSeconds;

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
    this.lastPositionSeconds = 0,
    this.isSaved = false,
    this.completed = false,
    this.watchedPercent,
    this.durationSeconds,
  });

  /// Patches a row in place after a progress write, so the tick appears while
  /// the video is still playing instead of waiting for the next content
  /// fetch.
  StudentLessonModel copyWith({
    bool? completed,
    int? lastPositionSeconds,
    int? watchedPercent,
    int? durationSeconds,
    bool? isSaved,
  }) =>
      StudentLessonModel(
        id: id,
        title: title,
        description: description,
        type: type,
        content: content,
        videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl,
        noteUrl: noteUrl,
        noteFileType: noteFileType,
        displayOrder: displayOrder,
        isFreePreview: isFreePreview,
        accessType: accessType,
        locked: locked,
        quizId: quizId,
        quiz: quiz,
        quizQuestionCount: quizQuestionCount,
        plans: plans,
        planIds: planIds,
        attempt: attempt,
        lastPositionSeconds: lastPositionSeconds ?? this.lastPositionSeconds,
        isSaved: isSaved ?? this.isSaved,
        // A rewind never un-finishes a lesson: once the server has said
        // completed, nothing local takes the tick away.
        completed: completed == true || this.completed,
        watchedPercent: watchedPercent ?? this.watchedPercent,
        durationSeconds: durationSeconds ?? this.durationSeconds,
      );

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
      lastPositionSeconds: _toInt(
        json['lastPositionSeconds'] ?? json['last_position_seconds'],
      ),
      completed: json['completed'] == true,
      // Read as nullable on purpose — see the field comment.
      watchedPercent: _toIntOrNull(json['watchedPercent']),
      durationSeconds: _toIntOrNull(json['durationSeconds']),
      isSaved: json['isSaved'] == true,
    );
  }

  bool get isQuiz => type == 'quiz';

  bool get hasVideo => videoUrl != null && videoUrl!.isNotEmpty;
  bool get hasNote => noteUrl != null && noteUrl!.isNotEmpty;
  bool get hasMedia => hasVideo || hasNote;

  /// Belongs in the video/notes lists. Quizzes live in QBank, never here.
  /// `locked` is kept in: the server strips videoUrl/noteUrl on locked
  /// lessons, so filtering on media alone would hide exactly the paid
  /// content these lists exist to advertise.
  bool get isWatchable => !isQuiz && (hasMedia || locked);

  /// Video or note, decided by `type` rather than by which URL happens to be
  /// present.
  ///
  /// A locked lesson has its `videoUrl` stripped to null, so [hasVideo] is
  /// false for every premium video — partitioning on that would file the
  /// whole paid catalogue under notes. `type` survives the lock; the URL
  /// does not.
  bool get isVideo => type == 'video' || hasVideo;

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

  /// The latest attempt's score — not the best. Genuinely negative when
  /// negative marking bites. Render as sent.
  final double score;

  /// How many attempts this student has made that have at least one answer.
  /// Every retake adds one.
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

/// A completed/total pair with the server's own percentage, used for both a
/// chapter and the whole course.
class ProgressInfo {
  final int completedLessons;

  /// Every lesson that counts toward completion — **locked ones included**.
  ///
  /// Dropping locked lessons from the denominator would show a free student
  /// "2 of 2, 100%" on a chapter where eight premium lessons remain, which
  /// reads as "you have finished this" rather than "you have finished what
  /// you can reach".
  final int totalLessons;

  /// The server's percentage, which deliberately caps at 99 until the last
  /// lesson is genuinely done. That makes `percent == 100` safe to use on
  /// its own as a "complete" badge.
  final int percent;

  const ProgressInfo({
    required this.completedLessons,
    required this.totalLessons,
    required this.percent,
  });

  /// Null when the block is absent — an unsent progress object is unknown,
  /// not zero, and rendering "0%" for it would be a lie.
  static ProgressInfo? maybeFrom(dynamic raw) {
    if (raw is! Map) return null;
    final json = Map<String, dynamic>.from(raw);

    final total = _toInt(json['totalLessons'] ?? json['total']);
    final completed = _toInt(json['completedLessons'] ?? json['completed']);

    return ProgressInfo(
      completedLessons: completed,
      totalLessons: total,
      // Computed only as a fallback: an empty chapter is 0%, never a divide
      // by zero, and never 100% for having nothing in it.
      percent: json['percent'] != null
          ? _toInt(json['percent'])
          : (total == 0 ? 0 : ((completed * 100) ~/ total).clamp(0, 100)),
    );
  }

  bool get isComplete => percent >= 100;
}

/// Null stays null. Used where the server distinguishes "not known" from
/// zero — `watchedPercent` most of all.
int? _toIntOrNull(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value.toString());
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}') ?? 0;
}
