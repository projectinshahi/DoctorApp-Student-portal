// lib/view/Home/Qbank/quiz_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../core/constant/local_storage.dart';
import '../../../models/quiz_model.dart';
import '../../../repository/quiz_provider.dart';
import '../../../repository/saved_provider.dart';
import '../../subjectSelection/select_exam_screen.dart';
import '../../../widget/app_shimmer.dart';
import '../../../widget/pro_plan_dialog.dart';

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
    // Provider is scoped to this route. The attempt lives on the server, so
    // a re-open resumes it rather than replaying anything cached here.
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
        final quizTitle = provider.attempt?.quiz?.title ?? lessonTitle;
        final appBarTitle = provider.finished ? "Result" : quizTitle;

        // Leaving mid-attempt loses nothing — every committed answer is on
        // the server and the attempt resumes — but it still needs confirming
        // so nobody drops out by accident.
        final guardExit = !provider.finished &&
            !provider.isLoading &&
            provider.failure == null &&
            provider.questions.isNotEmpty;

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
      return const ScreenShimmer(layout: ShimmerLayout.quiz);
    }

    if (provider.failure != null) {
      return _FailureView(
        failure: provider.failure!,
        onRetry: () => provider.load(lessonId),
      );
    }

    // First: a finished attempt is read-only, and the completed GET carries
    // no `questions` list — checking for one below would call it empty.
    if (provider.finished && provider.result != null) return const _ReviewView();

    if (provider.attempt == null || provider.questions.isEmpty) {
      return const _EmptyState(
        icon: Icons.quiz_outlined,
        title: "No questions yet",
        message: "This quiz doesn't have any questions right now.",
      );
    }

    return const _QuestionView();
  }
}

/// "Exit the quiz?" — returns true when the student confirms.
Future<bool> _confirmExit(BuildContext context, QuizProvider provider) async {
  final answered = provider.attemptedCount;
  final left = provider.remainingCount;

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
        "You've answered $answered question${answered == 1 ? '' : 's'}. "
        "$left left — the attempt is saved on your account, so it'll be "
        "waiting exactly here when you come back.",
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
  const _QuestionView();

  Future<void> _submitQuiz(BuildContext context, QuizProvider provider) async {
    final unanswered = provider.remainingCount;

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
                  "${unanswered == 1 ? "It'll" : "They'll"} be counted as skipped.",
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
    final total = provider.questions.length;

    final selectedOptionId = provider.selectedOption(question.id);
    final submitted = provider.isAnswered(question.id);

    // Filled the moment this answer is posted — the key comes back with it.
    // Null on a resumed answer: the server withholds the key until finish.
    final outcome = provider.resultFor(question);
    final checking = provider.isChecking(question.id);

    // Answering is the option tap itself, so this button only ever moves the
    // student along: Next / Skip, and Submit Quiz on the last question.
    final String primaryLabel;
    final VoidCallback? onPrimary;
    if (provider.isSubmitting) {
      primaryLabel = "Submitting…";
      onPrimary = null;
    } else if (checking) {
      primaryLabel = "Saving…";
      onPrimary = null;
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
                    "Attempted ${provider.attemptedCount}/${provider.totalQuestions}",
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
                        "${provider.resumedCount} already answered.",
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

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        question.questionText,
                        style: TextStyle(fontSize: 14.5.sp, height: 1.5, color: Colors.black87),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    _SaveButton(questionId: question.id),
                  ],
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

                  // correctOptionId is tested FIRST on purpose: a correct
                  // answer matches both ids, and reversing these two paints
                  // it red. Anything else stays normal — a skipped question
                  // highlights only the correct option.
                  bool? verdict;
                  if (outcome != null) {
                    if (option.id == outcome.correctOptionId) {
                      verdict = true;
                    } else if (option.id == outcome.selectedOptionId) {
                      verdict = false;
                    }
                  }

                  return Padding(
                    padding: EdgeInsets.only(bottom: 12.h),
                    child: _OptionTile(
                      letter: String.fromCharCode(65 + i), // A, B, C, D …
                      option: option,
                      isSelected: isSelected,
                      // Locked once answered, and while a tap is in flight so
                      // a second one can't race it onto the same question.
                      locked: submitted || checking,
                      busy: checking && isSelected,
                      verdict: verdict,
                      onTap: () =>
                          context.read<QuizProvider>().answer(question.id, option.id),
                    ),
                  );
                }),

                if (submitted || outcome != null || checking) ...[
                  SizedBox(height: 4.h),
                  _FeedbackCard(outcome: outcome, isChecking: checking),
                ],
              ],
            ),
          ),
        ),

        if (provider.submitError != null)
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 10.h),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded, size: 16.sp, color: Colors.red.shade600),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    provider.submitError!,
                    style: TextStyle(fontSize: 12.sp, color: Colors.red.shade700),
                  ),
                ),
              ],
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
                    child: (provider.isSubmitting || checking)
                        ? SizedBox(
                            width: 20.w,
                            height: 20.w,
                            child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(primaryLabel, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700)),
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

