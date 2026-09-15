// lib/view/Home/tests/tests_tab.dart
//
// The published tests for the student's selected course.
//
// Split into two tabs, because a student arrives with one of two intentions:
// sit something new, or read back something already marked. Mixed into one
// list those compete — a fresh paper is invisible among a column of finished
// ones — and each needs a different card to answer its own question.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/refresh_on_visible.dart';
import '../../../models/quiz_model.dart' show QuizException;
import '../../../models/test_model.dart';
import '../../../repository/selection_content_provider.dart';
import '../../../services/test_service.dart';
import '../../../widget/loading_wave.dart';
import 'test_attempt_screen.dart';
import 'test_instructions_screen.dart';
import 'test_result_screen.dart';

const Color _kPrimary = Color(0xFF87986B);
const Color _kPrimaryDark = Color(0xFF6B7C51);
const Color _kBg = Color(0xFFEFF4E2);
const Color _kAmber = Color(0xFFE8A33D);
const Color _kRed = Color(0xFFD65745);
const Color _kInk = Color(0xFF1F2418);

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// The soft lift every card sits on. One definition so a card added later
/// cannot drift a shade off the rest.
final List<BoxShadow> _kCardShadow = [
  BoxShadow(
    color: Colors.black.withValues(alpha: 0.05),
    blurRadius: 14,
    offset: const Offset(0, 4),
  ),
];

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

  /// The fetch currently in flight, if any.
  Future<void>? _inFlight;

  /// Refetched on entry and on return, so a paper just submitted moves from
  /// one tab to the other without a manual pull.
  ///
  /// Three things call this — the route observer when the tab becomes
  /// visible, again on resume, and build() the moment the course id arrives.
  /// Two of those land together on a first open, which showed on device as
  /// the same 1231-byte response fetched twice, 1263ms and 1265ms. A second
  /// caller now joins the first rather than starting another.
  @override
  Future<void> onRefresh() =>
      _inFlight ??= _refresh().whenComplete(() => _inFlight = null);

  Future<void> _refresh() async {
    final content = context.read<SelectionContentProvider>();
    final courseId = content.content?.course?.id;

    if (!mounted) return;
    if (courseId == null) {
      setState(() {
        // On a cold start this tab can open before the course has arrived.
        // Staying on the spinner is the honest state — telling the student to
        // "select a course" is telling them to redo something they have
        // already done. build() refetches the moment it lands.
        _loading = content.isLoading;
        _error = _loading ? null : 'Select a course to see its tests.';
      });
      return;
    }

    // Only when there is nothing to show, or when the course changed and the
    // list on screen belongs to the wrong one. Returning from a submitted
    // paper refetches under the list rather than blanking it.
    final cold = _tests.isEmpty || _loadedCourseId != courseId;
    _loadedCourseId = courseId;

    setState(() {
      _loading = cold;
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

  Future<void> _open(TestSummary test) async {
    // One attempt each: a finished paper opens its result and nothing else.
    if (test.isSubmitted) {
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
      return;
    }

    // A new paper reads the rules first; a running one does not. The clock has
    // been going for a while by then, and rules would cost time the student
    // cannot get back.
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => test.isInProgress
            ? TestAttemptScreen(test: test)
            : TestInstructionsScreen(test: test),
      ),
    );
  }

  /// Still to sit — never opened, or opened and still running. Both have work
  /// left in them, which is what puts them on the same tab.
  ///
  /// A paper whose clock has run out does not, so it moves across even though
  /// the server may not have recorded the auto-submit yet.
  List<TestSummary> get _pending =>
      _tests.where((t) => !t.isFinished).toList();

  List<TestSummary> get _attempted =>
      _tests.where((t) => t.isFinished).toList();

  @override
  Widget build(BuildContext context) {
    // Watched, not read: the course resolves asynchronously, and this fetches
    // itself as soon as it does.
    final courseId =
        context.watch<SelectionContentProvider>().content?.course?.id;
    if (courseId != null && courseId != _loadedCourseId) {
      _loadedCourseId = courseId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) onRefresh();
      });
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _kBg,
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            const SliverToBoxAdapter(child: _Header()),
            SliverPersistentHeader(
              pinned: true,
              delegate: const _TabsDelegate(),
            ),
          ],
          body: TabBarView(
            children: [
              _list(_pending, emptyText: 'No tests waiting for you right now.'),
              _list(_attempted,
                  emptyText: 'Nothing marked yet. Sit a test and it lands here.'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _list(List<TestSummary> tests, {required String emptyText}) {
    // The list's own shape, not a dot in an empty tab.
    if (_loading) return const _TestsSkeleton();
    if (_error != null) return _message(_error!, onRetry: onRefresh);
    if (tests.isEmpty) return _message(emptyText);

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 28.h),
      itemCount: tests.length,
      separatorBuilder: (_, __) => SizedBox(height: 12.h),
      itemBuilder: (context, index) {
        final test = tests[index];
        return test.isSubmitted
            ? _CompletedCard(test: test, onTap: () => _open(test))
            : _PendingCard(
                test: test,
                onTap: () => _open(test),
                // Re-splits the two tabs. The paper is finished; it just did
                // not get there by being submitted.
                onExpired: () {
                  if (mounted) setState(() {});
                },
              );
      },
    );
  }

  Widget _message(String text, {Future<void> Function()? onRetry}) => Center(
        child: Padding(
          padding: EdgeInsets.all(36.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_rounded, size: 40.sp, color: Colors.grey.shade400),
              SizedBox(height: 14.h),
              Text(text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13.sp, height: 1.4, color: Colors.grey.shade600)),
              if (onRetry != null) ...[
                SizedBox(height: 16.h),
                OutlinedButton(
                    onPressed: onRetry, child: const Text('Try again')),
              ],
            ],
          ),
        ),
      );
}

