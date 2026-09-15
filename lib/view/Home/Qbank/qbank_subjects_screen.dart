import 'dart:async';
// lib/view/Home/Qbank/qbank_subjects_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../models/selection_content_model.dart';
import '../../../repository/quiz_prefetch.dart';
import '../../../repository/selection_content_provider.dart';
import '../../../widget/app_loading.dart';
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
  /// these rows render from. Silent: the spinner shows only on a cold load, so
  /// this swaps the data underneath instead of flashing the list away.
  @override
  Future<void> onRefresh() async {
    await context.read<SelectionContentProvider>().loadContent();
    if (!mounted) return;
    // Warm this chapter's quizzes while the student reads the list they are
    // about to tap. Read-only: only quizzes that already have an attempt are
    // fetched, so nothing is started that the student did not start.
    unawaited(
      context.read<QuizPrefetch>().warm(
        // read, not watch: this runs from an async callback, and watching
        // outside a build is what threw "Tried to listen to a value exposed
        // with provider, from outside of the widget tree".
        _chapterIn(context.read<SelectionContentProvider>()).lessons,
      ),
    );
  }

  /// The chapter as the provider currently holds it. `widget.chapter` was
  /// captured when this route was pushed, so after a quiz is finished and the
  /// tree reloads, that copy still carries the old `attempt` objects.
  ///
  /// Takes the provider rather than a context, so the caller decides between
  /// watch (in build) and read (in a callback) — the wrong one throws.
  StudentChapterModel _chapterIn(SelectionContentProvider provider) {
    final chapters = provider.content?.chapters;
    if (chapters == null) return widget.chapter;

    for (final candidate in chapters) {
      if (candidate.id == widget.chapter.id) return candidate;
    }
    return widget.chapter;
  }

  /// [retake] opens straight into a new attempt — the row's Retest.
  Future<void> _openQuiz(
    BuildContext context,
    StudentLessonModel lesson, {
    bool retake = false,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          lessonId: lesson.id,
          lessonTitle: lesson.title,
          // Straight off the tree this screen already renders from, so the
          // quiz opens on one call rather than two.
          knownAttempt: lesson.attempt,
          attemptStateKnown: true,
          retake: retake,
        ),
      ),
    );

    // Nothing to do here: the route observer refetches when this screen
    // comes back into view.
  }

  @override
  Widget build(BuildContext context) {
    final content = context.watch<SelectionContentProvider>();
    final live = _chapterIn(context.watch<SelectionContentProvider>());
    final subjects = live.lessons.where((l) => l.isQuiz).toList();

    // This screen is pushed with its chapter already in hand, so there is
    // almost never nothing to show: `subjects` comes from widget.chapter even
    // before the refresh lands. Binding the loader to the shared tree's
    // isLoading blanked a screen that was holding its own data — which is the
    // spinner on an empty page the client reported.
    final showLoading = content.isLoading && subjects.isEmpty;

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
      body: showLoading
          ? const AppLoading()
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
                  onRetake: () => _openQuiz(context, lesson, retake: true),
                );
              },
            ),
    );
  }
}

/// Shared row used by the topic and subject lists, and by Rapid Recall.
class QbankRowTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool locked;

  /// This student's latest attempt, straight off the content tree. Null on a
  /// quiz never started and on every non-quiz row, so it stays nullable.
  final LessonAttemptInfo? attempt;

  /// Opens the row: the quiz, or a finished quiz's review.
  final VoidCallback onTap;

  /// Starts a new attempt on a finished quiz. Given, a finished row offers
  /// Review and Retest side by side; not given, it keeps a single Review
  /// pill — the topic and Recall lists have nothing to retest.
  final VoidCallback? onRetake;

  const QbankRowTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.locked = false,
    this.attempt,
    this.onRetake,
  });

  @override
  Widget build(BuildContext context) {
    final latest = attempt;
    final resuming = latest != null && latest.isInProgress;
    final completed = latest != null && latest.completed;

    // Two choices get a line of their own. Squeezed in beside the title they
    // left a long quiz name a few characters wide.
    final twoActions = completed && onRetake != null;

    final header = Row(
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
                maxLines: twoActions ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: Colors.black87),
              ),
              SizedBox(height: 3.h),
              Text(
                resuming
                    ? "${latest.remainingCount} left of ${latest.answeredCount + latest.remainingCount}"
                    : completed
                        // The tree reports the latest attempt, not the best —
                        // with retests the two differ.
                        ? "Last score ${_trimMarks(latest.score)} · "
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
          SizedBox(width: 6.w),
          Icon(Icons.lock_outline_rounded, size: 16.sp, color: Colors.grey.shade500),
        ],
        if (!twoActions) ...[
          SizedBox(width: 6.w),
          // Three states, one row: never started, half-done, already scored.
          if (resuming)
            _Pill(label: "Continue", filled: true)
          else if (completed)
            _Pill(label: "Review", filled: false)
          else
            Icon(Icons.chevron_right_rounded, size: 24.sp, color: Colors.grey.shade500),
        ],
      ],
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, twoActions ? 16.h : 14.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: resuming ? Border.all(color: _kPrimary, width: 1.2) : null,
        ),
        child: twoActions
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  header,
                  SizedBox(height: 14.h),
                  Row(
                    children: [
                      // Review first, Retest second: the forward action sits
                      // where the thumb ends up, as Continue does on an
                      // unfinished row.
                      Expanded(
                        child: _RowAction(
                          label: "Review",
                          icon: Icons.fact_check_outlined,
                          filled: false,
                          onTap: onTap,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: _RowAction(
                          label: "Retest",
                          icon: Icons.replay_rounded,
                          filled: true,
                          onTap: onRetake!,
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : header,
      ),
    );
  }
}

/// One of the two buttons under a finished quiz.
class _RowAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  const _RowAction({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tint = filled ? Colors.white : _kPrimary;

    return GestureDetector(
      onTap: onTap,
      // Opaque, so a tap on the button's padding is the button's — not the
      // card's, which would open the review behind a Retest.
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 40.h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? _kPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(22.r),
          border: filled ? null : Border.all(color: _kPrimary, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16.sp, color: tint),
            SizedBox(width: 6.w),
            Text(
              label,
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: tint),
            ),
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
