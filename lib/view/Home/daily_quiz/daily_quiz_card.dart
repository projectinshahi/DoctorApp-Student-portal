// lib/view/Home/daily_quiz/daily_quiz_card.dart
//
// MCQ of the Day, answerable from the home screen.
//
// The one hard rule: `GET /daily-quiz` **starts** the day's attempt, so the
// home screen must never call it on its own. A student who merely opened the
// app would otherwise end the day with an unfinished quiz and a broken
// streak.
//
// So the card works in two phases:
//
//  * `notStarted` — renders from the summary alone. No question is fetched,
//    because fetching one would be starting. Tapping is the student choosing
//    to start, and only then does the set load.
//
//  * `inProgress` / `completed` — the attempt already exists, so fetching is
//    free of side effects and the question is loaded straight away. This is
//    what puts the question and its revealed answer back on the card for the
//    rest of the day.
//
// The reveal survives closing the app because the server keeps it: today's
// set replays its own `answers`, so the explanation is still there tomorrow
// morning — right up until the set rolls at midnight Gulf time.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../models/daily_quiz_model.dart';
import '../../../repository/daily_quiz_provider.dart';
import '../../../services/daily_quiz_service.dart';
import '../../../widget/app_loading.dart';
import 'daily_quiz_screen.dart';

const Color _kPrimary = Color(0xFF87986B);
const Color _kBg = Color(0xFFEFF4E2);
const Color _kRed = Color(0xFFD65745);
const Color _kAmber = Color(0xFFE8A33D);

class DailyQuizCard extends StatefulWidget {
  final DailyQuizSummary summary;
  final int courseId;

  /// Called after anything that moves the day on, so the home screen can
  /// refresh its summary.
  final VoidCallback onChanged;

  /// Injected in tests. The card owns its provider — creating one is what
  /// starts the day — so this is the only seam a test can reach through.
  final DailyQuizService? service;

  const DailyQuizCard({
    super.key,
    required this.summary,
    required this.courseId,
    required this.onChanged,
    this.service,
  });

  @override
  State<DailyQuizCard> createState() => _DailyQuizCardState();
}

class _DailyQuizCardState extends State<DailyQuizCard> {
  DailyQuizProvider? _quiz;

  @override
  void initState() {
    super.initState();

    // The question is shown straight away, on every state.
    //
    // Note what this costs: `GET /daily-quiz` is what *creates* the day's
    // attempt, so simply opening the app now starts today's quiz. A student
    // who never answers ends the day with an attempt begun and unfinished,
    // which stops the streak extending. The card used to gate this behind a
    // "Start today's set" button for exactly that reason.
    //
    // Showing the question is what was asked for, and it is the better card.
    // If unfinished days start eating streaks, the fix is server-side: treat
    // an attempt with zero answers as never started.
    _open();
  }

  @override
  void dispose() {
    _quiz?.dispose();
    super.dispose();
  }

  void _open() {
    if (_quiz != null) return;
    final provider =
        DailyQuizProvider(courseId: widget.courseId, service: widget.service);
    setState(() => _quiz = provider);

    // The spinner ends when the response lands — no timer.
    provider.load().then((_) {
      if (mounted) widget.onChanged();
    });
  }

