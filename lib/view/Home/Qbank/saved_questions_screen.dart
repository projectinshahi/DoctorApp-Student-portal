// lib/view/Home/Qbank/saved_questions_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../models/saved_model.dart';
import '../../../repository/saved_provider.dart';
import '../../../widget/app_shimmer.dart';

const Color _kPrimary = Color(0xFF87986B);
const Color _kBg = Color(0xFFEFF4E2);

/// Everything the student has bookmarked.
///
/// A saved question shows its answer ONLY when the server marks it
/// `revealed` — i.e. they already answered it in a finished attempt.
/// Otherwise the question and its options render with nothing highlighted,
/// because the answer key genuinely isn't in the response. That is deliberate:
/// without it, saving a question mid-quiz and opening this screen would be a
/// way to read the answer.
class SavedQuestionsScreen extends StatefulWidget {
  const SavedQuestionsScreen({super.key});

  @override
  State<SavedQuestionsScreen> createState() => _SavedQuestionsScreenState();
}

class _SavedQuestionsScreenState extends State<SavedQuestionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<SavedProvider>().loadQuestions(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SavedProvider>();

    return Scaffold(
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
          "Bookmarks",
          style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w700, color: Colors.black),
        ),
      ),
      body: Builder(
        builder: (context) {
          if (provider.isLoadingQuestions && provider.questions.isEmpty) {
            return const ScreenShimmer(layout: ShimmerLayout.rows);
          }

          if (provider.questions.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 40.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bookmark_border_rounded, size: 40.sp, color: _kPrimary),
                    SizedBox(height: 14.h),
                    Text(
                      "Nothing saved yet",
                      style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: Colors.black87),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      "Tap the bookmark on any MCQ to keep it here for later.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5.sp, color: Colors.grey.shade700, height: 1.45),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            color: _kPrimary,
            onRefresh: provider.loadQuestions,
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 24.h),
              itemCount: provider.questions.length,
              itemBuilder: (context, index) =>
                  _SavedQuestionCard(question: provider.questions[index]),
            ),
          );
        },
      ),
    );
  }
}

class _SavedQuestionCard extends StatelessWidget {
  final SavedQuestion question;

  const _SavedQuestionCard({required this.question});

  @override
  Widget build(BuildContext context) {
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
              Expanded(
                child: Text(
                  question.lessonTitle ?? "Saved question",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5.sp, fontWeight: FontWeight.w700, color: _kPrimary),
                ),
              ),
              GestureDetector(
                onTap: () =>
                    context.read<SavedProvider>().toggleQuestion(question.questionId),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: EdgeInsets.all(2.w),
                  child: Icon(Icons.bookmark_rounded, size: 18.sp, color: _kPrimary),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),

          if (question.questionImageUrl != null && question.questionImageUrl!.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12.r),
              child: Image.network(question.questionImageUrl!, fit: BoxFit.cover),
            ),
            SizedBox(height: 10.h),
          ],

          Text(
            question.questionText,
            style: TextStyle(fontSize: 13.5.sp, height: 1.5, color: Colors.black87),
          ),
          SizedBox(height: 12.h),

          ...List.generate(question.options.length, (i) {
            final option = question.options[i];
            // `isCorrect` is bool?, not bool: it is null on every option of an
            // unrevealed question. `== true` keeps null reading as "unknown"
            // rather than as "wrong".
            final correct = question.revealed &&
                (option.id == question.correctOptionId || option.isCorrect == true);

            return Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: correct ? _kPrimary.withValues(alpha: 0.14) : _kBg,
                  borderRadius: BorderRadius.circular(24.r),
                  border: correct ? Border.all(color: _kPrimary, width: 1.3) : null,
                ),
                child: Row(
                  children: [
                    Text(
                      String.fromCharCode(65 + i),
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w700,
                        color: correct ? _kPrimary : Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        option.optionText,
                        style: TextStyle(fontSize: 12.5.sp, color: Colors.black87),
                      ),
                    ),
                    if (correct)
                      Icon(Icons.check_circle_rounded, size: 16.sp, color: _kPrimary),
                  ],
                ),
              ),
            );
          }),

          if (question.revealed &&
              question.explanation != null &&
              question.explanation!.trim().isNotEmpty) ...[
            SizedBox(height: 4.h),
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
                    question.explanation!.trim(),
                    style: TextStyle(fontSize: 12.5.sp, height: 1.5, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ],

          // Not a failure — they saved it before answering it, so the server
          // is withholding the key on purpose. Say why, rather than leaving a
          // question that looks broken.
          if (!question.revealed) ...[
            SizedBox(height: 4.h),
            Row(
              children: [
                Icon(Icons.lock_outline_rounded, size: 14.sp, color: Colors.grey.shade500),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    "Answer this one in a quiz to unlock the correct option "
                    "and its explanation.",
                    style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600, height: 1.4),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
