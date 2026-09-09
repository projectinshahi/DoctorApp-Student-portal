// lib/view/Home/daily_quiz/daily_quiz_screen.dart
//
// Today's ten. Opening this screen is what starts the day's attempt — which
// is why the home card never fetches the set, only the summary.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../models/daily_quiz_model.dart';
import '../../../repository/daily_quiz_provider.dart';
import '../../../widget/app_loading.dart';
import 'daily_quiz_result_screen.dart';

const Color _kPrimary = Color(0xFF87986B);
const Color _kBg = Color(0xFFEFF4E2);
const Color _kRed = Color(0xFFD65745);
const Color _kAmber = Color(0xFFE8A33D);

class DailyQuizScreen extends StatelessWidget {
  final int courseId;

  const DailyQuizScreen({super.key, required this.courseId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<DailyQuizProvider>(
      // Creating this is what opens the set. Deliberate: the student tapped
      // the card, which is them choosing to start.
      create: (_) => DailyQuizProvider(courseId: courseId)..load(),
      child: const _QuizView(),
    );
  }
}

class _QuizView extends StatelessWidget {
  const _QuizView();

  Future<void> _finish(BuildContext context, DailyQuizProvider provider) async {
    final skipped = provider.totalQuestions - provider.answeredCount;

    if (skipped > 0) {
      final go = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Finish today\'s quiz?'),
          content: Text(
            '$skipped of ${provider.totalQuestions} questions are unanswered. '
            'A skipped question scores 0 — it is not penalised.',
            style: TextStyle(fontSize: 13.sp, height: 1.4),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Keep going')),
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Finish')),
          ],
        ),
      );
      if (go != true || !context.mounted) return;
    }

    final ok = await provider.finish();
    if (!ok || !context.mounted) return;
    _showResult(context, provider);
  }

  void _showResult(BuildContext context, DailyQuizProvider provider) {
    final result = provider.result;
    if (result == null) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => DailyQuizResultScreen(result: result)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DailyQuizProvider>();

    // Finished — either already done today, or just completed by answering
    // the last one. Either way the sheet is the screen.
    if (!provider.isLoading && provider.result != null && provider.set?.completed == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) _showResult(context, provider);
      });
    }

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: Icon(Icons.chevron_left_rounded, size: 30.sp, color: Colors.black),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('MCQ of the Day',
                style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87)),
            if (provider.set != null)
              Text(provider.set!.date,
                  style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600)),
          ],
        ),
        actions: [
          if (provider.currentStreak > 0)
            Padding(
              padding: EdgeInsets.only(right: 14.w),
              child: Center(
                child: Row(
                  children: [
                    Icon(Icons.local_fire_department_rounded,
                        size: 17.sp, color: _kAmber),
                    SizedBox(width: 3.w),
                    Text('${provider.currentStreak}',
                        style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w800,
                            color: _kAmber)),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: _body(context, provider),
    );
  }

  Widget _body(BuildContext context, DailyQuizProvider provider) {
    if (provider.isLoading) return const AppLoading();

    final failure = provider.failure;
    if (failure != null) return _Message(text: failure.message);

    final set = provider.set;
    // A course whose bank is empty. A real state — show the server's reason
    // rather than a spinner or an error toast.
    if (set != null && !set.available) {
      return _Message(
          text: set.reason ?? 'No questions are set up for this course yet.');
    }

    final question = provider.current;
    if (question == null) {
      return const _Message(text: 'Today\'s set is empty.');
    }

    return Column(
      children: [
        _ProgressStrip(provider: provider),
        Expanded(child: _QuestionBody(question: question, provider: provider)),
        if (provider.actionError != null)
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 8.h),
            child: Text(provider.actionError!,
                style: TextStyle(fontSize: 11.5.sp, color: _kRed)),
          ),
        _Footer(
          provider: provider,
          onFinish: () => _finish(context, provider),
        ),
      ],
    );
  }
}

class _ProgressStrip extends StatelessWidget {
  final DailyQuizProvider provider;

