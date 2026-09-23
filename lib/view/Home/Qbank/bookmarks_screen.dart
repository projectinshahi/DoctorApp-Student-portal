// lib/view/Home/Qbank/bookmarks_screen.dart
//
// Everything the student has saved — questions and lessons — behind one set
// of filter chips, from `GET /users/me/saved?type=all`.
import 'package:flutter/material.dart';

import '../../../widget/app_refresh.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../models/saved_model.dart';
import '../../../repository/saved_provider.dart';
import '../../../widget/app_loading.dart';
import '../lessons/student_lesson_detail_screen.dart';
import '../../../core/utils/refresh_on_visible.dart';

const Color _kPrimary = Color(0xFF87986B);
const Color _kBg = Color(0xFFF4F4F2);
const Color _kCard = Color(0xFFE8E8E6);

/// One chip. `type` is the server's own key into `counts`, except [_all]
/// which is the unfiltered view.
/// Toggle, then refetch the list this screen is showing.
///
/// The toggle alone only flips an id in a set — it does not remove the row,
/// so an unsaved item sat there with a hollow icon until the screen was
/// reopened. Refetching is also what keeps `counts` honest: the chips read
/// the server's numbers, and a local removal would not move them.
Future<void> _toggleAndRefresh(
  BuildContext context,
  Future<void> Function() toggle,
) async {
  final provider = context.read<SavedProvider>();
  await toggle();
  if (!context.mounted) return;
  await provider.loadAll();
}

class _Filter {
  final String label;
  final String type;
  const _Filter(this.label, this.type);
}

const _filters = <_Filter>[
  _Filter('Saved MCQs', 'question'),
  _Filter('Saved videos', 'video'),
  _Filter('Saved notes', 'text'),
  _Filter('Saved quizzes', 'quiz'),
];

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen>
    with RefreshOnVisible<BookmarksScreen> {
  int _selected = 0;

  /// Bookmarks change from inside a quiz, a lesson, or another device, and
  /// this screen is where the student comes to check.
  @override
  Future<void> onRefresh() => context.read<SavedProvider>().loadAll();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SavedProvider>();
    final filter = _filters[_selected];

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: Icon(Icons.chevron_left_rounded, size: 30.sp, color: Colors.black),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Bookmarks',
              style: TextStyle(fontSize: 19.sp, fontWeight: FontWeight.w800, color: Colors.black),
            ),
            Text(
              'Your saved contents',
              style: TextStyle(fontSize: 11.5.sp, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 8.h),
          SizedBox(
            height: 46.h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => SizedBox(width: 10.w),
              itemBuilder: (context, index) {
                final item = _filters[index];
                return _Chip(
                  label: item.label,
                  // Straight from the server's counts, which are the full set
                  // whatever is being filtered — never a list length.
                  count: provider.countOf(item.type),
                  selected: index == _selected,
                  onTap: () => setState(() => _selected = index),
                );
              },
            ),
          ),
          SizedBox(height: 10.h),
          Expanded(child: _list(context, provider, filter)),
        ],
      ),
    );
  }

  Widget _list(BuildContext context, SavedProvider provider, _Filter filter) {
    // isLoading is now true only before the first answer arrives, so a
    // reopened Bookmarks shows the list it had and updates underneath.
    if (provider.isLoading) return const AppLoading();

    if (filter.type == 'question') {
      final questions = provider.questions;
      if (questions.isEmpty) {
        return AppRefresh.fill(
            onRefresh: onRefresh, child: _empty('No saved MCQs yet.'));
      }
      return AppRefresh(
        onRefresh: onRefresh,
        child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 24.h),
          itemCount: questions.length,
          separatorBuilder: (_, __) => SizedBox(height: 12.h),
          itemBuilder: (context, index) => _QuestionCard(question: questions[index]),
        ),
      );
    }

    final lessons = provider.lessons
        .where((saved) => saved.type == filter.type)
        .toList();
    if (lessons.isEmpty) {
      return AppRefresh.fill(
          onRefresh: onRefresh, child: _empty('Nothing saved here yet.'));
    }

    return AppRefresh(
      onRefresh: onRefresh,
      child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 24.h),
        itemCount: lessons.length,
        separatorBuilder: (_, __) => SizedBox(height: 12.h),
        itemBuilder: (context, index) => _LessonCard(saved: lessons[index]),
      ),
    );
  }

  Widget _empty(String message) => Center(
        child: Padding(
          padding: EdgeInsets.all(32.w),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade600),
          ),
        ),
      );
}

