// lib/view/Home/tests/test_review_screen.dart
//
// The marked paper, question by question.
//
// Split out from the score sheet because they answer different questions.
// The score sheet answers "how did I do"; this answers "what did I get wrong
// and why", which is the half a student actually learns from. Banding the
// questions into tabs of 20 keeps a 200-question paper navigable.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../models/test_model.dart';

const Color _kPrimary = Color(0xFF87986B);
const Color _kBg = Color(0xFFEFF4E2);
const Color _kWrong = Color(0xFFD65745);

/// Questions per tab. 20 is what fits a band label — "1 - 20" — without the
/// tab bar scrolling on a phone.
const int _kBand = 20;

enum ReviewFilter { all, correct, wrong, skipped }

extension on ReviewFilter {
  String get label => switch (this) {
        ReviewFilter.all => 'All',
        ReviewFilter.correct => 'Correct',
        ReviewFilter.wrong => 'Wrong',
        ReviewFilter.skipped => 'Skipped',
      };

  bool matches(TestQuestionResult result) => switch (this) {
        ReviewFilter.all => true,
        // Skipped is its own outcome, not a kind of wrong: it scores 0 where
        // wrong scores the negative mark.
        ReviewFilter.correct => result.answered && result.isCorrect,
        ReviewFilter.wrong => result.answered && !result.isCorrect,
        ReviewFilter.skipped => !result.answered,
      };
}

class TestReviewScreen extends StatefulWidget {
  final TestResult result;

  const TestReviewScreen({super.key, required this.result});

  @override
  State<TestReviewScreen> createState() => _TestReviewScreenState();
}

class _TestReviewScreenState extends State<TestReviewScreen> {
  ReviewFilter _filter = ReviewFilter.all;

  List<TestQuestionResult> get _all => widget.result.results;

  /// Question numbers are the paper's, not the filtered list's. Filtering to
  /// "Wrong" must still call question 37 question 37.
  List<(int, TestQuestionResult)> get _numbered =>
      [for (var i = 0; i < _all.length; i++) (i + 1, _all[i])];

  int get _bandCount => (_all.length / _kBand).ceil();

  Future<void> _pickFilter() async {
    final picked = await showModalBottomSheet<ReviewFilter>(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 8.h),
            for (final filter in ReviewFilter.values)
              ListTile(
                title: Text(filter.label,
                    style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight:
                            filter == _filter ? FontWeight.w700 : FontWeight.w500,
                        color: filter == _filter ? _kPrimary : Colors.black87)),
                trailing: Text('${_all.where(filter.matches).length}',
                    style:
                        TextStyle(fontSize: 13.sp, color: Colors.grey.shade600)),
                onTap: () => Navigator.pop(sheetContext, filter),
              ),
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );

    if (picked != null && mounted) setState(() => _filter = picked);
  }

  @override
  Widget build(BuildContext context) {
    // One band is not a choice, so a short paper gets no tab bar.
    final banded = _bandCount > 1;

    final appBar = AppBar(
      backgroundColor: _kBg,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.maybePop(context),
        icon: Icon(Icons.arrow_back_rounded, size: 24.sp, color: Colors.black87),
      ),
      title: Text('Review',
          style: TextStyle(
              fontSize: 17.sp, fontWeight: FontWeight.w700, color: Colors.black87)),
      actions: [
        IconButton(
          onPressed: _pickFilter,
          tooltip: 'Filter',
          icon: Badge(
            isLabelVisible: _filter != ReviewFilter.all,
            backgroundColor: _kPrimary,
            child: Icon(Icons.filter_alt_outlined,
                size: 22.sp, color: Colors.black87),
          ),
        ),
      ],
      bottom: banded
          ? TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: _kPrimary,
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: _kPrimary,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
              tabs: [
                for (var band = 0; band < _bandCount; band++)
                  Tab(
                      text: '${band * _kBand + 1} - '
                          '${((band + 1) * _kBand).clamp(0, _all.length)}'),
              ],
            )
          : null,
    );

    if (!banded) {
      return Scaffold(
        backgroundColor: _kBg,
        appBar: appBar,
        body: _list(_numbered),
      );
    }

    return DefaultTabController(
      length: _bandCount,
      child: Scaffold(
        backgroundColor: _kBg,
        appBar: appBar,
        body: TabBarView(
          children: [
            for (var band = 0; band < _bandCount; band++)
              _list(_numbered
                  .skip(band * _kBand)
                  .take(_kBand)
                  .toList()),
          ],
        ),
      ),
    );
  }

  Widget _list(List<(int, TestQuestionResult)> items) {
    final shown = items.where((item) => _filter.matches(item.$2)).toList();

    if (shown.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32.w),
          child: Text('No ${_filter.label.toLowerCase()} questions here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade600)),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
      itemCount: shown.length,
      separatorBuilder: (_, __) => SizedBox(height: 10.h),
      itemBuilder: (context, index) => _ReviewCard(
        number: shown[index].$1,
        result: shown[index].$2,
      ),
    );
  }
}