  Future<void> _answer(DailyQuizQuestion question, int optionId) async {
    await _quiz?.answer(question.id, optionId);
    if (mounted) widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final quiz = _quiz;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(summary: widget.summary, quiz: quiz),
          SizedBox(height: 14.h),
          if (quiz == null)
            AppLoading(height: 180.h)
          else
            // _Body shows the spinner while quiz.isLoading, so it stays up
            // until the response lands and not a millisecond longer.
            ListenableBuilder(
              listenable: quiz,
              builder: (context, _) => _Body(
                quiz: quiz,
                courseId: widget.courseId,
                onAnswer: _answer,
                onChanged: widget.onChanged,
              ),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final DailyQuizSummary summary;
  final DailyQuizProvider? quiz;

  const _Header({required this.summary, required this.quiz});

  @override
  Widget build(BuildContext context) {
    // The live one once the set is open, otherwise the summary's.
    final streak = quiz?.currentStreak ?? summary.currentStreak;

    return Row(
      children: [
        Icon(Icons.today_rounded, size: 18.sp, color: _kPrimary),
        SizedBox(width: 7.w),
        Expanded(
          child: Text('Today\'s MCQ',
              style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87)),
        ),
        if (streak > 0) ...[
          Icon(Icons.local_fire_department_rounded, size: 15.sp, color: _kAmber),
          SizedBox(width: 3.w),
          // Never rendered as lost: it counts back from yesterday until
          // today is done, so an unfinished today is still a live streak.
          Text('$streak',
              style: TextStyle(
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w800,
                  color: _kAmber)),
        ],
      ],
    );
  }
}

class _Body extends StatelessWidget {
  final DailyQuizProvider quiz;
  final int courseId;
  final Future<void> Function(DailyQuizQuestion, int) onAnswer;
  final VoidCallback onChanged;

  const _Body({
    required this.quiz,
    required this.courseId,
    required this.onAnswer,
    required this.onChanged,
  });

  Future<void> _openFull(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DailyQuizScreen(courseId: courseId)),
    );
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    if (quiz.isLoading) {
      return AppLoading(height: 180.h);
    }

    if (quiz.failure != null) {
      return Text(quiz.failure!.message,
          style: TextStyle(fontSize: 12.5.sp, color: Colors.grey.shade700));
    }

    final set = quiz.set;
    // A course with an empty bank. A real state, shown as the server words
    // it rather than as an error.
    if (set != null && !set.available) {
      return Text(set.reason ?? 'No questions are set up for this course yet.',
          style: TextStyle(fontSize: 12.5.sp, color: Colors.grey.shade700));
    }

    // Always the first question of today's set, never `quiz.current`.
    //
    // One question per day on the home screen, and the *same* one all day:
    // it must not advance when answered, or the explanation the student just
    // read would slide away and be replaced by a fresh question. The set is
    // frozen by (courseId, date) server-side, so this is stable until
    // midnight Gulf time and then changes on its own.
    final question = quiz.questions.isEmpty ? null : quiz.questions.first;
    if (question == null) {
      return Text('Today\'s set is empty.',
          style: TextStyle(fontSize: 12.5.sp, color: Colors.grey.shade700));
    }

    final answer = quiz.answerFor(question.id);
    final revealed = answer != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // No "Question 2 of 10" and no counter: there is one question here,
        // and a position out of ten only invites looking for the other nine.
        Row(
          children: [
            Icon(Icons.event_available_rounded,
                size: 13.sp, color: Colors.grey.shade600),
            SizedBox(width: 5.w),
            Text(
              revealed ? 'Answered — new question tomorrow' : 'Today\'s question',
              style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        if (question.questionText != null && question.questionText!.isNotEmpty)
          Text(question.questionText!,
              style: TextStyle(
                  fontSize: 14.sp,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87)),
        SizedBox(height: 18.h),
        for (var i = 0; i < question.options.length; i++) ...[
          _Option(
            letter: String.fromCharCode(65 + i),
            option: question.options[i],
            // One shot: re-answering is a 409, and being able to change your
            // mind after reading the explanation would make the score
            // meaningless.
            enabled: !revealed && !quiz.isSubmitting,
            selectedId: answer?.selectedOptionId,
            correctId: answer?.correctOptionId,
            revealed: revealed,
            onTap: () => onAnswer(question, question.options[i].id),
          ),
          SizedBox(height: 11.h),
        ],
        if (revealed) ...[
          SizedBox(height: 4.h),
          _Reveal(answer: answer),
        ],
        // Nothing to navigate to. The other nine questions live in the full
        // set; this card is one question a day, answered once.
        if (revealed) ...[
          SizedBox(height: 12.h),
          Center(
            child: _TextAction(
              label: 'Practise the full set',
              strong: true,
              onTap: () => _openFull(context),
            ),
          ),
        ],
      ],
    );
  }
}

