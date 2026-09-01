// lib/view/Home/tests/test_instructions_screen.dart
//
// The gate in front of a fresh attempt.
//
// It exists for one reason: the clock is the server's and it starts the
// moment the attempt is created. Closing the app does not pause it, and
// neither does leaving the screen. That has to be said before the student
// commits, not discovered afterwards — so this screen is shown only for a
// new attempt. Resuming goes straight back to the paper, because by then the
// clock has been running for a while and rules are just a delay.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../models/test_model.dart';
import 'test_attempt_screen.dart';

const Color _kPrimary = Color(0xFF87986B);
const Color _kBg = Color(0xFFEFF4E2);

class TestInstructionsScreen extends StatelessWidget {
  final TestSummary test;

  const TestInstructionsScreen({super.key, required this.test});

  /// The rules, written from this test's own numbers rather than hardcoded,
  /// so a 200-question paper does not claim to have 10.
  List<String> get _rules => [
        'This test is one part of ${test.totalQuestions} '
            '${test.totalQuestions == 1 ? 'question' : 'questions'}, allotted '
            '${test.durationMinutes} minutes in a single sitting.',
        'You get one attempt. Once you submit, the paper is closed and the '
            'score stands — there is no retake.',
        'The timer starts as soon as you begin and cannot be paused. It keeps '
            'running if you leave the app or close it.',
        if (test.hasNegativeMarking)
          'Each correct answer scores ${test.marksCorrect}. Each wrong answer '
              'loses ${test.marksIncorrect.abs()}. A question you skip scores '
              '0 — skipping is safer than guessing.'
        else
          'Each correct answer scores ${test.marksCorrect}. There is no '
              'negative marking.',
        'You can move between questions in any order, and change or clear an '
            'answer until you submit.',
        'When the time runs out the test is submitted automatically with the '
            'answers you have given.',
        'Answers and explanations appear only after you submit.',
      ];

  Future<void> _start(BuildContext context) async {
    // The one thing worth a second tap. Everything else on this screen is
    // information; this is the door closing.
    final go = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        content: Text(
          'Once you start, the test timer cannot be paused. Continue?',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14.sp, height: 1.45, color: Colors.black87),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            height: 46.h,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26.r)),
              ),
              child: Text('YES',
                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700)),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('No, may be later',
                  style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: _kPrimary)),
            ),
          ),
        ],
      ),
    );

    if (go != true || !context.mounted) return;

    // pushReplacement: coming back from the paper should land on the tests
    // list, not on the instructions for a test already under way.
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => TestAttemptScreen(test: test)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: Icon(Icons.arrow_back_rounded, size: 24.sp, color: Colors.black87),
        ),
        title: Text(test.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 16.sp, fontWeight: FontWeight.w700, color: Colors.black87)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 16.h),
              children: [
                Center(
                  child: Text('Instructions',
                      style: TextStyle(
                          fontSize: 21.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87)),
                ),
                SizedBox(height: 18.h),
                // The three numbers a student weighs before committing, up
                // front rather than buried in the prose below.
                Row(
                  children: [
                    Expanded(
                        child: _Fact(
                            icon: Icons.timer_outlined,
                            value: '${test.durationMinutes}',
                            label: 'minutes')),
                    Expanded(
                        child: _Fact(
                            icon: Icons.help_outline_rounded,
                            value: '${test.totalQuestions}',
                            label: 'questions')),
                    Expanded(
                      child: _Fact(
                        icon: test.hasNegativeMarking
                            ? Icons.remove_circle_outline_rounded
                            : Icons.check_circle_outline_rounded,
                        value: test.hasNegativeMarking
                            ? '${test.marksIncorrect}'
                            : '0',
                        label: 'per wrong',
                        danger: test.hasNegativeMarking,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24.h),
                for (var i = 0; i < _rules.length; i++) ...[
                  _Rule(number: i + 1, text: _rules[i]),
                  SizedBox(height: 18.h),
                ],
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 24.h),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 50.h,
                  child: ElevatedButton(
                    onPressed: () => _start(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28.r)),
                    ),
                    child: Text('Yes, continue',
                        style:
                            TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700)),
                  ),
                ),
                SizedBox(height: 6.h),
                TextButton(
                  onPressed: () => Navigator.maybePop(context),
                  child: Text('No, exit',
                      style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: _kPrimary)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final bool danger;

  const _Fact({
    required this.icon,
    required this.value,
    required this.label,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? Colors.red.shade700 : _kPrimary;

    return Column(
      children: [
        Icon(icon, size: 20.sp, color: color),
        SizedBox(height: 6.h),
        Text(value,
            style: TextStyle(
                fontSize: 17.sp, fontWeight: FontWeight.w800, color: color)),
        Text(label,
            style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600)),
      ],
    );
  }
}

class _Rule extends StatelessWidget {
  final int number;
  final String text;

  const _Rule({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 22.w,
          child: Text('$number.',
              style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800)),
        ),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: 14.sp, height: 1.45, color: Colors.grey.shade800)),
        ),
      ],
    );
  }
}
