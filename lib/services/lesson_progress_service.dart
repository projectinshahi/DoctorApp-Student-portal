// lib/services/lesson_progress_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/constant/api_constant.dart';
import 'refresh_api_services.dart'; // ApiClient + SessionExpiredException

/// Writes watch position back to the server: `PUT /users/me/lessons/:id/progress`.
///
/// The request is partial in both directions — send only what changed, and
/// expect only what changed back — so marking a lesson complete does not have
/// to restate the position, and saving a position does not reset `completed`.
///
/// Every failure here is swallowed. A dropped progress write costs the student
/// a few seconds of replay; an error banner over their video costs them the
/// lesson. The next tick retries anyway.
class LessonProgressService {
  static String _url(int lessonId) =>
      '${ApiConstant.baseUrl}/users/me/lessons/$lessonId/progress';

  /// Reports where the player is and returns what the server made of it.
  ///
  /// The return value is the point: `completed` is the server's verdict
  /// against its own threshold, and it arrives on this very call — which is
  /// what lets the tick appear while the video is still playing, with no
  /// refetch. Null means the write failed and nothing should change.
  Future<LessonProgress?> save(
    int lessonId, {
    int? positionSeconds,
    int? durationSeconds,
    bool? completed,
  }) async {
    if (positionSeconds == null && completed == null) return null;

    try {
      final response = await ApiClient.put(_url(lessonId), body: {
        if (positionSeconds != null) 'lastPositionSeconds': positionSeconds,
        // Sent so the server can judge a percentage at all. Old uploads have
        // no stored length, and 300s into a 310s clip is finished where 300s
        // into an hour is not. Ignored once stored, so repeating it is free.
        if (durationSeconds != null && durationSeconds > 0)
          'durationSeconds': durationSeconds,
        if (completed != null) 'completed': completed,
      });

      if (response.statusCode != 200 || response.body.isEmpty) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      return LessonProgress.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      // Deliberately silent — see the class comment.
      return null;
    }
  }
}

/// The server's answer to a progress write.
class LessonProgress {
  final int lessonId;

  /// **The server's verdict, never the app's.** It owns the threshold, and it
  /// only ever turns on: a rewind after finishing leaves this true.
  final bool completed;

  final int lastPositionSeconds;

  /// Null until the server knows the video's length. Not zero — see
  /// [StudentLessonModel.watchedPercent].
  final int? watchedPercent;
  final int? durationSeconds;

  const LessonProgress({
    required this.lessonId,
    required this.completed,
    required this.lastPositionSeconds,
    this.watchedPercent,
    this.durationSeconds,
  });

  factory LessonProgress.fromJson(Map<String, dynamic> json) {
    int? asIntOrNull(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.round();
      return int.tryParse(value.toString());
    }

    return LessonProgress(
      lessonId: asIntOrNull(json['lessonId']) ?? 0,
      completed: json['completed'] == true,
      lastPositionSeconds: asIntOrNull(json['lastPositionSeconds']) ?? 0,
      watchedPercent: asIntOrNull(json['watchedPercent']),
      durationSeconds: asIntOrNull(json['durationSeconds']),
    );
  }
}

/// Throttles position writes for one open lesson.
///
/// The player ticks several times a second. Writing on every tick is a
/// database row per tick, so [record] only remembers the latest position and a
/// timer flushes it at most once per [interval]. [flush] forces one out on
/// pause and on dispose, which are the two moments the student is most likely
/// to leave and expect their place kept.
class LessonProgressWriter {
  final int lessonId;
  final Duration interval;
  final LessonProgressService _service;

  Timer? _ticker;
  int? _pending;
  int? _lastSent;
  bool _closed = false;

  /// The video's length, learned from the player once it initialises.
  int? _duration;

  /// Called with the server's answer to every successful write. The screen
  /// uses it to patch the outline, so the tick lands mid-playback.
  final void Function(LessonProgress)? onProgress;

  LessonProgressWriter({
    required this.lessonId,
    this.interval = const Duration(seconds: 10),
    LessonProgressService? service,
    this.onProgress,
  }) : _service = service ?? LessonProgressService();

  /// Set once the player reports a duration. Sent with every write after
  /// that: harmless when the server already has it, and it backfills a
  /// catalogue uploaded before lengths were stored.
  set durationSeconds(int? seconds) {
    if (seconds != null && seconds > 0) _duration = seconds;
  }

  /// Called from the player's listener on every frame. Cheap on purpose.
  void record(int positionSeconds) {
    if (_closed || positionSeconds < 0) return;
    _pending = positionSeconds;
    _ticker ??= Timer.periodic(interval, (_) => flush());
  }

  /// Writes the pending position now, if it differs from the last one sent.
  ///
  /// The equality check is what stops a paused video from posting the same
  /// second over and over for as long as it sits there.
  Future<void> flush({bool? completed}) async {
    final position = _pending;
    if (_closed && completed == null) return;
    if (position == null && completed == null) return;
    if (position == _lastSent && completed == null) return;

    _lastSent = position;
    final progress = await _service.save(
      lessonId,
      positionSeconds: position,
      durationSeconds: _duration,
      completed: completed,
    );

    if (progress != null) onProgress?.call(progress);
  }

  /// Last write on the way out. Awaiting this in `dispose()` is not possible,
  /// so it is fired and forgotten — the request outlives the widget.
  void close({bool? completed}) {
    _ticker?.cancel();
    _ticker = null;
    unawaited(flush(completed: completed));
    _closed = true;
  }

  @visibleForTesting
  int? get pendingPosition => _pending;

  @visibleForTesting
  int? get lastSentPosition => _lastSent;
}
