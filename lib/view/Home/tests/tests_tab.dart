// lib/view/Home/tests/tests_tab.dart
//
// The published tests for the student's selected course.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/refresh_on_visible.dart';
import '../../../models/quiz_model.dart' show QuizException;
import '../../../models/test_model.dart';
import '../../../repository/selection_content_provider.dart';
import '../../../services/test_service.dart';
import '../../../widget/app_shimmer.dart';
import 'test_attempt_screen.dart';
import 'test_result_screen.dart';

const Color _kPrimary = Color(0xFF87986B);
const Color _kBg = Color(0xFFEFF4E2);

class TestsTab extends StatefulWidget {
  const TestsTab({super.key});

  @override
  State<TestsTab> createState() => _TestsTabState();
}

class _TestsTabState extends State<TestsTab> with RefreshOnVisible<TestsTab> {
  final TestService _service = TestService();

  List<TestSummary> _tests = const [];
  bool _loading = true;
  String? _error;

  /// The course this list was fetched for, so build() can spot it arriving.
  int? _loadedCourseId;

  /// Refetched on entry and on return, so a paper just submitted shows
  /// "View result" instead of still offering "Resume".
  @override
  Future<void> onRefresh() async {
    final content = context.read<SelectionContentProvider>();
    final courseId = content.content?.course?.id;

    if (!mounted) return;
    if (courseId == null) {
      setState(() {
        // On a cold start this tab can open before the course has arrived.
        // Staying on the shimmer is the honest state — telling the student to
        // "select a course" is telling them to redo something they have
        // already done. build() refetches the moment it lands.
        _loading = content.isLoading;
        _error = _loading ? null : 'Select a course to see its tests.';
      });
      return;
    }

    _loadedCourseId = courseId;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final tests = await _service.fetchTests(courseId);
      if (!mounted) return;
      setState(() {
        _tests = tests;
        _loading = false;
      });
    } on QuizException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  Future<void> _openResult(TestSummary test) async {
    final attempt = test.lastAttempt;
    if (attempt == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TestResultScreen(
          attemptId: attempt.attemptId,
          testId: test.id,
          testName: test.name,
        ),
      ),
    );
  }

  /// Start, resume, or retake — all one call. The server decides which:
  /// POST /attempts resumes an unfinished paper and opens a fresh one
  /// otherwise, so retakes need no separate endpoint.
  Future<void> _openPaper(TestSummary test) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TestAttemptScreen(test: test)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watched, not read: the course resolves asynchronously, and this fetches
    // itself as soon as it does.
    final courseId = context.watch<SelectionContentProvider>().content?.course?.id;
    if (courseId != null && courseId != _loadedCourseId) {
      _loadedCourseId = courseId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) onRefresh();
      });
    }

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: Icon(Icons.chevron_left_rounded, size: 30.sp, color: Colors.black),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Tests',
                style: TextStyle(
                    fontSize: 19.sp, fontWeight: FontWeight.w800, color: Colors.black)),
            Text('Grand tests for your course',
                style: TextStyle(fontSize: 11.5.sp, color: Colors.grey.shade600)),
          ],
        ),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const ScreenShimmer(layout: ShimmerLayout.rows);

    if (_error != null) {
      return _message(_error!, onRetry: onRefresh);
    }
    if (_tests.isEmpty) {
      return _message('No tests published for this course yet.');
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
      itemCount: _tests.length,
      separatorBuilder: (_, __) => SizedBox(height: 12.h),
      itemBuilder: (context, index) => _TestCard(
        test: _tests[index],
        onOpenResult: () => _openResult(_tests[index]),
        onOpenPaper: () => _openPaper(_tests[index]),
      ),
    );
  }

  Widget _message(String text, {Future<void> Function()? onRetry}) => Center(
        child: Padding(
          padding: EdgeInsets.all(32.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade700)),
              if (onRetry != null) ...[
                SizedBox(height: 14.h),
                OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
              ],
            ],
          ),
        ),
      );
}

class _TestCard extends StatelessWidget {
  final TestSummary test;
  final VoidCallback onOpenResult;
  final VoidCallback onOpenPaper;

  const _TestCard({
    required this.test,
    required this.onOpenResult,
    required this.onOpenPaper,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Tapping the card body does the obvious thing: read the marked paper
      // if there is one, otherwise open it.
      onTap: test.isSubmitted ? onOpenResult : onOpenPaper,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    test.name,
                    style: TextStyle(
                        fontSize: 15.sp, fontWeight: FontWeight.w700, color: Colors.black87),
                  ),
                ),
                if (test.attemptCount > 0) ...[
                  SizedBox(width: 8.w),
                  Text(
                    // Retakes are unlimited, so this is a count, not "of N".
                    'Attempt ${test.attemptCount}',
                    style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
            SizedBox(height: 10.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 6.h,
              children: [
                _Tag(icon: Icons.help_outline_rounded, label: '${test.totalQuestions} questions'),
                _Tag(icon: Icons.timer_outlined, label: '${test.durationMinutes} min'),
                // Shown before they start on purpose: negative marking changes
                // how a student plays the paper.
                if (test.hasNegativeMarking)
                  _Tag(
                    icon: Icons.remove_circle_outline_rounded,
                    label: '${test.marksIncorrect} per wrong answer',
                    danger: true,
                  ),
              ],
            ),
            if (test.isSubmitted && test.lastAttempt?.score != null) ...[
              SizedBox(height: 10.h),
              Text(
                'Last score ${test.lastAttempt!.score}',
                style: TextStyle(
                    fontSize: 12.sp, fontWeight: FontWeight.w600, color: _kPrimary),
              ),
            ],
            SizedBox(height: 14.h),
            SizedBox(
              height: 42.h,
              // A submitted test keeps both doors open: the marked paper, and
              // another go at it. Offering only "View result" would strand the
              // student on their first score, and retakes are unlimited.
              child: test.isSubmitted
                  ? Row(
                      children: [
                        Expanded(
                          child: _Action(
                            label: 'View result',
                            onTap: onOpenResult,
                            filled: false,
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: _Action(label: 'Retake', onTap: onOpenPaper),
                        ),
                      ],
                    )
                  : _Action(
                      label: test.isInProgress ? 'Resume' : 'Start',
                      onTap: onOpenPaper,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool filled;

  const _Action({required this.label, required this.onTap, this.filled = true});

  @override
  Widget build(BuildContext context) {
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r));

    return filled
        ? ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.zero,
              shape: shape,
            ),
            child: Text(label,
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700)),
          )
        : OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: _kPrimary,
              side: const BorderSide(color: _kPrimary),
              padding: EdgeInsets.zero,
              shape: shape,
            ),
            child: Text(label,
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600)),
          );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool danger;

  const _Tag({required this.icon, required this.label, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final color = danger ? Colors.red.shade700 : Colors.grey.shade700;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: danger ? Colors.red.shade50 : const Color(0xFFF3F5EC),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13.sp, color: color),
          SizedBox(width: 5.w),
          Text(label,
              style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
