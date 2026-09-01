// lib/view/Home/tests/test_result_screen.dart
//
// The marked paper and the leaderboard.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../models/test_model.dart';
import '../../../repository/test_provider.dart';
import '../../../widget/app_shimmer.dart';
import 'test_review_screen.dart';

const Color _kPrimary = Color(0xFF87986B);
const Color _kBg = Color(0xFFEFF4E2);

class TestResultScreen extends StatelessWidget {
  final int attemptId;
  final int testId;
  final String testName;

  /// Passed straight through when arriving from a submit, so the sheet does
  /// not refetch what it was just handed.
  final TestResult? preloaded;
  final Leaderboard? leaderboard;

  const TestResultScreen({
    super.key,
    required this.attemptId,
    required this.testId,
    required this.testName,
    this.preloaded,
    this.leaderboard,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<TestProvider>(
      create: (_) {
        final provider = TestProvider()..leaderboardTestId = testId;
        if (preloaded != null) {
          provider.result = preloaded;
          provider.leaderboard = leaderboard;
          provider.isLoading = false;
          if (leaderboard == null) provider.loadLeaderboard();
        } else {
          provider.loadResult(attemptId).then((_) => provider.loadLeaderboard());
        }
        return provider;
      },
      child: _ResultView(testName: testName),
    );
  }
}

class _ResultView extends StatelessWidget {
  final String testName;

  const _ResultView({required this.testName});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TestProvider>();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _kBg,
        appBar: AppBar(
          backgroundColor: _kBg,
          elevation: 0,
          title: Text(testName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 15.sp, fontWeight: FontWeight.w700, color: Colors.black87)),
          leading: IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: Icon(Icons.chevron_left_rounded, size: 30.sp, color: Colors.black),
          ),
          bottom: TabBar(
            labelColor: _kPrimary,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: _kPrimary,
            labelStyle: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
            tabs: const [Tab(text: 'Result'), Tab(text: 'Leaderboard')],
          ),
        ),
        body: provider.isLoading
            ? const ScreenShimmer(layout: ShimmerLayout.rows)
            : TabBarView(
                children: [
                  _ResultTab(provider: provider),
                  _LeaderboardTab(provider: provider),
                ],
              ),
      ),
    );
  }
}

class _ResultTab extends StatelessWidget {
  final TestProvider provider;

  const _ResultTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final result = provider.result;
    if (result == null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32.w),
          child: Text(provider.failure?.message ?? 'This result is not available.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade700)),
        ),
      );
    }

    final me = provider.leaderboard?.me;
    final total = provider.leaderboard?.totalParticipants ?? 0;

    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
      children: [
        if (me != null && total > 0) ...[
          _RankHero(rank: me.rank, outOf: total),
          SizedBox(height: 14.h),
        ],
        SizedBox(
          width: double.infinity,
          height: 48.h,
          child: ElevatedButton.icon(
            // The half a student learns from. It is a button rather than a
            // section further down because on a 200-question paper the score
            // is one screen and the answers are forty.
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TestReviewScreen(result: result),
              ),
            ),
            icon: Icon(Icons.fact_check_outlined, size: 19.sp),
            label: Text('REVIEW ANSWERS',
                style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _kPrimary,
              elevation: 0,
              side: const BorderSide(color: _kPrimary),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(26.r)),
            ),
          ),
        ),
        SizedBox(height: 14.h),
        Container(
          padding: EdgeInsets.fromLTRB(18.w, 20.h, 18.w, 18.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18.r),
          ),
          child: Column(
            children: [
              Text(
                // Rendered exactly as sent: with negative marking a total can
                // be negative, and abs() would flatter the student.
                '${result.score}',
                style: TextStyle(
                    fontSize: 34.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87),
              ),
              SizedBox(height: 2.h),
              Text('Total score out of ${result.totalMarks}',
                  style: TextStyle(fontSize: 12.5.sp, color: Colors.grey.shade600)),
              if (me != null && total > 0) ...[
                SizedBox(height: 10.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF8E8),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text('${_percentile(me.rank, total)} Percentile',
                      style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800)),
                ),
              ],
              SizedBox(height: 20.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _Gauge(
                      value: result.correctCount,
                      total: result.totalQuestions,
                      label: 'Correct',
                      color: _kPrimary),
                  _Gauge(
                      value: result.wrongCount,
                      total: result.totalQuestions,
                      label: 'Wrong',
                      color: const Color(0xFFD65745)),
                  // Skipped is its own outcome: 0 marks, no penalty.
                  _Gauge(
                      value: result.skippedCount,
                      total: result.totalQuestions,
                      label: 'Skipped',
                      color: Colors.grey.shade500),
                ],
              ),
              SizedBox(height: 18.h),
              Text('Time taken ${_clock(result.timeTakenSeconds)}',
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600)),
            ],
          ),
        ),
        SizedBox(height: 14.h),
        Center(
          child: TextButton(
            onPressed: () => DefaultTabController.of(context).animateTo(1),
            child: Text('See how you compare with others',
                style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: _kPrimary)),
          ),
        ),
        if (_bySubject(result).isNotEmpty) ...[
          SizedBox(height: 10.h),
          _SubjectBreakdown(rows: _bySubject(result)),
        ],
      ],
    );
  }
}

/// Percentile from rank, the way a rank list defines it: the share of the
/// field at or below you. Derived rather than fetched — the leaderboard sends
/// rank and total, and those are the only two numbers it needs.
String _percentile(int rank, int total) {
  if (total <= 0) return '0.00';
  final value = (total - rank) / total * 100;
  return value.toStringAsFixed(2);
}