/// The banner: where you are, and the one rule that governs everything under
/// it. No progress figures — this is a student opening a list of papers, not
/// a report on how they are doing.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 20.h),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kPrimary, _kPrimaryDark],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => Navigator.maybePop(context),
              icon: Icon(Icons.chevron_left_rounded,
                  size: 28.sp, color: Colors.white),
            ),
            SizedBox(width: 8.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Tests',
                    style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                SizedBox(height: 2.h),
                Text('One attempt each — make it count',
                    style: TextStyle(fontSize: 11.5.sp, color: Colors.white70)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Pinned so the tabs stay reachable while a long list scrolls under them.
class _TabsDelegate extends SliverPersistentHeaderDelegate {
  const _TabsDelegate();

  @override
  double get minExtent => 54;

  @override
  double get maxExtent => 54;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    return Container(
      color: _kBg,
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      child: TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey.shade700,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        splashBorderRadius: BorderRadius.circular(24.r),
        indicator: BoxDecoration(
          color: _kPrimary,
          borderRadius: BorderRadius.circular(24.r),
        ),
        labelStyle: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w600),
        tabs: const [
          // No counts: the tab is a place to go, not a statistic. The list
          // underneath already says how many there are.
          Tab(text: '     To attempt     '),
          Tab(text: '     Completed     '),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TabsDelegate old) => false;
}

/// A paper still to sit. Leads with what it costs — minutes, questions, the
/// penalty — because that is the decision being made here.
class _PendingCard extends StatelessWidget {
  final TestSummary test;
  final VoidCallback onTap;

  /// Passed down to the countdown, so the tab can re-split when the clock
  /// runs out under the student's eyes.
  final VoidCallback? onExpired;

  const _PendingCard(
      {required this.test, required this.onTap, this.onExpired});

  @override
  Widget build(BuildContext context) {
    final running = test.isInProgress;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18.r),
          boxShadow: _kCardShadow,
        ),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 12.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42.w,
                    height: 42.w,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_kPrimary, _kPrimaryDark],
                      ),
                      borderRadius: BorderRadius.circular(13.r),
                    ),
                    child: Icon(
                        running
                            ? Icons.play_arrow_rounded
                            : Icons.description_outlined,
                        size: 22.sp,
                        color: Colors.white),
                  ),
                  SizedBox(width: 13.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(test.name,
                            style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w700,
                                color: _kInk)),
                        SizedBox(height: 8.h),
                        Wrap(
                          spacing: 8.w,
                          runSpacing: 6.h,
                          children: [
                            _Chip(
                                icon: Icons.timer_outlined,
                                label: '${test.durationMinutes} min'),
                            _Chip(
                                icon: Icons.help_outline_rounded,
                                label: '${test.totalQuestions} MCQs'),
                            if (test.hasNegativeMarking)
                              _Chip(
                                  icon: Icons.remove_circle_outline_rounded,
                                  label: '${test.marksIncorrect}',
                                  danger: true),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(16.w, 11.h, 16.w, 11.h),
              decoration: BoxDecoration(
                color: running ? _kAmber.withValues(alpha: 0.1) : _kBg,
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(18.r)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: running
                        ? _ResumeCountdown(test: test, onExpired: onExpired)
                        : Text('One attempt only',
                            style: TextStyle(
                                fontSize: 11.5.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700)),
                  ),
                  Text(running ? 'Resume' : 'Start',
                      style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w800,
                          color: running ? _kAmber : _kPrimary)),
                  Icon(Icons.arrow_forward_rounded,
                      size: 16.sp, color: running ? _kAmber : _kPrimary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A marked paper, led by its score.
///
/// Deliberately not the same card as an unsat test. Duration and negative
/// marking are there to help decide whether to sit a paper — once it is
/// marked they are noise, and the score they produced is the only thing
/// worth scanning a column of finished tests for.
class _CompletedCard extends StatelessWidget {
  final TestSummary test;
  final VoidCallback onTap;

  const _CompletedCard({required this.test, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final score = test.lastAttempt?.score ?? 0;
    final outOf = test.totalMarks;

    // Negative marking can drive a score below zero. The number is shown as
    // it stands, but the ring has nowhere below empty to go.
    final fraction = outOf <= 0 ? 0.0 : (score / outOf).clamp(0.0, 1.0);

    final color = score <= 0
        ? _kRed
        : fraction >= 0.6
            ? _kPrimary
            : fraction >= 0.35
                ? _kAmber
                : _kRed;

    final submittedAt = test.lastAttempt?.submittedAt?.toLocal();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18.r),
          boxShadow: _kCardShadow,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 54.w,
              height: 54.w,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: fraction,
                      strokeWidth: 5,
                      strokeCap: StrokeCap.round,
                      backgroundColor: const Color(0xFFEFEFEF),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$score',
                          style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w800,
                              color: color)),
                      Text('of ${outOf.toStringAsFixed(0)}',
                          style: TextStyle(
                              fontSize: 8.5.sp, color: Colors.grey.shade600)),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(test.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14.5.sp,
                          fontWeight: FontWeight.w700,
                          color: _kInk)),
                  SizedBox(height: 5.h),
                  if (submittedAt != null)
                    Text(
                      'Attempted ${submittedAt.day} '
                      '${_months[submittedAt.month - 1]}',
                      style: TextStyle(
                          fontSize: 11.5.sp, color: Colors.grey.shade600),
                    ),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Text('Review answers',
                          style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                              color: _kPrimary)),
                      SizedBox(width: 3.w),
                      Icon(Icons.arrow_forward_rounded,
                          size: 14.sp, color: _kPrimary),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool danger;

  const _Chip({required this.icon, required this.label, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final color = danger ? _kRed : Colors.grey.shade700;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: danger ? _kRed.withValues(alpha: 0.08) : const Color(0xFFF4F6EE),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.sp, color: color),
          SizedBox(width: 4.w),
          Text(label,
              style: TextStyle(
                  fontSize: 10.5.sp, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

/// Time left on a paper the student walked away from, ticking on the card.
///
/// The clock did not stop when they left, and a card that says only "Resume"
/// hides that. Ticks locally off the derived deadline; the paper itself still
/// takes the server's number when it opens.
class _ResumeCountdown extends StatefulWidget {
  final TestSummary test;

  /// Fired the moment the clock reaches zero.
  ///
  /// The tab splits pending from finished in its own build, and this ticker
  /// lives in a card — so without telling the parent, a paper that expired
  /// while the student was looking at the list stayed on the wrong tab until
  /// something else happened to refresh it.
  final VoidCallback? onExpired;

  const _ResumeCountdown({required this.test, this.onExpired});

  @override
  State<_ResumeCountdown> createState() => _ResumeCountdownState();
}

class _ResumeCountdownState extends State<_ResumeCountdown> {
  Timer? _ticker;

  /// Once only — the parent rebuild would otherwise fire this every second.
  bool _announced = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});

      if ((widget.test.secondsLeftOnAttempt ?? 0) <= 0 && !_announced) {
        _announced = true;
        // Stop ticking: there is nothing left to count, and the card is
        // about to move to the other tab.
        _ticker?.cancel();
        widget.onExpired?.call();
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.test.secondsLeftOnAttempt ?? 0;
    final h = left ~/ 3600;
    final m = ((left % 3600) ~/ 60).toString().padLeft(2, '0');
    final sec = (left % 60).toString().padLeft(2, '0');
    final expired = left <= 0;

    return Row(
      children: [
        Icon(expired ? Icons.error_outline_rounded : Icons.timer_outlined,
            size: 14.sp, color: expired ? _kRed : _kAmber),
        SizedBox(width: 5.w),
        Flexible(
          child: Text(
            // Not paused, just left. The countdown says so better than words.
            expired ? 'Time is up' : '$h:$m:$sec left',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w700,
              color: expired ? _kRed : _kAmber,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

/// The Tests tab while its list is on the way.
///
/// Four rows shaped like a test card — the title, a shorter meta line, and
/// the action pill on the right — so the page fills in where it is going to
/// be rather than appearing from behind a spinner.
class _TestsSkeleton extends StatelessWidget {
  const _TestsSkeleton();

  static const int _rows = 4;

  @override
  Widget build(BuildContext context) {
    return LoadingWave(
      steps: _rows,
      builder: (context, lift) => ListView.separated(
        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _rows,
        separatorBuilder: (_, __) => SizedBox(height: 14.h),
        itemBuilder: (context, i) => Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18.r),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WaveBar(height: 13.h, radius: 7.r, lift: lift(i)),
                    SizedBox(height: 9.h),
                    FractionallySizedBox(
                      widthFactor: 0.55,
                      child: WaveBar(height: 11.h, radius: 6.r, lift: lift(i)),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 14.w),
              WaveBar(width: 74.w, height: 32.h, radius: 18.r, lift: lift(i)),
            ],
          ),
        ),
      ),
    );
  }
}
