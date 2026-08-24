// lib/view/Home/Qbank/quiz_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../core/constant/local_storage.dart';
import '../../../models/quiz_model.dart';
import '../../../repository/quiz_provider.dart';
import '../../subjectSelection/select_exam_screen.dart';

const Color _kPrimary = Color(0xFF87986B);
const Color _kBg = Color(0xFFEFF4E2);

class QuizScreen extends StatelessWidget {
  final int lessonId;
  final String lessonTitle;

  const QuizScreen({
    super.key,
    required this.lessonId,
    required this.lessonTitle,
  });

  @override
  Widget build(BuildContext context) {
    // Provider is scoped to this route: questions are never cached across
    // sessions, and a re-open always refetches.
    return ChangeNotifierProvider<QuizProvider>(
      create: (_) => QuizProvider()..load(lessonId),
      child: _QuizView(lessonId: lessonId, lessonTitle: lessonTitle),
    );
  }
}

class _QuizView extends StatelessWidget {
  final int lessonId;
  final String lessonTitle;

  const _QuizView({required this.lessonId, required this.lessonTitle});

  @override
  Widget build(BuildContext context) {
    return Consumer<QuizProvider>(
      builder: (context, provider, _) {
        final quizTitle = provider.questions?.quiz?.title ?? lessonTitle;
        final appBarTitle = provider.finished ? "Result" : quizTitle;

        // Leaving mid-attempt loses nothing (every submitted answer is saved)
        // but it still needs confirming, so nobody drops out by accident.
        final guardExit = !provider.finished &&
            !provider.isLoading &&
            provider.failure == null &&
            provider.visibleQuestions.isNotEmpty;

        return PopScope(
          canPop: !guardExit,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final leave = await _confirmExit(context, provider);
            if (leave && context.mounted) Navigator.pop(context);
          },
          child: Scaffold(
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
                appBarTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w700, color: Colors.black),
              ),
            ),
            body: _body(context, provider),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, QuizProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator(color: _kPrimary));
    }

    if (provider.failure != null) {
      return _FailureView(
        failure: provider.failure!,
        onRetry: () => provider.load(lessonId),
      );
    }

    final questions = provider.questions;
    if (questions == null || questions.questions.isEmpty) {
      return const _EmptyState(
        icon: Icons.quiz_outlined,
        title: "No questions yet",
        message: "This quiz doesn't have any questions right now.",
      );
    }

    if (provider.finished) return _ReviewView(questions: questions);

    // Resumed an attempt where everything was already submitted.
    if (provider.visibleQuestions.isEmpty) {
      return _EmptyState(
        icon: Icons.task_alt_rounded,
        title: "All questions answered",
        message: "You've already submitted every question in this quiz.",
        actionLabel: "See result",
        onAction: provider.finish,
      );
    }

    return _QuestionView(questions: questions);
  }
}

