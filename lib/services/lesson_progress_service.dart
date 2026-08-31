// lib/services/lesson_progress_service.dart
import 'dart:async';

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

  Future<void> save(
    int lessonId, {
    int? positionSeconds,
    bool? completed,
  }) async {
    if (positionSeconds == null && completed == null) return;

    try {
      await ApiClient.put(_url(lessonId), body: {
        if (positionSeconds != null) 'lastPositionSeconds': positionSeconds,
        if (completed != null) 'completed': completed,
      });
    } catch (_) {
      // Deliberately silent — see the class comment.
    }
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

  LessonProgressWriter({
    required this.lessonId,
    this.interval = const Duration(seconds: 10),
    LessonProgressService? service,
  }) : _service = service ?? LessonProgressService();

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
    await _service.save(
      lessonId,
      positionSeconds: position,
      completed: completed,
    );
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
