// lib/view/Home/tests/test_attempt_screen.dart
//
// The paper itself: one question at a time, a server-driven countdown, and a
// submit that cannot be taken back.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../models/quiz_model.dart' show QuizErrorKind;
import '../../../models/test_model.dart';
import '../../../repository/test_provider.dart';
import '../../../widget/app_loading.dart';
import '../../../widget/quiz_loading.dart';
import 'test_question_palette.dart';
import 'test_result_screen.dart';

const Color _kPrimary = Color(0xFF87986B);
const Color _kBg = Color(0xFFEFF4E2);

class TestAttemptScreen extends StatelessWidget {
  final TestSummary test;

  const TestAttemptScreen({super.key, required this.test});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<TestProvider>(
      create: (_) => TestProvider()..start(test.id),
      child: _AttemptView(test: test),
    );
  }
}

class _AttemptView extends StatefulWidget {
  final TestSummary test;

  const _AttemptView({required this.test});

  @override
  State<_AttemptView> createState() => _AttemptViewState();
}

class _AttemptViewState extends State<_AttemptView> {
  TestSummary get test => widget.test;

  @override
  void initState() {
    super.initState();
    // The clock runs out on its own schedule, so the paper has to end itself.
    context.read<TestProvider>().onExpired = _onExpired;
  }

  /// No confirm dialog: there is nothing left to decide, and the server has
  /// either already closed the paper or is about to.
  Future<void> _onExpired() async {
    final provider = context.read<TestProvider>();
    if (provider.result != null || provider.isSubmitting) return;
    await _finish(context, provider);
  }

  /// Leaving mid-paper is allowed — the attempt and its clock live on the
  /// server — but it must be deliberate, because the clock keeps running.
  Future<bool> _confirmExit(BuildContext context, TestProvider provider) async {
    if (provider.result != null) return true;

    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave the test?'),
        content: Text(
          'Your answers are saved, and you can resume from the tests list. '
          'The timer keeps running while you are away.',
          style: TextStyle(fontSize: 13.sp, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    return leave == true;
  }

  Future<void> _submit(BuildContext context, TestProvider provider) async {
    final skipped = provider.skippedCount;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Submit this test?'),
        content: Text(
          skipped > 0
              ? '$skipped of ${provider.totalQuestions} questions are unanswered. '
                  'Skipped questions score 0 — they are not penalised.'
              : 'All ${provider.totalQuestions} questions are answered.',
          style: TextStyle(fontSize: 13.sp, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep going'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await _finish(context, provider);
  }

  /// The navigator, over the paper. It shares this screen's provider, so the
  /// grid is live: answering a question recolours its box.
  void _openPalette(BuildContext context, TestProvider provider) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ChangeNotifierProvider<TestProvider>.value(
          value: provider,
          child: TestQuestionPalette(
            onSubmit: () => _submit(context, provider),
          ),
        ),
      ),
    );
  }

  /// Submits and shows the sheet. Shared by the button and by the clock
  /// running out.
  Future<void> _finish(BuildContext context, TestProvider provider) async {
    final ok = await provider.submit();
    if (!ok || !context.mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => TestResultScreen(
          attemptId: provider.attempt!.attemptId,
          testId: test.id,
          testName: test.name,
          preloaded: provider.result,
          leaderboard: provider.leaderboard,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TestProvider>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmExit(context, provider) && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: _kBg,
        appBar: AppBar(
          backgroundColor: _kBg,
          elevation: 0,
          title: Text(test.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 15.sp, fontWeight: FontWeight.w700, color: Colors.black87)),
          leading: IconButton(
            onPressed: () async {
              if (await _confirmExit(context, provider) && context.mounted) {
                Navigator.pop(context);
              }
            },
            icon: Icon(Icons.chevron_left_rounded, size: 30.sp, color: Colors.black),
          ),
          actions: [
            if (!provider.isLoading && provider.failure == null)
              Padding(
                padding: EdgeInsets.only(right: 14.w),
                child: Center(child: _Countdown(provider: provider)),
              ),
          ],
        ),
        body: _body(context, provider),
      ),
    );
  }

