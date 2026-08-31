// lib/view/Home/Qbank/qbank_subjects_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../models/selection_content_model.dart';
import '../../../repository/selection_content_provider.dart';
import '../../../widget/app_shimmer.dart';
import 'quiz_screen.dart';
import '../../../core/utils/refresh_on_visible.dart';

const Color _kPrimary = Color(0xFF87986B);
const Color _kBg = Color(0xFFEFF4E2);

/// Subjects inside one topic. Only quiz lessons are listed — this is the
/// MCQ section, so anything without a quiz has no place here.
///
/// Each row's state comes from `lesson.attempt`, which the content tree
/// already carries. This screen used to fire one history call per quiz to
/// work that out; the tree made that N+1 unnecessary.
class QbankSubjectsScreen extends StatefulWidget {
  final StudentChapterModel chapter;

  const QbankSubjectsScreen({super.key, required this.chapter});

  @override
  State<QbankSubjectsScreen> createState() => _QbankSubjectsScreenState();
}

class _QbankSubjectsScreenState extends State<QbankSubjectsScreen>
    with RefreshOnVisible<QbankSubjectsScreen> {
  /// Refetches the tree every time this screen is entered.
  ///
  /// Scores and attempt state change while the student is off in a quiz — or
  /// on another device — and `lesson.attempt` from the tree is the only thing
  /// these rows render from. Silent: the shimmer shows only on a cold load, so
  /// this swaps the data underneath instead of flashing the list away.
  @override
  Future<void> onRefresh() =>
      context.read<SelectionContentProvider>().loadContent();

  /// The chapter as the provider currently holds it. `widget.chapter` was
  /// captured when this route was pushed, so after a quiz is finished and the
  /// tree reloads, that copy still carries the old `attempt` objects.
  StudentChapterModel _liveChapter(BuildContext context) {
    final chapters = context.watch<SelectionContentProvider>().content?.chapters;
    if (chapters == null) return widget.chapter;

    for (final candidate in chapters) {
      if (candidate.id == widget.chapter.id) return candidate;
    }
    return widget.chapter;
  }

  Future<void> _openQuiz(BuildContext context, StudentLessonModel lesson) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizScreen(lessonId: lesson.id, lessonTitle: lesson.title),
      ),
    );

    // Nothing to do here: the route observer refetches when this screen
    // comes back into view.
  }

  @override
  Widget build(BuildContext context) {
    final content = context.watch<SelectionContentProvider>();
    final live = _liveChapter(context);
    final subjects = live.lessons.where((l) => l.isQuiz).toList();

    // Only while there is genuinely nothing to show. A refresh over rows that
    // are already on screen stays silent — flashing them away on every entry
    // would be worse than a moment of stale numbers.
    final showShimmer = content.isLoading;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        foregroundColor: Colors.black,
        titleSpacing: 0,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: Icon(Icons.chevron_left_rounded, size: 30.sp, color: Colors.black),
        ),
        title: Text(
          live.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w700, color: Colors.black),
        ),
      ),
      body: showShimmer
          ? const ScreenShimmer(layout: ShimmerLayout.rows)
          : subjects.isEmpty
          ? Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 32.w),
                child: Text(
                  "No MCQ subjects in this topic yet.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade600),
                ),
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 24.h),
              itemCount: subjects.length,
              separatorBuilder: (_, __) => SizedBox(height: 12.h),
              itemBuilder: (context, index) {
                final lesson = subjects[index];
                return QbankRowTile(
                  icon: Icons.help_outline_rounded,
                  title: lesson.title,
                  subtitle: lesson.quizQuestionCount == null
                      ? "MCQs"
                      : "${lesson.quizQuestionCount} MCQs",
                  locked: lesson.locked,
                  attempt: lesson.attempt,
                  onTap: () => _openQuiz(context, lesson),
                );
              },
            ),
    );
  }
}

/// Shared row used by both the topics list and the subjects list.
class QbankRowTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool locked;

  /// This student's latest attempt, straight off the content tree. Null on a
  /// quiz never started and on every non-quiz row, so it stays nullable.
  final LessonAttemptInfo? attempt;

  final VoidCallback onTap;

  const QbankRowTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.locked = false,
    this.attempt,
  });

  @override
  Widget build(BuildContext context) {
    final latest = attempt;
    final resuming = latest != null && latest.isInProgress;
    final completed = latest != null && latest.completed;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: resuming ? Border.all(color: _kPrimary, width: 1.2) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 44.w,
              height: 44.w,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: _kBg, shape: BoxShape.circle),
              child: Icon(icon, size: 20.sp, color: _kPrimary),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: Colors.black87),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    resuming
                        ? "${latest.remainingCount} left of ${latest.answeredCount + latest.remainingCount}"
                        : completed
                            ? "Best ${_trimMarks(latest.score)} · "
                                "${latest.attemptCount} attempt${latest.attemptCount == 1 ? '' : 's'}"
                            : subtitle,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: latest == null ? FontWeight.w400 : FontWeight.w600,
                      color: latest == null ? Colors.grey.shade600 : _kPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if (locked) ...[
              Icon(Icons.lock_outline_rounded, size: 16.sp, color: Colors.grey.shade500),
              SizedBox(width: 6.w),
            ],
            // Three states, one row: never started, half-done, already scored.
            // A finished quiz reopens read-only, so this says Review: there
            // is no second attempt to offer.
            if (resuming)
              _Pill(label: "Continue", filled: true)
            else if (completed)
              _Pill(label: "Review", filled: false)
            else
              Icon(Icons.chevron_right_rounded, size: 24.sp, color: Colors.grey.shade500),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool filled;

  const _Pill({required this.label, required this.filled});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: filled ? _kPrimary : Colors.transparent,
        borderRadius: BorderRadius.circular(20.r),
        border: filled ? null : Border.all(color: _kPrimary, width: 1.2),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5.sp,
          fontWeight: FontWeight.w700,
          color: filled ? Colors.white : _kPrimary,
        ),
      ),
    );
  }
}

/// 2.0 -> "2", -0.5 -> "-0.5". Never touches the sign.
String _trimMarks(double value) {
  final text = value.toStringAsFixed(2);
  return text.replaceFirst(RegExp(r'\.?0+$'), '');
}