/// Correct-per-subject, counted off the marked paper. Not a comparison
/// against other students — the API sends no cohort averages — just where
/// this student's own marks went.
List<({String subject, int correct, int total})> _bySubject(TestResult result) {
  final order = <String>[];
  final correct = <String, int>{};
  final total = <String, int>{};

  for (final row in result.results) {
    final subject = row.subject;
    if (subject == null || subject.isEmpty) continue;
    if (!order.contains(subject)) order.add(subject);
    total[subject] = (total[subject] ?? 0) + 1;
    if (row.answered && row.isCorrect) {
      correct[subject] = (correct[subject] ?? 0) + 1;
    }
  }

  return [
    for (final subject in order)
      (subject: subject, correct: correct[subject] ?? 0, total: total[subject]!),
  ];
}

class _RankHero extends StatelessWidget {
  final int rank;
  final int outOf;

  const _RankHero({required this.rank, required this.outOf});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 20.h),
      decoration: BoxDecoration(
        color: _kPrimary,
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Column(
        children: [
          Icon(Icons.emoji_events_outlined, size: 34.sp, color: Colors.white),
          SizedBox(height: 6.h),
          Text('Rank',
              style: TextStyle(fontSize: 12.sp, color: Colors.white70)),
          Text('$rank',
              style: TextStyle(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          SizedBox(height: 2.h),
          Text('Out of $outOf',
              style: TextStyle(fontSize: 12.5.sp, color: Colors.white70)),
        ],
      ),
    );
  }
}

/// A ring per outcome. The ring is the share of the paper, so 146 wrong out
/// of 200 reads as most of the circle without doing the division.
class _Gauge extends StatelessWidget {
  final int value;
  final int total;
  final String label;
  final Color color;

  const _Gauge({
    required this.value,
    required this.total,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 62.w,
          height: 62.w,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: total == 0 ? 0 : value / total,
                  strokeWidth: 5,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              Text('$value',
                  style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87)),
            ],
          ),
        ),
        SizedBox(height: 8.h),
        Text(label,
            style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade700)),
      ],
    );
  }
}

class _SubjectBreakdown extends StatelessWidget {
  final List<({String subject, int correct, int total})> rows;

  const _SubjectBreakdown({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Performance by subject',
              style: TextStyle(
                  fontSize: 14.5.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87)),
          SizedBox(height: 14.h),
          for (final row in rows) ...[
            Row(
              children: [
                Expanded(
                  child: Text(row.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12.5.sp, color: Colors.grey.shade800)),
                ),
                Text('${row.correct}/${row.total}',
                    style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade700)),
              ],
            ),
            SizedBox(height: 6.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(10.r),
              child: LinearProgressIndicator(
                value: row.total == 0 ? 0 : row.correct / row.total,
                minHeight: 6.h,
                backgroundColor: const Color(0xFFEFEFEF),
                valueColor: const AlwaysStoppedAnimation<Color>(_kPrimary),
              ),
            ),
            SizedBox(height: 14.h),
          ],
        ],
      ),
    );
  }
}

/// mm:ss. Time is the leaderboard's tiebreak, so it has to read as a duration
/// next to the scores it separates — "1200s" makes the reader do the division.
String _clock(int seconds) {
  final m = seconds ~/ 60;
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

class _LeaderboardTab extends StatelessWidget {
  final TestProvider provider;

  const _LeaderboardTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final board = provider.leaderboard;
    if (board == null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32.w),
          child: Text('The leaderboard is not available right now.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade700)),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 8.h),
          child: Row(
            children: [
              Text('${board.totalParticipants} participants',
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade700)),
              const Spacer(),
              Text('Score ranks · time breaks ties',
                  style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600)),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 16.h),
            itemCount: board.entries.length,
            separatorBuilder: (_, __) => SizedBox(height: 10.h),
            itemBuilder: (context, index) => _LeaderRow(
              entry: board.entries[index],
              isMe: board.me != null && board.entries[index].rank == board.me!.rank,
            ),
          ),
        ),
        // Pinned, because a student ranked 87th never appears in a top 50.
        // Skipped when they are already in the list above, so their row does
        // not show twice.
        if (board.me != null && !board.meIsListed)
          Container(
            padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 20.h),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: _LeaderRow(entry: board.me!, isMe: true),
          ),
      ],
    );
  }
}

class _LeaderRow extends StatelessWidget {
  final LeaderboardEntry entry;
  final bool isMe;

  const _LeaderRow({required this.entry, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: isMe ? _kPrimary.withValues(alpha: 0.12) : Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: isMe ? Border.all(color: _kPrimary) : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34.w,
            // The server's rank, never the row index: ties share a rank and
            // the next one skips, so counting rows would renumber them.
            child: Text('#${entry.rank}',
                style: TextStyle(
                    fontSize: 13.sp, fontWeight: FontWeight.w800, color: _kPrimary)),
          ),
          Expanded(
            child: Text(isMe ? '${entry.name}  (you)' : entry.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13.sp, fontWeight: FontWeight.w600, color: Colors.black87)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${entry.score}',
                  style: TextStyle(
                      fontSize: 13.sp, fontWeight: FontWeight.w700, color: Colors.black87)),
              Text(_clock(entry.timeTakenSeconds),
                  style: TextStyle(fontSize: 10.5.sp, color: Colors.grey.shade600)),
            ],
          ),
        ],
      ),
    );
  }
}