  Widget _body(BuildContext context, TestProvider provider) {
    // The same wait as opening a QBank quiz — questions that do not exist
    // until the server makes the attempt — so it reads the same way.
    if (provider.isLoading) {
      return const QuizLoading(message: 'Preparing your paper…');
    }

    final failure = provider.failure;
    if (failure != null) {
      // A paper whose time ran out while the app was closed has already been
      // submitted by the server. Sending the student to the marked sheet is
      // the designed path, not an error to apologise for.
      final expired = failure.kind == QuizErrorKind.attemptFinished;
      return _Message(
        text: failure.message,
        actionLabel: expired ? 'See result' : 'Try again',
        onAction: () {
          if (expired) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => TestResultScreen(
                  attemptId: test.lastAttempt?.attemptId ?? 0,
                  testId: test.id,
                  testName: test.name,
                ),
              ),
            );
          } else {
            provider.start(test.id);
          }
        },
      );
    }

    final question = provider.currentQuestion;
    if (question == null) {
      return const _Message(text: 'This test has no questions yet.');
    }

    return Column(
      children: [
        _ProgressStrip(provider: provider),
        Expanded(child: _QuestionBody(question: question, provider: provider)),
        if (provider.actionError != null)
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 8.h),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded, size: 15.sp, color: Colors.red.shade600),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(provider.actionError!,
                      style: TextStyle(fontSize: 11.5.sp, color: Colors.red.shade700)),
                ),
              ],
            ),
          ),
        _Footer(
          provider: provider,
          onSubmit: () => _submit(context, provider),
          onOpenPalette: () => _openPalette(context, provider),
        ),
      ],
    );
  }
}

/// The exam clock. Red under a minute; at zero the paper locks and only
/// submit is left.
class _Countdown extends StatelessWidget {
  final TestProvider provider;

  const _Countdown({required this.provider});

