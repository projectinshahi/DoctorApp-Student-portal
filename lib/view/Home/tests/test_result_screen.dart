// lib/view/Home/tests/test_result_screen.dart
//
// The marked paper and the leaderboard.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../models/test_model.dart';
import '../../../repository/test_provider.dart';
import '../../../widget/app_shimmer.dart';

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

    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
      children: [
        Container(
          padding: EdgeInsets.all(18.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18.r),
          ),
          child: Column(
            children: [
              Text('Score',
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600)),
              SizedBox(height: 6.h),
              Text(
                // Rendered exactly as sent: with negative marking a total can
                // be negative, and abs() would flatter the student.
                '${result.score} / ${result.totalMarks}',
                style: TextStyle(
                    fontSize: 26.sp, fontWeight: FontWeight.w800, color: _kPrimary),
              ),
              SizedBox(height: 14.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _Stat(label: 'Correct', value: '${result.correctCount}', color: _kPrimary),
                  _Stat(label: 'Wrong', value: '${result.wrongCount}', color: Colors.red.shade600),
                  // Skipped is its own outcome: 0 marks, no penalty.
                  _Stat(label: 'Skipped', value: '${result.skippedCount}', color: Colors.grey.shade600),
                ],
              ),
              SizedBox(height: 12.h),
              Text('Time taken ${_clock(result.timeTakenSeconds)}',
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600)),
            ],
          ),
        ),
        SizedBox(height: 18.h),
        Text('Your answers',
            style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: Colors.black87)),
        SizedBox(height: 10.h),
        for (var i = 0; i < result.results.length; i++) ...[
          _ResultCard(index: i, result: result.results[i]),
          SizedBox(height: 12.h),
        ],
      ],
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

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800, color: color)),
        SizedBox(height: 2.h),
        Text(label, style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600)),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  final int index;
  final TestQuestionResult result;

  const _ResultCard({required this.index, required this.result});

  /// Three states, not two. A skipped question is neither right nor wrong,
  /// and painting it red would tell the student they lost marks they kept.
  ({String label, Color color}) get _verdict {
    if (!result.answered) return (label: 'Skipped', color: Colors.grey.shade600);
    if (result.isCorrect) return (label: 'Correct', color: _kPrimary);
    return (label: 'Wrong', color: Colors.red.shade600);
  }

  @override
  Widget build(BuildContext context) {
    final verdict = _verdict;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Q${index + 1}',
                  style: TextStyle(
                      fontSize: 12.sp, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: verdict.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(verdict.label,
                    style: TextStyle(
                        fontSize: 10.sp, fontWeight: FontWeight.w700, color: verdict.color)),
              ),
              const Spacer(),
              Text(
                // Negative marks render as sent: "-0.25", never "--0.25".
                '${result.marksAwarded > 0 ? '+' : ''}${result.marksAwarded}',
                style: TextStyle(
                    fontSize: 12.sp, fontWeight: FontWeight.w700, color: verdict.color),
              ),
            ],
          ),
          if (result.subject != null) ...[
            SizedBox(height: 6.h),
            Text(result.subject!,
                style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600)),
          ],
          if (result.questionText != null && result.questionText!.isNotEmpty) ...[
            SizedBox(height: 10.h),
            Text(result.questionText!,
                style: TextStyle(fontSize: 13.5.sp, color: Colors.black87, height: 1.45)),
          ],
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: Text(
                  result.answered
                      ? 'You chose ${result.selectedOption}'
                      : 'Not answered',
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade700),
                ),
              ),
              Text('Correct: ${result.correctOption ?? '—'}',
                  style: TextStyle(
                      fontSize: 12.sp, fontWeight: FontWeight.w700, color: _kPrimary)),
            ],
          ),
          if (result.explanation != null && result.explanation!.isNotEmpty) ...[
            SizedBox(height: 12.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F5EC),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Text(result.explanation!,
                  style: TextStyle(fontSize: 12.5.sp, color: Colors.black87, height: 1.5)),
            ),
          ],
        ],
      ),
    );
  }
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