  const _ProgressStrip({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${provider.currentIndex + 1} of ${provider.questions.length}',
                  style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700)),
              Text('${provider.answeredCount}/${provider.totalQuestions} answered',
                  style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: _kPrimary)),
            ],
          ),
          SizedBox(height: 8.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(10.r),
            child: LinearProgressIndicator(
              value: provider.totalQuestions == 0
                  ? 0
                  : provider.answeredCount / provider.totalQuestions,
              minHeight: 5.h,
              backgroundColor: Colors.white,
              valueColor: const AlwaysStoppedAnimation<Color>(_kPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionBody extends StatelessWidget {
  final DailyQuizQuestion question;
  final DailyQuizProvider provider;

  const _QuestionBody({required this.question, required this.provider});

  @override
  Widget build(BuildContext context) {
    final answer = provider.answerFor(question.id);
    final revealed = answer != null;

    return ListView(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 16.h),
      children: [
        if (question.subject != null)
          Text(
            [question.subject, question.topic].whereType<String>().join(' · '),
            style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600),
          ),
        SizedBox(height: 8.h),
        if (question.questionText != null && question.questionText!.isNotEmpty)
          Text(question.questionText!,
              style: TextStyle(
                  fontSize: 14.5.sp, height: 1.45, color: Colors.black87)),
        // A question can be an image alone.
        if (question.questionImageUrl != null) ...[
          SizedBox(height: 12.h),
          _Image(url: question.questionImageUrl!),
        ],
        SizedBox(height: 18.h),
        for (var i = 0; i < question.options.length; i++) ...[
          _OptionTile(
            letter: String.fromCharCode(65 + i),
            option: question.options[i],
            // One shot per question: once answered the options lock, because
            // re-answering is a 409 and because changing your mind after the
            // explanation would make the score meaningless.
            enabled: !revealed && !provider.isSubmitting,
            selectedId: answer?.selectedOptionId,
            correctId: answer?.correctOptionId,
            revealed: revealed,
            pending: provider.pendingOptionId == question.options[i].id,
            onTap: () => provider.answer(question.id, question.options[i].id),
          ),
          SizedBox(height: 10.h),
        ],
        if (revealed) ...[
          SizedBox(height: 6.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14.r),
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
                        size: 17.sp,
                        color: answer.isCorrect ? _kPrimary : _kRed),
                    SizedBox(width: 6.w),
                    Text(answer.isCorrect ? 'Correct' : 'Incorrect',
                        style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: answer.isCorrect ? _kPrimary : _kRed)),
                    const Spacer(),
                    Text(
                      // Negative marks render as sent — never "--0.5".
                      answer.marksAwarded > 0
                          ? '+${answer.marksAwarded}'
                          : '${answer.marksAwarded}',
                      style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: answer.marksAwarded > 0
                              ? _kPrimary
                              : answer.marksAwarded < 0
                                  ? _kRed
                                  : Colors.grey.shade600),
                    ),
                  ],
                ),
                if (answer.explanation != null &&
                    answer.explanation!.isNotEmpty) ...[
                  SizedBox(height: 10.h),
                  Text(answer.explanation!,
                      style: TextStyle(
                          fontSize: 12.5.sp,
                          height: 1.45,
                          color: Colors.grey.shade800)),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String letter;
  final DailyQuizOption option;
  final bool enabled;
  final int? selectedId;
  final int? correctId;
  final bool revealed;
  final VoidCallback onTap;

  /// Tapped, and waiting on the server's verdict.
  final bool pending;

  const _OptionTile({
    required this.letter,
    required this.option,
    required this.enabled,
    required this.selectedId,
    required this.correctId,
    required this.revealed,
    required this.onTap,
    this.pending = false,
  });

  @override
  Widget build(BuildContext context) {
    final isCorrect = revealed && option.id == correctId;
    final isWrongPick =
        revealed && option.id == selectedId && option.id != correctId;

    final border = isCorrect
        ? _kPrimary
        : isWrongPick
            ? _kRed
            : pending
                // Neutral on purpose. The tap is acknowledged; guessing at
                // green or red before the server rules would be a lie half
                // the time.
                ? _kPrimary
                : Colors.transparent;
    final fill = isCorrect
        ? _kPrimary.withValues(alpha: 0.08)
        : isWrongPick
            ? _kRed.withValues(alpha: 0.07)
            : pending
                ? _kPrimary.withValues(alpha: 0.06)
                : Colors.white;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: border, width: 1.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 14.r,
              backgroundColor: isCorrect
                  ? _kPrimary
                  : isWrongPick
                      ? _kRed
                      : pending
                          ? _kPrimary
                          : Colors.grey.shade200,
              child: pending
                  // On the tile itself, not over the page: the student can
                  // see exactly which answer is being checked.
                  ? SizedBox(
                      width: 13.r,
                      height: 13.r,
                      child: const CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(letter,
                      style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          color: isCorrect || isWrongPick
                              ? Colors.white
                              : Colors.black87)),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (option.optionText != null && option.optionText!.isNotEmpty)
                    Text(option.optionText!,
                        style: TextStyle(
                            fontSize: 13.5.sp,
                            height: 1.35,
                            color: Colors.black87)),
                  // An option can be an image with no words at all.
                  if (option.optionImageUrl != null) ...[
                    if (option.optionText != null &&
                        option.optionText!.isNotEmpty)
                      SizedBox(height: 8.h),
                    _Image(url: option.optionImageUrl!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final DailyQuizProvider provider;
  final VoidCallback onFinish;

  const _Footer({required this.provider, required this.onFinish});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 18.h),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          if (provider.currentIndex > 0) ...[
            Expanded(
              child: SizedBox(
                height: 46.h,
                child: OutlinedButton(
                  onPressed: provider.previous,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kPrimary,
                    side: const BorderSide(color: _kPrimary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26.r)),
                  ),
                  child: Text('Previous',
                      style: TextStyle(
                          fontSize: 13.sp, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            SizedBox(width: 12.w),
          ],
          Expanded(
            child: SizedBox(
              height: 46.h,
              child: ElevatedButton(
                onPressed: provider.isSubmitting
                    ? null
                    : (provider.isLast ? onFinish : provider.next),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _kPrimary.withValues(alpha: 0.5),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26.r)),
                ),
                child: provider.isSubmitting
                    ? SizedBox(
                        width: 16.w,
                        height: 16.w,
                        child: const CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(provider.isLast ? 'Finish' : 'Next',
                        style: TextStyle(
                            fontSize: 13.sp, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Image extends StatelessWidget {
  final String url;

  const _Image({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12.r),
      child: Image.network(
        url,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : AppLoading(height: 150.h),
        // A missing image must not take the question down with it.
        errorBuilder: (context, _, __) => Container(
          height: 80.h,
          alignment: Alignment.center,
          color: Colors.grey.shade200,
          child: Text('Image unavailable',
              style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600)),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;

  const _Message({required this.text});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: EdgeInsets.all(32.w),
          child: Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13.sp, height: 1.4, color: Colors.grey.shade700)),
        ),
      );
}