class _Chip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: 18.w),
        decoration: BoxDecoration(
          color: selected ? _kCard : Colors.white,
          borderRadius: BorderRadius.circular(24.r),
        ),
        child: Text(
          count > 0 ? '$label  $count' : label,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final SavedQuestion question;

  const _QuestionCard({required this.question});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SavedQuestionScreen(question: question)),
      ),
      child: Container(
        padding: EdgeInsets.fromLTRB(16.w, 16.h, 8.w, 16.h),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    question.questionText,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.5.sp, color: Colors.black87, height: 1.45),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    question.lessonTitle ?? '',
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            _SavedToggle(
              saved: context.watch<SavedProvider>().isQuestionSaved(question.questionId),
              onTap: () => _toggleAndRefresh(
                context,
                () => context
                    .read<SavedProvider>()
                    .toggleQuestion(question.questionId),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  final SavedLesson saved;

  const _LessonCard({required this.saved});

  IconData get _icon => switch (saved.type) {
        'video' => Icons.play_circle_outline_rounded,
        'quiz' => Icons.help_outline_rounded,
        _ => Icons.description_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // The saved row is a whole lesson, so this opens the real screen with
      // its video, notes, paywall and saved position all intact.
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StudentLessonDetailScreen(lesson: saved.lesson),
        ),
      ),
      child: Container(
        padding: EdgeInsets.fromLTRB(14.w, 14.h, 8.w, 14.h),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Row(
          children: [
            Container(
              width: 42.w,
              height: 42.w,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: Icon(_icon, size: 20.sp, color: _kPrimary),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (saved.chapterTitle != null)
                    Text(
                      saved.chapterTitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600),
                    ),
                  Text(
                    saved.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            _SavedToggle(
              saved: context.watch<SavedProvider>().isLessonSaved(saved.lessonId),
              onTap: () => _toggleAndRefresh(
                context,
                () => context.read<SavedProvider>().toggleLesson(saved.lessonId),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedToggle extends StatelessWidget {
  final bool saved;
  final VoidCallback onTap;

  const _SavedToggle({required this.saved, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(
        saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
        size: 20.sp,
        color: Colors.black87,
      ),
    );
  }
}

/// One saved question in full: the options, the correct one marked, and the
/// explanation.
///
/// All three of those are gated. `revealed` is true only when the student
/// answered this question inside a finished attempt; otherwise the server
/// strips `correctOptionId`, `explanation` and every `options[].isCorrect`,
/// and this screen must not imply an answer it was not given.
class SavedQuestionScreen extends StatelessWidget {
  final SavedQuestion question;

  const SavedQuestionScreen({super.key, required this.question});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: Icon(Icons.chevron_left_rounded, size: 30.sp, color: Colors.black),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Bookmarks',
              style: TextStyle(fontSize: 19.sp, fontWeight: FontWeight.w800, color: Colors.black),
            ),
            Text(
              question.revealed ? 'Explanation' : 'Saved question',
              style: TextStyle(fontSize: 11.5.sp, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          _SavedToggle(
            saved: context.watch<SavedProvider>().isQuestionSaved(question.questionId),
            onTap: () => _toggleAndRefresh(
              context,
              () => context
                  .read<SavedProvider>()
                  .toggleQuestion(question.questionId),
            ),
          ),
          SizedBox(width: 6.w),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 32.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question.questionText,
              style: TextStyle(fontSize: 15.sp, color: Colors.black87, height: 1.55),
            ),
            SizedBox(height: 20.h),
            for (var i = 0; i < question.options.length; i++) ...[
              if (i > 0) SizedBox(height: 12.h),
              _OptionRow(
                letter: String.fromCharCode(65 + i),
                text: question.options[i].optionText,
                // `isCorrect` is bool?, not bool: it is null on every option
                // of an unrevealed question. `== true` keeps null reading as
                // "unknown" rather than as "wrong".
                correct: question.revealed &&
                    (question.options[i].id == question.correctOptionId ||
                        question.options[i].isCorrect == true),
              ),
            ],
            if (question.revealed && question.explanation != null) ...[
              SizedBox(height: 24.h),
              Divider(color: Colors.grey.shade300, height: 1),
              SizedBox(height: 20.h),
              Text(
                question.explanation!,
                style: TextStyle(fontSize: 14.sp, color: Colors.black87, height: 1.6),
              ),
            ],
            if (!question.revealed) ...[
              SizedBox(height: 20.h),
              Row(
                children: [
                  Icon(Icons.lock_outline_rounded, size: 15.sp, color: Colors.grey.shade600),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'Answer this one in a quiz to unlock the correct option '
                      'and its explanation.',
                      style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600, height: 1.4),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final String letter;
  final String text;
  final bool correct;

  const _OptionRow({required this.letter, required this.text, required this.correct});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: correct ? _kCard : Colors.white,
        borderRadius: BorderRadius.circular(30.r),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 15.r,
            backgroundColor: correct ? Colors.white : _kBg,
            child: Text(
              letter,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13.5.sp, color: Colors.black87, height: 1.35),
            ),
          ),
          if (correct) ...[
            Icon(Icons.check_circle_rounded, size: 18.sp, color: _kPrimary),
            SizedBox(width: 6.w),
          ],
        ],
      ),
    );
  }
}