  @override
  Widget build(BuildContext context) {
    final urgent = provider.secondsRemaining <= 60;
    final color = urgent ? Colors.red.shade600 : Colors.black87;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: urgent ? Colors.red.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 14.sp, color: color),
          SizedBox(width: 5.w),
          Text(
            provider.isTimeUp ? "Time's up" : provider.formattedTime,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressStrip extends StatelessWidget {
  final TestProvider provider;

  const _ProgressStrip({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 10.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${provider.currentIndex + 1} of ${provider.questions.length}',
                  style: TextStyle(
                      fontSize: 12.sp, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
              Text('Answered ${provider.answeredCount}/${provider.totalQuestions}',
                  style: TextStyle(
                      fontSize: 12.sp, fontWeight: FontWeight.w600, color: _kPrimary)),
            ],
          ),
          SizedBox(height: 8.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(10.r),
            child: LinearProgressIndicator(
              value: provider.questions.isEmpty
                  ? 0
                  : (provider.currentIndex + 1) / provider.questions.length,
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
  final TestQuestion question;
  final TestProvider provider;

  const _QuestionBody({required this.question, required this.provider});

  @override
  Widget build(BuildContext context) {
    final selected = provider.selectedOption(question.id);
    final busy = provider.isBusy(question.id);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text and image are both optional — a question can be an ECG on
          // its own, with nothing written above it.
          if (question.questionText != null && question.questionText!.isNotEmpty)
            Text(
              question.questionText!,
              style: TextStyle(fontSize: 14.5.sp, color: Colors.black87, height: 1.5),
            ),
          if (question.questionImageUrl != null) ...[
            SizedBox(height: 12.h),
            _Image(url: question.questionImageUrl!),
          ],
          SizedBox(height: 18.h),
          for (final letter in question.letters) ...[
            _OptionTile(
              letter: letter,
              text: question.textFor(letter),
              imageUrl: question.imageFor(letter),
              selected: selected == letter,
              busy: busy && selected == letter,
              // Locked at zero: the server will not take another answer, and
              // pretending otherwise would lose it silently.
              enabled: !provider.isTimeUp && provider.busyQuestionId == null,
              onTap: () => provider.select(question.id, letter),
            ),
            SizedBox(height: 12.h),
          ],
          if (selected != null && !provider.isTimeUp)
            Padding(
              padding: EdgeInsets.only(top: 4.h),
              child: Text(
                'Tap $selected again to clear it — a skipped question scores 0, '
                'a wrong one loses marks.',
                style: TextStyle(fontSize: 11.5.sp, color: Colors.grey.shade600, height: 1.4),
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
    return GestureDetector(
      // The answer often lives in a detail — an ECG lead, one cell on a slide
      // — that is unreadable at column width. Tapping opens it full screen.
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => _FullScreenImage(url: url),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: Image.network(
        url,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : AppLoading(height: 160.h),
        // A missing image must not take the question down with it — the
        // student can still read the options and answer.
        errorBuilder: (context, _, __) => Container(
          height: 90.h,
          alignment: Alignment.center,
          color: Colors.grey.shade200,
          child: Text('Image unavailable',
              style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600)),
        ),
        ),
      ),
    );
  }
}

/// The question image on its own, on black, pinch to zoom.
class _FullScreenImage extends StatelessWidget {
  final String url;

  const _FullScreenImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Center(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (context, _, __) => Text('Image unavailable',
                      style: TextStyle(fontSize: 13.sp, color: Colors.white70)),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8.h,
            right: 8.w,
            child: IconButton(
              onPressed: () => Navigator.maybePop(context),
              icon: Icon(Icons.close_rounded, size: 28.sp, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String letter;
  final String? text;
  final String? imageUrl;
  final bool selected;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  const _OptionTile({
    required this.letter,
    required this.text,
    required this.imageUrl,
    required this.selected,
    required this.busy,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: selected ? _kPrimary.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: selected ? _kPrimary : Colors.grey.shade300,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 14.r,
              backgroundColor: selected ? _kPrimary : Colors.grey.shade200,
              child: busy
                  ? SizedBox(
                      width: 12.w,
                      height: 12.w,
                      child: const CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(letter,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : Colors.black87,
                      )),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (text != null && text!.isNotEmpty)
                    Text(text!,
                        style: TextStyle(
                            fontSize: 13.5.sp, color: Colors.black87, height: 1.35)),
                  // An option can be a slide with no words at all.
                  if (imageUrl != null) ...[
                    if (text != null && text!.isNotEmpty) SizedBox(height: 8.h),
                    _Image(url: imageUrl!),
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

/// The bar from the paper: navigator, star, and one forward button.
///
/// Previous/Next are gone on purpose — at 40 questions, walking the paper two
/// taps at a time is unusable. The navigator does the moving, and this row
/// keeps only what is needed without leaving the question.
class _Footer extends StatelessWidget {
  final TestProvider provider;
  final VoidCallback onSubmit;
  final VoidCallback onOpenPalette;

  const _Footer({
    required this.provider,
    required this.onSubmit,
    required this.onOpenPalette,
  });

  @override
  Widget build(BuildContext context) {
    final question = provider.currentQuestion;
    final marked = question != null && provider.isMarked(question.id);
    final answered =
        question != null && provider.selectedOption(question.id) != null;

    // At zero, and on the last question, forward is submit.
    final onlySubmit = provider.isTimeUp || provider.isLastQuestion;

    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onOpenPalette,
            tooltip: 'All questions',
            icon: Icon(Icons.menu_rounded, size: 24.sp, color: Colors.grey.shade800),
          ),
          IconButton(
            onPressed:
                question == null ? null : () => provider.toggleMark(question.id),
            tooltip: marked ? 'Unmark' : 'Mark for review',
            icon: Icon(
              marked ? Icons.star_rounded : Icons.star_border_rounded,
              size: 24.sp,
              color: marked ? const Color(0xFFE8A33D) : Colors.grey.shade600,
            ),
          ),
          SizedBox(width: 6.w),
          Expanded(
            child: SizedBox(
              height: 46.h,
              child: ElevatedButton(
                onPressed: provider.isSubmitting
                    ? null
                    : (onlySubmit ? onSubmit : provider.next),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _kPrimary.withValues(alpha: 0.5),
                  elevation: 0,
                  shape:
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(26.r)),
                ),
                child: provider.isSubmitting
                    ? SizedBox(
                        width: 18.w,
                        height: 18.w,
                        child: const CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        // "Skip" is honest about what Next does on an
                        // unanswered question, and skipping is not penalised.
                        onlySubmit ? 'SUBMIT' : (answered ? 'NEXT' : 'SKIP'),
                        style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _Message({required this.text, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade700, height: 1.5)),
            if (actionLabel != null) ...[
              SizedBox(height: 16.h),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
