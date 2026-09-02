// lib/view/Home/daily_quiz/daily_quiz_result_screen.dart
//
// Today's sheet, plus the full review.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../models/daily_quiz_model.dart';

const Color _kPrimary = Color(0xFF87986B);
const Color _kPrimaryDark = Color(0xFF6B7C51);
const Color _kBg = Color(0xFFEFF4E2);
const Color _kRed = Color(0xFFD65745);
const Color _kAmber = Color(0xFFE8A33D);

class DailyQuizResultScreen extends StatelessWidget {
  final DailyQuizResult result;

  const DailyQuizResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: Icon(Icons.chevron_left_rounded, size: 30.sp, color: Colors.black),
        ),
        title: Text('MCQ of the Day',
            style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
                color: Colors.black87)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 28.h),
        children: [
          _Hero(result: result),
          SizedBox(height: 18.h),
          Text('Review',
              style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87)),
          SizedBox(height: 10.h),
          for (var i = 0; i < result.results.length; i++) ...[
            _ReviewCard(number: i + 1, row: result.results[i]),
            SizedBox(height: 10.h),
          ],
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final DailyQuizResult result;

  const _Hero({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kPrimary, _kPrimaryDark],
        ),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Column(
        children: [
          if (result.currentStreak > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_fire_department_rounded,
                    size: 20.sp, color: _kAmber),
                SizedBox(width: 5.w),
                Text(
                    '${result.currentStreak} '
                    '${result.currentStreak == 1 ? 'day' : 'days'} streak',
                    style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ],
            ),
            SizedBox(height: 12.h),
          ],
          Text(
            // Can be negative with negative marking. Printed as sent, so a
            // -1.5 never renders as "--1.5".
            '${result.score}',
            style: TextStyle(
                fontSize: 34.sp, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          Text('score', style: TextStyle(fontSize: 12.sp, color: Colors.white70)),
          SizedBox(height: 18.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _Stat(value: '${result.correctCount}', label: 'Correct'),
              _Stat(value: '${result.wrongCount}', label: 'Wrong'),
              // Skipped is its own outcome: 0 marks, no penalty.
              _Stat(value: '${result.skippedCount}', label: 'Skipped'),
            ],
          ),
          SizedBox(height: 16.h),
          Text(
            // Out of what was answered, not out of ten — so answering one and
            // getting it right is 100%. The count is beside it for exactly
            // that reason.
            '${result.accuracy}% accuracy of ${result.answeredCount} answered',
            style: TextStyle(fontSize: 11.5.sp, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;

  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          SizedBox(height: 2.h),
          Text(label,
              style: TextStyle(fontSize: 11.sp, color: Colors.white70)),
        ],
      );
}

class _ReviewCard extends StatelessWidget {
  final int number;
  final DailyQuizResultRow row;

  const _ReviewCard({required this.number, required this.row});

  @override
  Widget build(BuildContext context) {
    // Three states, and skipped is not a kind of wrong — it scores 0 rather
    // than the negative mark, so it must not be painted red.
    final (verdict, color) = !row.answered
        ? ('Skipped', Colors.grey.shade600)
        : row.isCorrect
            ? ('Correct', _kPrimary)
            : ('Wrong', _kRed);

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Q$number',
                  style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey.shade600)),
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
              const Spacer(),
              Text(
                row.marksAwarded > 0
                    ? '+${row.marksAwarded}'
                    : '${row.marksAwarded}',
                style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: row.marksAwarded > 0
                        ? _kPrimary
                        : row.marksAwarded < 0
                            ? _kRed
                            : Colors.grey.shade600),
              ),
            ],
          ),
          if (row.subject != null) ...[
            SizedBox(height: 8.h),
            Text([row.subject, row.topic].whereType<String>().join(' · '),
                style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600)),
          ],
          SizedBox(height: 8.h),
          if (row.questionText != null)
            Text(row.questionText!,
                style: TextStyle(
                    fontSize: 13.sp, height: 1.4, color: Colors.black87)),
          SizedBox(height: 12.h),
          for (final option in row.options)
            Padding(
              padding: EdgeInsets.only(bottom: 6.h),
              child: _OptionLine(option: option, row: row),
            ),
          if (row.explanation != null && row.explanation!.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: _kBg,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Text(row.explanation!,
                  style: TextStyle(
                      fontSize: 12.5.sp,
                      height: 1.45,
                      color: Colors.grey.shade800)),
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionLine extends StatelessWidget {
  final DailyQuizOption option;
  final DailyQuizResultRow row;

  const _OptionLine({required this.option, required this.row});

  @override
  Widget build(BuildContext context) {
    final isCorrect = option.id == row.correctOptionId || option.isCorrect == true;
    // Their pick, shown alongside the right answer when they got it wrong.
    final isTheirs = row.answered && option.id == row.selectedOptionId;

    final color = isCorrect
        ? _kPrimary
        : isTheirs
            ? _kRed
            : Colors.grey.shade700;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
            isCorrect
                ? Icons.check_circle_rounded
                : isTheirs
                    ? Icons.cancel_rounded
                    : Icons.circle_outlined,
            size: 14.sp,
            color: color),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(option.optionText ?? 'Image option',
              style: TextStyle(
                  fontSize: 12.5.sp,
                  height: 1.35,
                  fontWeight:
                      isCorrect || isTheirs ? FontWeight.w700 : FontWeight.w400,
                  color: color)),
        ),
      ],
    );
  }
}