/// The mockup's option row: a lettered circle and the text, on a soft pill.
class _Option extends StatelessWidget {
  final String letter;
  final DailyQuizOption option;
  final bool enabled;
  final int? selectedId;
  final int? correctId;
  final bool revealed;
  final VoidCallback onTap;

  const _Option({
    required this.letter,
    required this.option,
    required this.enabled,
    required this.selectedId,
    required this.correctId,
    required this.revealed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCorrect = revealed && option.id == correctId;
    final isWrongPick =
        revealed && option.id == selectedId && option.id != correctId;

    final accent = isCorrect
        ? _kPrimary
        : isWrongPick
            ? _kRed
            : null;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 13.w, vertical: 13.h),
        decoration: BoxDecoration(
          color: accent == null ? Colors.white : accent.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(28.r),
          border: Border.all(
            // Hairline until answered, then the verdict colour.
            color: accent ?? const Color(0xFFE6E6E6),
            width: accent == null ? 1 : 1.4,
          ),
          boxShadow: accent == null
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 26.w,
              height: 26.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent ?? const Color(0xFFF1F1F1),
                border: accent == null
                    ? Border.all(color: const Color(0xFFDFDFDF))
                    : null,
              ),
              child: Text(letter,
                  style: TextStyle(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w600,
                      color: accent == null ? Colors.grey.shade700 : Colors.white)),
            ),
            SizedBox(width: 11.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (option.optionText != null && option.optionText!.isNotEmpty)
                    Text(option.optionText!,
                        style: TextStyle(
                            fontSize: 13.sp,
                            height: 1.35,
                            color: Colors.black87)),
                  // An option can be an image with no words at all.
                  if (option.optionImageUrl != null) ...[
                    if (option.optionText != null &&
                        option.optionText!.isNotEmpty)
                      SizedBox(height: 6.h),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8.r),
                      child: Image.network(option.optionImageUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (context, _, __) => const SizedBox.shrink()),
                    ),
                  ],
                ],
              ),
            ),
            if (isCorrect)
              Icon(Icons.check_circle_rounded, size: 17.sp, color: _kPrimary)
            else if (isWrongPick)
              Icon(Icons.cancel_rounded, size: 17.sp, color: _kRed),
          ],
        ),
      ),
    );
  }
}

/// Verdict and explanation. Stays on the card for the rest of the day,
/// because the server replays the answer with tomorrow's set never arriving
/// until midnight Gulf time.
class _Reveal extends StatelessWidget {
  final DailyQuizAnswer answer;

  const _Reveal({required this.answer});

  @override
  Widget build(BuildContext context) {
    final color = answer.isCorrect ? _kPrimary : _kRed;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(13.w),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                  answer.isCorrect
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  size: 16.sp,
                  color: color),
              SizedBox(width: 6.w),
              Text(answer.isCorrect ? 'Correct' : 'Incorrect',
                  style: TextStyle(
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w700,
                      color: color)),
              const Spacer(),
              Text(
                // Negative marks print as sent — never "--0.5".
                answer.marksAwarded > 0
                    ? '+${answer.marksAwarded}'
                    : '${answer.marksAwarded}',
                style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: answer.marksAwarded > 0
                        ? _kPrimary
                        : answer.marksAwarded < 0
                            ? _kRed
                            : Colors.grey.shade600),
              ),
            ],
          ),
          if (answer.explanation != null && answer.explanation!.isNotEmpty) ...[
            SizedBox(height: 9.h),
            Text(answer.explanation!,
                style: TextStyle(
                    fontSize: 12.sp, height: 1.45, color: Colors.grey.shade800)),
          ],
        ],
      ),
    );
  }
}

class _TextAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool strong;

  const _TextAction({
    required this.label,
    required this.onTap,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 8.w),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12.5.sp,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
              color: strong ? _kPrimary : Colors.grey.shade700)),
    );
  }
}
