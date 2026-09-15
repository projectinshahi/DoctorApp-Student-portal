// lib/models/home_summary_model.dart
//
// What GET /users/me/home carries. One call, no side effects.

import 'daily_quiz_model.dart';

int _toInt(dynamic v) =>
    v is int ? v : (v is num ? v.round() : int.tryParse('${v ?? ''}') ?? 0);

int? _toIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.round();
  return int.tryParse(v.toString());
}

/// A video the student is part-way through.
///
/// Carries its own `videoUrl`, which is the point of the row: tapping a card
/// starts playback straight away. Fetching the lesson first is the hop that
/// makes a Continue Watching row slower than the outline it exists to
/// shortcut.
class InProgressVideo {
  final int lessonId;
  final String title;
  final String? thumbnailUrl;
  final String? chapterTitle;

  final int lastPositionSeconds;

  /// Both nullable, and **null is not zero**: it means the video's length is
  /// not stored yet, so no share can be computed. A bar pinned at 0% reads as
  /// "never started" for a video someone is 40 seconds into. It fills in by
  /// itself once the player reports a duration.
  final int? durationSeconds;
  final int? watchedPercent;

  /// Null when [locked]. The resume point is not the media, so a lapsed
  /// subscriber still sees where they were — they just get the paywall
  /// instead of the player.
  final String? videoUrl;

  final bool locked;
  final DateTime? updatedAt;

  const InProgressVideo({
    required this.lessonId,
    required this.title,
    this.thumbnailUrl,
    this.chapterTitle,
    required this.lastPositionSeconds,
    this.durationSeconds,
    this.watchedPercent,
    this.videoUrl,
    required this.locked,
    this.updatedAt,
  });

  factory InProgressVideo.fromJson(Map<String, dynamic> json) {
    final chapter = json['chapter'];

    return InProgressVideo(
      lessonId: _toInt(json['lessonId'] ?? json['id']),
      title: json['title']?.toString() ?? 'Lesson',
      thumbnailUrl: json['thumbnailUrl']?.toString(),
      chapterTitle: chapter is Map ? chapter['title']?.toString() : null,
      lastPositionSeconds: _toInt(json['lastPositionSeconds']),
      durationSeconds: _toIntOrNull(json['durationSeconds']),
      watchedPercent: _toIntOrNull(json['watchedPercent']),
      videoUrl: json['videoUrl']?.toString(),
      locked: json['locked'] == true,
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.tryParse(json['updatedAt'].toString()),
    );
  }

  /// "Resume at 2:30".
  String get resumeLabel {
    final minutes = lastPositionSeconds ~/ 60;
    final seconds = (lastPositionSeconds % 60).toString().padLeft(2, '0');
    if (minutes < 60) return '$minutes:$seconds';
    return '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}:$seconds';
  }
}

class HomeSummary {
  final DailyQuizSummary? dailyQuiz;

  /// Unfinished videos with a resume point, most recently watched first,
  /// capped at ten by the server. A finished video leaves the list.
  final List<InProgressVideo> inProgressVideos;

  const HomeSummary({this.dailyQuiz, required this.inProgressVideos});

  factory HomeSummary.fromJson(Map<String, dynamic> json) {
    final modules = json['modules'];
    final daily = modules is Map ? modules['dailyQuiz'] : null;

    return HomeSummary(
      dailyQuiz: daily is Map
          ? DailyQuizSummary.fromJson(Map<String, dynamic>.from(daily))
          : null,
      // `continueWatching` is deliberately ignored: it is the first element
      // of this same list, kept for older single-card home screens. Rendering
      // both would show that video twice.
      inProgressVideos: [
        for (final v in (json['inProgressVideos'] as List?) ?? const [])
          if (v is Map) InProgressVideo.fromJson(Map<String, dynamic>.from(v)),
      ],
    );
  }
}