/// Shown once a question is locked. Before the quiz is submitted there is
/// nothing to reveal — the answer key only arrives with the submit response.
/// After it, three states, never two: correct, wrong, skipped.

class _FeedbackCard extends StatelessWidget {
  final QuizQuestionResult? outcome;
  final bool isChecking;

  const _FeedbackCard({required this.outcome, this.isChecking = false});

  @override
  Widget build(BuildContext context) {
    final result = outcome;

    if (isChecking) {
      return _FeedbackShell(
        color: Colors.grey.shade600,
        icon: Icons.hourglass_top_rounded,
        title: "Saving your answer…",
        children: const [],
      );
    }

    // Answered in an earlier sitting. The server withholds the key for an
    // unfinished attempt, so there is nothing to reveal yet — the answer is
    // recorded and will be scored at the end.
    if (result == null) {
      return _FeedbackShell(
        color: Colors.grey.shade600,
        icon: Icons.lock_outline_rounded,
        title: "Answered earlier",
        children: [
          Text(
            "This one is already recorded. You'll see the answer and the "
            "explanation when you finish the quiz.",
            style: TextStyle(fontSize: 12.sp, height: 1.45, color: Colors.grey.shade800),
          ),
        ],
      );
    }

    final Color color;
    final IconData icon;
    final String title;
    if (result.isCorrect) {
      color = _kPrimary;
      icon = Icons.check_circle_rounded;
      title = "Correct";
    } else if (result.isSkipped) {
      // Skipped is not wrong — no penalty, so no red.
      color = Colors.orange.shade800;
      icon = Icons.remove_circle_outline_rounded;
      title = "Skipped";
    } else {
      color = Colors.red.shade600;
      icon = Icons.cancel_rounded;
      title = "Incorrect";
    }

    final correct = result.correctOption;
    final explanation = result.explanation;

    return _FeedbackShell(
      color: color,
      icon: icon,
      title: title,
      // Marks only where they were earned or lost. A skipped question scores
      // 0 and must not read like a penalty.
      trailing: result.answered
          ? Text(
              "${_trimNumber(result.marksAwarded)} marks",
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: color),
            )
          : null,
      children: [
        // Always shown, right or wrong — the student wants to see the answer
        // confirmed, not just inferred from the green tile.
        if (correct != null) ...[
          Text(
            "Correct answer",
            style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, color: Colors.grey.shade600),
          ),
          SizedBox(height: 4.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check_circle_rounded, size: 15.sp, color: _kPrimary),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  correct.optionText,
                  style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: _kPrimary, height: 1.4),
                ),
              ),
            ],
          ),
          if (explanation != null && explanation.trim().isNotEmpty) SizedBox(height: 12.h),
        ],
        // Nullable on purpose — plenty of questions have none, and no space
        // is reserved for it.
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
  final Widget? trailing;

  const _FeedbackShell({
    required this.color,
    required this.icon,
    required this.title,
    required this.children,
    this.trailing,
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
              if (trailing != null) ...[const Spacer(), trailing!],
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

  /// Answered, or a tap already in flight — no more taps.
  final bool locked;

  /// This option is the one being saved right now.
  final bool busy;

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
    this.busy = false,
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
            if (busy) ...[
              SizedBox(width: 8.w),
              SizedBox(
                width: 18.sp,
                height: 18.sp,
                child: CircularProgressIndicator(strokeWidth: 2, color: accent),
              ),
            ] else if (verdict != null) ...[
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
// Result — every number here comes from the submit response. The app
// never computes a mark; the same totals are printed to the terminal
// by QuizProvider.printScore().
// ─────────────────────────────────────────────────────────────
class _ReviewView extends StatelessWidget {
  const _ReviewView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<QuizProvider>();
    final rows = provider.reviewResults;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 20.h),
            children: [
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
                      // score is genuinely negative when negative marking
                      // bites — printed as sent, never absolute.
                      "${_trimNumber(provider.scoredMarks)} / ${_trimNumber(provider.totalMarks)}",
                      style: TextStyle(
                        fontSize: 30.sp,
                        fontWeight: FontWeight.w800,
                        color: provider.scoredMarks < 0 ? Colors.red.shade600 : _kPrimary,
                      ),
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
                  SizedBox(width: 12.w),
                  _StatChip(label: "Skipped", value: "${provider.skippedCount}"),
                ],
              ),

              SizedBox(height: 20.h),
              Text(
                "Your answers",
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: Colors.black87),
              ),
              SizedBox(height: 12.h),

              // Every question in full — text, all the options marked up, and
              // the explanation. Nothing to tap into: the attempt is over, so
              // a jump-back-into-the-quiz would have nowhere to go.
              ...List.generate(
                rows.length,
                (index) => _ReviewQuestionCard(number: index + 1, outcome: rows[index]),
              ),

              // Past attempts. Self-hides under the one-attempt-per-quiz rule;
              // it only shows for quizzes attempted before that rule existed.
              if (provider.history.length > 1) ...[
                SizedBox(height: 8.h),
                Text(
                  "Past attempts",
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: Colors.black87),
                ),
                SizedBox(height: 12.h),
                ...provider.history.map(
                  (summary) => _HistoryRow(
                    summary: summary,
                    isCurrent: summary.attemptId == provider.attempt?.attemptId,
                  ),
                ),
              ],
            ],
          ),
        ),

        Padding(
          padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
          child: Row(
            children: [
              // No Retake: one attempt per quiz, so this review is final.
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

/// One question in the review: the question, every option marked up, and the
/// correct answer with its explanation. Built from the finish response, which
/// is the only place the answer key exists.
class _ReviewQuestionCard extends StatelessWidget {
  final int number;
  final QuizQuestionResult outcome;

  const _ReviewQuestionCard({required this.number, required this.outcome});

  @override
  Widget build(BuildContext context) {
    final Color headerColor;
    final IconData headerIcon;
    final String headerLabel;
    if (outcome.isCorrect) {
      headerColor = _kPrimary;
      headerIcon = Icons.check_circle_rounded;
      headerLabel = "Correct";
    } else if (outcome.isSkipped) {
      // Skipped is not wrong — no penalty, so no red.
      headerColor = Colors.orange.shade800;
      headerIcon = Icons.remove_circle_outline_rounded;
      headerLabel = "Skipped";
    } else {
      headerColor = Colors.red.shade600;
      headerIcon = Icons.cancel_rounded;
      headerLabel = "Incorrect";
    }

    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24.w,
                height: 24.w,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: _kBg, shape: BoxShape.circle),
                child: Text(
                  "$number",
                  style: TextStyle(fontSize: 10.5.sp, fontWeight: FontWeight.w700, color: _kPrimary),
                ),
              ),
              SizedBox(width: 8.w),
              Icon(headerIcon, size: 16.sp, color: headerColor),
              SizedBox(width: 5.w),
              Text(
                headerLabel,
                style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w700, color: headerColor),
              ),
              const Spacer(),
              // A skipped question scores 0 — printing marks there would read
              // as a penalty.
              if (outcome.answered)
                Text(
                  "${_trimNumber(outcome.marksAwarded)} marks",
                  style: TextStyle(fontSize: 11.5.sp, fontWeight: FontWeight.w700, color: headerColor),
                ),
              SizedBox(width: 4.w),
              _SaveButton(questionId: outcome.questionId, compact: true),
            ],
          ),
          SizedBox(height: 10.h),

          if (outcome.questionImageUrl != null && outcome.questionImageUrl!.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12.r),
              child: Image.network(outcome.questionImageUrl!, fit: BoxFit.cover),
            ),
            SizedBox(height: 10.h),
          ],

          Text(
            outcome.questionText,
            style: TextStyle(fontSize: 13.5.sp, height: 1.5, color: Colors.black87),
          ),
          SizedBox(height: 12.h),

          ...List.generate(outcome.options.length, (i) {
            final option = outcome.options[i];

            // correctOptionId is tested FIRST on purpose: a correct answer
            // matches both ids, and reversing these two paints it red.
            bool? verdict;
            if (option.id == outcome.correctOptionId) {
              verdict = true;
            } else if (option.id == outcome.selectedOptionId) {
              verdict = false;
            }

            return Padding(
              padding: EdgeInsets.only(bottom: 10.h),
              child: _OptionTile(
                letter: String.fromCharCode(65 + i),
                option: option,
                isSelected: option.id == outcome.selectedOptionId,
                locked: true,
                verdict: verdict,
                onTap: () {},
              ),
            );
          }),

          // Nullable on purpose — plenty of questions have none, and no space
          // is reserved for it.
          if (outcome.explanation != null && outcome.explanation!.trim().isNotEmpty) ...[
            SizedBox(height: 2.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: _kBg,
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Explanation",
                    style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, color: Colors.grey.shade700),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    outcome.explanation!.trim(),
                    style: TextStyle(fontSize: 12.5.sp, height: 1.5, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Save-for-later toggle. Writes straight through to /saved-questions via the
/// app-wide provider, so the QBank badge and the saved list stay in step with
/// this icon without either of them refetching.
class _SaveButton extends StatelessWidget {
  final int questionId;
  final bool compact;

  const _SaveButton({required this.questionId, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final saved = context.watch<SavedProvider>().isQuestionSaved(questionId);

    return GestureDetector(
      onTap: () => context.read<SavedProvider>().toggleQuestion(questionId),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.all(compact ? 2.w : 4.w),
        child: Icon(
          saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          size: (compact ? 18 : 22).sp,
          color: saved ? _kPrimary : Colors.grey.shade500,
        ),
      ),
    );
  }
}

/// One row of the attempt history. Summary fields only — the endpoint sends
/// no per-question detail, so there is nothing here to tap into.
class _HistoryRow extends StatelessWidget {
  final QuizAttemptSummary summary;
  final bool isCurrent;

  const _HistoryRow({required this.summary, required this.isCurrent});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: isCurrent ? Border.all(color: _kPrimary, width: 1.4) : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCurrent ? "This attempt" : "Attempt #${summary.attemptId}",
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w700,
                    color: isCurrent ? _kPrimary : Colors.black87,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  summary.completed
                      ? "${summary.correctCount} correct of ${summary.totalQuestions}"
                      : "In progress — ${summary.answeredCount} answered",
                  style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          if (summary.completed)
            Text(
              // Negative scores are real; printed as sent.
              _trimNumber(summary.score),
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w800,
                color: summary.score < 0 ? Colors.red.shade600 : _kPrimary,
              ),
            ),
        ],
      ),
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
        // Same paywall the video player shows — PRO badge, View Plan, Go back.
        // Subscribing reloads the lesson so the questions appear straight away.
        return ProPlanPaywall(
          message: 'This quiz is available for pro users of this course. '
              'Want to check Pro plans?',
          onSubscribed: onRetry,
        );

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

      case QuizErrorKind.noQuestions:
        return const _EmptyState(
          icon: Icons.inbox_rounded,
          title: "No questions yet",
          message: "This quiz is set up but doesn't have any questions in it "
              "so far. Check back soon.",
        );

      case QuizErrorKind.attemptNotFound:
        // Also what another student's attempt id returns — the API answers
        // identically on purpose, so ids can't be probed.
        return _EmptyState(
          icon: Icons.help_outline_rounded,
          title: "Attempt not found",
          message: "That attempt is gone, or it isn't yours. Start a fresh one.",
          actionLabel: "Start again",
          onAction: onRetry,
        );

      case QuizErrorKind.attemptFinished:
        return _EmptyState(
          icon: Icons.done_all_rounded,
          title: "Already finished",
          message: "This attempt has been scored. Start a fresh one to "
              "practise again — you'll get a new set of questions.",
          actionLabel: "Start again",
          onAction: onRetry,
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
