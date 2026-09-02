// lib/widget/lesson_watch_indicator.dart
//
// Watched / part-watched / not started, for a lesson row in the outline.
//
// Four states, and the order they are tested in is the whole design:
//
//   completed              -> filled tick, "Watched"
//   watchedPercent > 0     -> thin bar, "Resume at m:ss"
//   watchedPercent == 0    -> empty circle, "Not started"
//   watchedPercent == null -> empty circle, no bar
//
// `completed` is tested first because it can be true while the percentage is
// low: finish a video, rewind, and the server keeps the tick while the share
// drops. The tick wins — it is never derived from the percentage.
//
// `null` is not `0`. Null means the video's length is unknown, so no share
// can be computed; a bar pinned at zero would read as "never watched" for a
// lesson the student is halfway through. Notes and quizzes are always null.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/selection_content_model.dart';

const Color _kPrimary = Color(0xFF87986B);
const Color _kAmber = Color(0xFFE8A33D);

/// m:ss, or h:mm:ss past an hour.
String formatWatchClock(int seconds) {
  final minutes = seconds ~/ 60;
  final remainder = (seconds % 60).toString().padLeft(2, '0');
  if (minutes < 60) return '$minutes:$remainder';
  return '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}:$remainder';
}

/// The status line under a lesson title.
class LessonWatchIndicator extends StatelessWidget {
  final StudentLessonModel lesson;

  /// Hides "Not started", for lists where a row of grey text adds nothing.
  final bool showNotStarted;

  const LessonWatchIndicator({
    super.key,
    required this.lesson,
    this.showNotStarted = false,
  });

  @override
  Widget build(BuildContext context) {
    // The server decides this, for a video off the player and for a quiz off
    // its attempt. Never re-derived here from type or percentage.
    if (lesson.completed) {
      return _Line(
        icon: Icons.check_circle_rounded,
        color: _kPrimary,
        label: 'Watched',
      );
    }

    final percent = lesson.watchedPercent;

    // Started, and the server knows enough to say how far.
    if (percent != null && percent > 0) {
      return Padding(
        padding: EdgeInsets.only(bottom: 6.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4.r),
              child: LinearProgressIndicator(
                value: (percent / 100).clamp(0.0, 1.0),
                minHeight: 3.h,
                backgroundColor: const Color(0xFFE6E6E6),
                valueColor: const AlwaysStoppedAnimation<Color>(_kAmber),
              ),
            ),
            SizedBox(height: 5.h),
            _Line(
              icon: Icons.history_rounded,
              color: _kAmber,
              // The position is kept even on a locked lesson — the lock
              // strips videoUrl, not the place the student got to.
              label: 'Resume at ${formatWatchClock(lesson.lastPositionSeconds)}',
              padded: false,
            ),
          ],
        ),
      );
    }

    // Either 0% (known, untouched) or null (length unknown). Neither gets a
    // bar: at 0 there is nothing to draw, and at null there is nothing to
    // draw it from. A position without a percentage still says where to
    // resume — that is the honest half of the answer.
    if (percent == null && lesson.lastPositionSeconds > 0) {
      return _Line(
        icon: Icons.history_rounded,
        color: _kAmber,
        label: 'Resume at ${formatWatchClock(lesson.lastPositionSeconds)}',
      );
    }

    if (!showNotStarted) return const SizedBox.shrink();

    return _Line(
      icon: Icons.circle_outlined,
      color: Colors.grey.shade500,
      label: 'Not started',
    );
  }
}

class _Line extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final bool padded;

  const _Line({
    required this.icon,
    required this.color,
    required this.label,
    this.padded = true,
  });

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12.sp, color: color),
        SizedBox(width: 4.w),
        Text(label,
            style: TextStyle(
                fontSize: 10.sp, fontWeight: FontWeight.w600, color: color)),
      ],
    );

    return padded ? Padding(padding: EdgeInsets.only(bottom: 6.h), child: row) : row;
  }
}