/// A question, collapsed to its stem. Tapping opens the answer and the
/// explanation — the reason this screen exists — without leaving the list.
class _ReviewCard extends StatefulWidget {
  final int number;
  final TestQuestionResult result;

  const _ReviewCard({required this.number, required this.result});

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final result = widget.result;

    final (verdict, color) = !result.answered
        ? ('Skipped', Colors.grey.shade600)
        : result.isCorrect
            ? ('Correct', _kPrimary)
            : ('Wrong', _kWrong);

    return GestureDetector(
      onTap: () => setState(() => _open = !_open),
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '${widget.number}.  ${result.questionText ?? 'Image question'}',
                    maxLines: _open ? null : 3,
                    overflow: _open ? null : TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13.5.sp, height: 1.4, color: Colors.black87),
                  ),
                ),
                SizedBox(width: 10.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(verdict,
                      style: TextStyle(
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w700,
                          color: color)),
                ),
              ],
            ),
            if (result.subject != null && result.subject!.isNotEmpty) ...[
              SizedBox(height: 8.h),
              Text(result.subject!,
                  style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600)),
            ],
            if (_open) ...[
              SizedBox(height: 12.h),
              Divider(height: 1, color: Colors.grey.shade200),
              SizedBox(height: 12.h),
              _AnswerLine(
                label: 'You chose',
                value: result.answered ? result.selectedOption ?? '—' : 'Not answered',
                color: result.answered
                    ? (result.isCorrect ? _kPrimary : _kWrong)
                    : Colors.grey.shade600,
              ),
              SizedBox(height: 6.h),
              _AnswerLine(
                  label: 'Correct',
                  value: result.correctOption ?? '—',
                  color: _kPrimary),
              SizedBox(height: 6.h),
              _AnswerLine(
                label: 'Marks',
                value: result.marksAwarded > 0
                    ? '+${result.marksAwarded}'
                    : '${result.marksAwarded}',
                color: result.marksAwarded > 0
                    ? _kPrimary
                    : result.marksAwarded < 0
                        ? _kWrong
                        : Colors.grey.shade600,
              ),
              if (result.explanation != null && result.explanation!.isNotEmpty) ...[
                SizedBox(height: 12.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: _kBg,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Text(result.explanation!,
                      style: TextStyle(
                          fontSize: 12.5.sp,
                          height: 1.45,
                          color: Colors.grey.shade800)),
                ),
              ],
            ] else ...[
              SizedBox(height: 8.h),
              Row(
                children: [
                  Text('Tap to see the answer',
                      style:
                          TextStyle(fontSize: 11.sp, color: Colors.grey.shade500)),
                  SizedBox(width: 4.w),
                  Icon(Icons.expand_more_rounded,
                      size: 15.sp, color: Colors.grey.shade500),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AnswerLine extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _AnswerLine(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 84.w,
          child: Text(label,
              style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600)),
        ),
        Text(value,
            style: TextStyle(
                fontSize: 12.5.sp, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}