/// "Exit the quiz?" — returns true when the student confirms.
Future<bool> _confirmExit(BuildContext context, QuizProvider provider) async {
  final answered = provider.attemptedCount;
  final left = provider.visibleQuestions
      .where((q) => !provider.isSubmitted(q.id))
      .length;

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      title: Text(
        "Exit the quiz?",
        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: Colors.black87),
      ),
      content: Text(
        "You've submitted $answered answer${answered == 1 ? '' : 's'}. "
        "$left question${left == 1 ? '' : 's'} left — they'll be waiting for you "
        "when you come back.",
        style: TextStyle(fontSize: 13.sp, height: 1.45, color: Colors.grey.shade800),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text("Keep going", style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade700)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kPrimary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
          ),
          child: Text("Exit", style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
  return result ?? false;
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700, color: _kPrimary),
            ),
            SizedBox(height: 2.h),
            Text(label, style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// One question at a time. Answer → Submit → the answer key and the
// explanation are revealed, and the question locks.
// ─────────────────────────────────────────────────────────────
class _QuestionView extends StatelessWidget {
  final QuizQuestionsModel questions;

  const _QuestionView({required this.questions});

  Future<void> _submitQuiz(BuildContext context, QuizProvider provider) async {
    final unanswered = provider.allQuestions.length - provider.attemptedCount;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Text(
          "Submit the quiz?",
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: Colors.black87),
        ),
        content: Text(
          unanswered == 0
              ? "You've answered every question."
              : "$unanswered question${unanswered == 1 ? '' : 's'} left unanswered. "
                  "They'll be counted as skipped.",
          style: TextStyle(fontSize: 13.sp, height: 1.45, color: Colors.grey.shade800),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Cancel", style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
            ),
            child: Text("Submit", style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true) await provider.finish();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<QuizProvider>();
    final question = provider.currentQuestion!;
    final visible = provider.visibleQuestions;
    final total = visible.length;

    final selectedOptionId = provider.selectedOption(question.id);
    final submitted = provider.isSubmitted(question.id);
    final correctOption = question.correctOption;

    // Primary button: Submit the answer → Next → Submit Quiz on the last one.
    final String primaryLabel;
    final VoidCallback? onPrimary;
    if (!submitted && selectedOptionId != null) {
      primaryLabel = "Submit";
      onPrimary = provider.submitCurrent;
    } else if (provider.isLastQuestion) {
      primaryLabel = "Submit Quiz";
      onPrimary = () => _submitQuiz(context, provider);
    } else {
      primaryLabel = submitted ? "Next" : "Skip";
      onPrimary = provider.next;
    }

    return Column(
      children: [
        // ── Progress ──
        Padding(
          padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "${provider.currentIndex + 1} of $total",
                    style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                  ),
                  Text(
                    "Attempted ${provider.attemptedCount}/${provider.allQuestions.length}",
                    style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: _kPrimary),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              ClipRRect(
                borderRadius: BorderRadius.circular(10.r),
                child: LinearProgressIndicator(
                  value: (provider.currentIndex + 1) / total,
                  minHeight: 5.h,
                  backgroundColor: Colors.white,
                  valueColor: const AlwaysStoppedAnimation<Color>(_kPrimary),
                ),
              ),
              if (provider.isResumed) ...[
                SizedBox(height: 10.h),
                Row(
                  children: [
                    Icon(Icons.history_rounded, size: 14.sp, color: Colors.grey.shade600),
                    SizedBox(width: 6.w),
                    Expanded(
                      child: Text(
                        "Continuing where you left off — "
                        "${provider.carriedOverCount} already answered.",
                        style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 20.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Images are usually null — nothing is reserved for them.
                if (question.questionImageUrl != null && question.questionImageUrl!.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14.r),
                    child: Image.network(question.questionImageUrl!, fit: BoxFit.cover),
                  ),
                  SizedBox(height: 14.h),
                ],

                Text(
                  question.questionText,
                  style: TextStyle(fontSize: 14.5.sp, height: 1.5, color: Colors.black87),
                ),

                SizedBox(height: 10.h),
                Row(
                  children: [
                    _MarkPill(text: "+${_trimNumber(question.marksCorrect)}", color: _kPrimary),
                    if (question.marksIncorrect != 0) ...[
                      SizedBox(width: 8.w),
                      // A genuine negative — printed as sent, never absolute.
                      _MarkPill(text: _trimNumber(question.marksIncorrect), color: Colors.orange.shade800),
                    ],
                    if (question.difficulty != null && question.difficulty!.isNotEmpty) ...[
                      const Spacer(),
                      Text(
                        question.difficulty!.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),

                SizedBox(height: 18.h),

                ...List.generate(question.options.length, (i) {
                  final option = question.options[i];
                  final isSelected = selectedOptionId == option.id;

                  // Only after submitting does the tile know right from wrong,
                  // and only when the API actually sent the answer key.
                  bool? verdict;
                  if (submitted && correctOption != null) {
                    if (option.id == correctOption.id) {
                      verdict = true;
                    } else if (isSelected) {
                      verdict = false;
                    }
                  }

                  return Padding(
                    padding: EdgeInsets.only(bottom: 12.h),
                    child: _OptionTile(
                      letter: String.fromCharCode(65 + i), // A, B, C, D …
                      option: option,
                      isSelected: isSelected,
                      locked: submitted,
                      verdict: verdict,
                      onTap: () => context.read<QuizProvider>().select(question.id, option.id),
                    ),
                  );
                }),

                if (submitted) ...[
                  SizedBox(height: 4.h),
                  _FeedbackCard(
                    question: question,
                    isCorrect: provider.resultFor(question),
                  ),
                ],
              ],
            ),
          ),
        ),

        // ── Previous / Submit / Next ──
        Padding(
          padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
          child: Row(
            children: [
              if (provider.currentIndex > 0) ...[
                Expanded(
                  child: SizedBox(
                    height: 50.h,
                    child: OutlinedButton(
                      onPressed: provider.previous,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kPrimary,
                        side: const BorderSide(color: _kPrimary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.r)),
                      ),
                      child: Text("Previous", style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
              ],
              Expanded(
                child: SizedBox(
                  height: 50.h,
                  child: ElevatedButton(
                    onPressed: onPrimary,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.r)),
                    ),
                    child: Text(primaryLabel, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shown once a question is submitted: right/wrong, the correct answer when
/// the student missed it, and the explanation.
class _FeedbackCard extends StatelessWidget {
  final QuizQuestionModel question;
  final bool? isCorrect;

  const _FeedbackCard({required this.question, required this.isCorrect});

  @override
  Widget build(BuildContext context) {
    final correct = question.correctOption;
    final explanation = question.explanation;

    // No answer key from the API — say so instead of implying a result.
    if (correct == null) {
      return _FeedbackShell(
        color: Colors.grey.shade600,
        icon: Icons.info_outline_rounded,
        title: "Answer recorded",
        children: [
          Text(
            "The correct answer isn't sent to the app for this quiz, so it "
            "can't be shown here.",
            style: TextStyle(fontSize: 12.sp, height: 1.45, color: Colors.grey.shade800),
          ),
        ],
      );
    }

    final right = isCorrect == true;
    final color = right ? _kPrimary : Colors.red.shade600;

    return _FeedbackShell(
      color: color,
      icon: right ? Icons.check_circle_rounded : Icons.cancel_rounded,
      title: right ? "Correct" : "Incorrect",
      children: [
        if (!right) ...[
          Text(
            "Correct answer",
            style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, color: Colors.grey.shade600),
          ),
          SizedBox(height: 4.h),
          Text(
            correct.optionText,
            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: _kPrimary, height: 1.4),
          ),
          SizedBox(height: 12.h),
        ],
        if (explanation != null && explanation.trim().isNotEmpty) ...[
          Text(
            "Explanation",
            style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, color: Colors.grey.shade600),
          ),
          SizedBox(height: 4.h),
          Text(
            explanation.trim(),
            style: TextStyle(fontSize: 12.5.sp, height: 1.5, color: Colors.black87),
          ),
        ],
      ],
    );
  }
}

class _FeedbackShell extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final List<Widget> children;

  const _FeedbackShell({
    required this.color,
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18.sp, color: color),
              SizedBox(width: 8.w),
              Text(
                title,
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
          if (children.isNotEmpty) SizedBox(height: 12.h),
          ...children,
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String letter;
  final QuizOptionModel option;
  final bool isSelected;

  /// Answer submitted — no more taps.
  final bool locked;

  /// true = this is the correct option, false = the wrong one the student
  /// picked, null = neutral (or the answer key wasn't sent).
  final bool? verdict;

  final VoidCallback onTap;

  const _OptionTile({
    required this.letter,
    required this.option,
    required this.isSelected,
    required this.onTap,
    this.locked = false,
    this.verdict,
  });

  @override
  Widget build(BuildContext context) {
    final Color accent;
    if (verdict == true) {
      accent = _kPrimary;
    } else if (verdict == false) {
      accent = Colors.red.shade600;
    } else {
      accent = _kPrimary;
    }

    final highlighted = isSelected || verdict != null;

    return GestureDetector(
      onTap: locked ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: highlighted ? accent.withOpacity(0.14) : Colors.white,
          borderRadius: BorderRadius.circular(30.r),
          border: Border.all(
            color: highlighted ? accent : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 26.w,
              height: 26.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: highlighted ? accent : _kBg,
                shape: BoxShape.circle,
              ),
              child: Text(
                letter,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: highlighted ? Colors.white : Colors.black87,
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.optionText,
                    style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500, color: Colors.black87),
                  ),
                  if (option.optionImageUrl != null && option.optionImageUrl!.isNotEmpty) ...[
                    SizedBox(height: 8.h),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10.r),
                      child: Image.network(option.optionImageUrl!, fit: BoxFit.cover),
                    ),
                  ],
                ],
              ),
            ),
            if (verdict != null) ...[
              SizedBox(width: 8.w),
              Icon(
                verdict! ? Icons.check_circle_rounded : Icons.cancel_rounded,
                size: 18.sp,
                color: accent,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MarkPill extends StatelessWidget {
  final String text;
  final Color color;

  const _MarkPill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Text(
        "$text marks",
        style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Result — shown after the final Submit. The same totals are printed
// to the terminal by QuizProvider.printScore().
// ─────────────────────────────────────────────────────────────
class _ReviewView extends StatelessWidget {
  final QuizQuestionsModel questions;

  const _ReviewView({required this.questions});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<QuizProvider>();
    final scored = provider.hasAnswerKey;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 20.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (scored) ...[
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 20.h),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Column(
                      children: [
                        Text(
                          "Total marks",
                          style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade700),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          "${_trimNumber(provider.scoredMarks)} / ${_trimNumber(questions.totalMarks)}",
                          style: TextStyle(fontSize: 30.sp, fontWeight: FontWeight.w800, color: _kPrimary),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      _StatChip(label: "Correct", value: "${provider.correctCount}"),
                      SizedBox(width: 12.w),
                      _StatChip(label: "Wrong", value: "${provider.wrongCount}"),
                    ],
                  ),
                  SizedBox(height: 12.h),
                ],

                Row(
                  children: [
                    _StatChip(label: "Attempted", value: "${provider.attemptedCount}"),
                    SizedBox(width: 12.w),
                    _StatChip(label: "Skipped", value: "${provider.skippedCount}"),
                  ],
                ),
                SizedBox(height: 16.h),

                if (!scored)
                  // Honest about the boundary — no score, no pass/fail.
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, size: 18.sp, color: Colors.orange),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Text(
                            "Marks aren't available. This quiz's correct answers and "
                            "explanations weren't sent to the app, so it can't score them.",
                            style: TextStyle(fontSize: 12.sp, height: 1.45, color: Colors.grey.shade800),
                          ),
                        ),
                      ],
                    ),
                  ),

                SizedBox(height: 20.h),
                Text(
                  "Your answers",
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: Colors.black87),
                ),
                SizedBox(height: 12.h),

                ...List.generate(provider.allQuestions.length, (index) {
                  final question = provider.allQuestions[index];
                  final selectedId = provider.selectedOption(question.id);
                  final selected = selectedId == null
                      ? null
                      : question.options.where((o) => o.id == selectedId).firstOrNull;
                  final verdict = provider.resultFor(question);

                  // Only questions still in this attempt can be jumped back to.
                  final visibleIndex =
                      provider.visibleQuestions.indexWhere((q) => q.id == question.id);

                  final Color answerColor;
                  if (selected == null) {
                    answerColor = Colors.orange.shade800;
                  } else if (verdict == null) {
                    answerColor = _kPrimary;
                  } else {
                    answerColor = verdict ? _kPrimary : Colors.red.shade600;
                  }

                  return Padding(
                    padding: EdgeInsets.only(bottom: 12.h),
                    child: GestureDetector(
                      onTap: visibleIndex < 0 ? null : () => provider.goTo(visibleIndex),
                      child: Container(
                        padding: EdgeInsets.all(14.w),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 26.w,
                              height: 26.w,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(color: _kBg, shape: BoxShape.circle),
                              child: Text(
                                "${index + 1}",
                                style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, color: _kPrimary),
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    question.questionText,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w600, height: 1.35),
                                  ),
                                  SizedBox(height: 6.h),
                                  Text(
                                    selected == null ? "Skipped" : selected.optionText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.5.sp,
                                      color: answerColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (verdict != null)
                              Icon(
                                verdict ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                size: 18.sp,
                                color: verdict ? _kPrimary : Colors.red.shade600,
                              )
                            else
                              Icon(Icons.chevron_right_rounded, size: 20.sp, color: Colors.grey.shade400),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        Padding(
          padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50.h,
                  child: OutlinedButton(
                    onPressed: provider.retakeFromStart,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kPrimary,
                      side: const BorderSide(color: _kPrimary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.r)),
                    ),
                    child: Text("Retake", style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: SizedBox(
                  height: 50.h,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.r)),
                    ),
                    child: Text("Done", style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Failure states — one screen per kind
// ─────────────────────────────────────────────────────────────
class _FailureView extends StatelessWidget {
  final QuizException failure;
  final VoidCallback onRetry;

  const _FailureView({required this.failure, required this.onRetry});

  Future<void> _openCourseSelection(BuildContext context) async {
    final accessToken = await LocalStorage.getAccessToken() ?? '';
    final refreshToken = await LocalStorage.getRefreshToken() ?? '';
    final deviceId = await LocalStorage.getDeviceId();

    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExamSelectionScreen(
          accessToken: accessToken,
          refreshToken: refreshToken,
          deviceId: deviceId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (failure.kind) {
      case QuizErrorKind.locked:
        return _PaywallView(failure: failure);

      case QuizErrorKind.noCourseSelected:
        return _EmptyState(
          icon: Icons.school_outlined,
          title: "Choose your exam first",
          message: failure.message.isEmpty
              ? "Select a course before opening a lesson."
              : failure.message,
          actionLabel: "Select a course",
          onAction: () => _openCourseSelection(context),
        );

      case QuizErrorKind.lessonNotFound:
        return _EmptyState(
          icon: Icons.search_off_rounded,
          title: "Lesson not found",
          message: "This lesson isn't published, or the link is out of date.",
          actionLabel: "Go back",
          onAction: () => Navigator.maybePop(context),
        );

      case QuizErrorKind.notInCourse:
        return _EmptyState(
          icon: Icons.block_outlined,
          title: "Not in your course",
          message: "This lesson is not part of your selected course.",
          actionLabel: "Go back",
          onAction: () => Navigator.maybePop(context),
        );

      case QuizErrorKind.noQuizLinked:
        return const _EmptyState(
          icon: Icons.quiz_outlined,
          title: "No MCQs here yet",
          message: "This lesson doesn't have a quiz linked to it.",
        );

      case QuizErrorKind.quizInactive:
        return const _EmptyState(
          icon: Icons.pause_circle_outline_rounded,
          title: "Not available right now",
          message: "This quiz has been paused. Please check back later.",
        );

      case QuizErrorKind.sessionExpired:
        return _EmptyState(
          icon: Icons.lock_clock_outlined,
          title: "Session ended",
          message: failure.message.isEmpty ? "Please log in again." : failure.message,
          actionLabel: "Go back",
          onAction: () => Navigator.maybePop(context),
        );

      case QuizErrorKind.serverError:
        return _EmptyState(
          icon: Icons.cloud_off_rounded,
          title: "Server couldn't load this quiz",
          message: failure.message.isEmpty
              ? "The questions are there, but the server failed to return them. "
                  "This isn't your connection — try again in a moment."
              : "${failure.message}\n\nThis is a server error, not your connection.",
          actionLabel: "Retry",
          onAction: onRetry,
        );

      case QuizErrorKind.network:
        return _EmptyState(
          icon: Icons.wifi_off_rounded,
          title: "Couldn't load the quiz",
          message: failure.message,
          actionLabel: "Retry",
          onAction: onRetry,
        );
    }
  }
}

/// 403 + requiredPlans — the plans arrive with the error, so no second call.
class _PaywallView extends StatelessWidget {
  final QuizException failure;

  const _PaywallView({required this.failure});

  @override
  Widget build(BuildContext context) {
    final plans = failure.requiredPlans;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 64.w,
              height: 64.w,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: Icon(Icons.lock_outline_rounded, size: 28.sp, color: _kPrimary),
            ),
          ),
          SizedBox(height: 16.h),
          Center(
            child: Text(
              "This quiz is locked",
              style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w700, color: Colors.black87),
            ),
          ),
          SizedBox(height: 6.h),
          Center(
            child: Text(
              failure.message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5.sp, color: Colors.grey.shade700, height: 1.4),
            ),
          ),
          SizedBox(height: 24.h),

          if (plans.isEmpty)
            Text(
              "Subscribe to unlock it.",
              style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade700),
            )
          else ...[
            Text(
              "Plans that unlock it",
              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: Colors.black87),
            ),
            SizedBox(height: 12.h),
            ...plans.map(
              (plan) => Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plan.title,
                              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: Colors.black87),
                            ),
                            if (plan.description != null && plan.description!.isNotEmpty) ...[
                              SizedBox(height: 4.h),
                              Text(
                                plan.description!,
                                style: TextStyle(fontSize: 11.5.sp, color: Colors.grey.shade600),
                              ),
                            ],
                            if (plan.durationDays > 0) ...[
                              SizedBox(height: 4.h),
                              Text(
                                "${plan.durationDays} days",
                                style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        _trimNumber(plan.price),
                        style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: _kPrimary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64.w,
              height: 64.w,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: Icon(icon, size: 28.sp, color: _kPrimary),
            ),
            SizedBox(height: 16.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: Colors.black87),
            ),
            SizedBox(height: 8.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5.sp, color: Colors.grey.shade700, height: 1.45),
            ),
            if (actionLabel != null) ...[
              SizedBox(height: 20.h),
              SizedBox(
                height: 46.h,
                child: ElevatedButton(
                  onPressed: onAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(horizontal: 28.w),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.r)),
                  ),
                  child: Text(actionLabel!, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 2.0 -> "2", -0.5 -> "-0.5". Never touches the sign.
String _trimNumber(double value) {
  final text = value.toStringAsFixed(2);
  return text.replaceFirst(RegExp(r'\.?0+$'), '');
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
