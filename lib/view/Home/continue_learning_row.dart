// lib/view/Home/continue_learning_row.dart
//
// Continue Learning — the video you left, and the one after it.
//
// Two cards, no more. A home screen is a place to resume from, not a
// catalogue: the full course lives one tap away in QBank and AI Videos, and
// a scrolling wall of lessons here just buries the one the student actually
// wants.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../models/home_summary_model.dart';
import '../../models/selection_content_model.dart';

const Color _kPrimary = Color(0xFF87986B);

/// One card's worth of lesson, from either source.
///
/// The resumed video comes from `/home` (which carries its `videoUrl`, so it
/// plays without a second call); the next one comes from the course outline.
/// Wrapping both keeps the card from caring which.
class LearningItem {
  final StudentLessonModel lesson;

  /// "Resume at 1:35", or null on a lesson not started.
  final String? resumeAt;

  const LearningItem({required this.lesson, this.resumeAt});

  bool get isResume => resumeAt != null;
}

class ContinueLearningRow extends StatelessWidget {
  final List<LearningItem> items;
  final void Function(StudentLessonModel) onOpen;

  const ContinueLearningRow({
    super.key,
    required this.items,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    // Nothing to resume and nothing queued — hide the section rather than
    // show an empty frame.
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Continue Learning',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 12.h),
        Row(
          // Not `stretch`. This Row lives in a scroll view, so its height is
          // unbounded, and stretch would hand the cards an infinite height
          // to fill. They set their own 150.h, which is what makes the pair
          // match anyway.
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) SizedBox(width: 12.w),
              Expanded(
                child: _LearningCard(
                  item: items[i],
                  onTap: () => onOpen(items[i].lesson),
                ),
              ),
            ],
            // A single card must not stretch to the full width, or it stops
            // matching the pair it usually sits in.
            if (items.length == 1) ...[
              SizedBox(width: 12.w),
              const Expanded(child: SizedBox()),
            ],
          ],
        ),
      ],
    );
  }
}

class _LearningCard extends StatelessWidget {
  final LearningItem item;
  final VoidCallback onTap;

  const _LearningCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final lesson = item.lesson;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 150.h,
        decoration: BoxDecoration(
          // Stays behind the poster: it is what shows while the image loads,
          // if it fails, and on a lesson that has no thumbnail at all.
          color: _kPrimary,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16.r),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (lesson.thumbnailUrl != null)
                Image.network(
                  lesson.thumbnailUrl!,
                  fit: BoxFit.cover,
                  // A dead thumbnail must not take the card down with it —
                  // the green underneath is a perfectly good card.
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              // Every poster is a different brightness, and the title and
              // Resume pill are white on all of them. The scrim is what makes
              // that safe rather than lucky.
              if (lesson.thumbnailUrl != null)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.25),
                        Colors.black.withValues(alpha: 0.72),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.all(14.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34.w,
                          height: 34.w,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            // Locked opens the paywall, not the player — and the
                            // card says so before the tap.
                            lesson.locked
                                ? Icons.lock_rounded
                                : lesson.isVideo
                                ? Icons.play_arrow_rounded
                                : Icons.description_outlined,
                            size: 17.sp,
                            color: _kPrimary,
                          ),
                        ),
                        const Spacer(),
                        if (item.isResume)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 3.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: Text(
                              'Resume',
                              style: TextStyle(
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      lesson.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.3,
                      ),
                    ),
                    if (item.resumeAt != null) ...[
                      SizedBox(height: 5.h),
                      Text(
                        'at ${item.resumeAt}',
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Picks the two cards: what they left, then what comes next.
///
/// [inProgress] is `/home`'s list, most recently watched first — its head is
/// the lesson to resume. The follow-up is the first unfinished lesson in
/// course order that is not already that one, so the pair never shows the
/// same lesson twice.
List<LearningItem> pickLearningItems({
  required List<InProgressVideo> inProgress,
  required SelectionContentModel? content,
}) {
  final items = <LearningItem>[];
  final taken = <int>{};

  if (inProgress.isNotEmpty) {
    final video = inProgress.first;
    taken.add(video.lessonId);
    items.add(
      LearningItem(
        // Built from /home, so it already carries videoUrl and the position.
        lesson: lessonFromHomeVideo(video),
        resumeAt: video.resumeLabel,
      ),
    );
  }

  for (final chapter in content?.chapters ?? const <StudentChapterModel>[]) {
    if (items.length >= 2) break;
    for (final lesson in chapter.lessons) {
      if (items.length >= 2) break;
      if (!lesson.isWatchable) continue;
      // A finished lesson is not "next", and neither is the one already on
      // the left-hand card.
      if (lesson.completed || taken.contains(lesson.id)) continue;

      taken.add(lesson.id);
      items.add(
        LearningItem(
          lesson: lesson,
          resumeAt: lesson.lastPositionSeconds > 0
              ? _clock(lesson.lastPositionSeconds)
              : null,
        ),
      );
    }
  }

  return items;
}

String _clock(int seconds) {
  final minutes = seconds ~/ 60;
  final rest = (seconds % 60).toString().padLeft(2, '0');
  if (minutes < 60) return '$minutes:$rest';
  return '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}:$rest';
}

/// A `/home` video as the lesson the player expects.
///
/// `videoUrl` is null when locked, which is what routes the screen to the
/// paywall instead of letting it build a controller on null.
StudentLessonModel lessonFromHomeVideo(InProgressVideo video) =>
    StudentLessonModel(
      id: video.lessonId,
      title: video.title,
      type: 'video',
      videoUrl: video.videoUrl,
      thumbnailUrl: video.thumbnailUrl,
      displayOrder: 0,
      isFreePreview: !video.locked,
      accessType: video.locked ? 'premium' : 'free',
      locked: video.locked,
      lastPositionSeconds: video.lastPositionSeconds,
      watchedPercent: video.watchedPercent,
      durationSeconds: video.durationSeconds,
    );
