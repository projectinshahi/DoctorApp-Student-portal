// lib/view/Home/Qbank/qbank_subjects_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../models/selection_content_model.dart';
import 'quiz_screen.dart';

const Color _kPrimary = Color(0xFF87986B);
const Color _kBg = Color(0xFFEFF4E2);

/// Subjects inside one topic. Only quiz lessons are listed — this is the
/// MCQ section, so anything without a quiz has no place here.
class QbankSubjectsScreen extends StatelessWidget {
  final StudentChapterModel chapter;

  const QbankSubjectsScreen({super.key, required this.chapter});

  @override
  Widget build(BuildContext context) {
    final subjects = chapter.lessons.where((l) => l.isQuiz).toList();

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
          chapter.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w700, color: Colors.black),
        ),
      ),
      body: subjects.isEmpty
          ? Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 32.w),
                child: Text(
                  "No MCQ subjects in this topic yet.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade600),
                ),
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 24.h),
              itemCount: subjects.length,
              separatorBuilder: (_, __) => SizedBox(height: 12.h),
              itemBuilder: (context, index) => QbankRowTile(
                icon: Icons.help_outline_rounded,
                title: subjects[index].title,
                subtitle: _mcqLabel(subjects[index]),
                locked: subjects[index].locked,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuizScreen(
                      lessonId: subjects[index].id,
                      lessonTitle: subjects[index].title,
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  String _mcqLabel(StudentLessonModel lesson) {
    final count = lesson.quizQuestionCount;
    return count == null ? "MCQs" : "$count MCQs";
  }
}

/// Shared row used by both the topics list and the subjects list.
class QbankRowTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool locked;
  final VoidCallback onTap;

  const QbankRowTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          children: [
            Container(
              width: 44.w,
              height: 44.w,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: _kBg, shape: BoxShape.circle),
              child: Icon(icon, size: 20.sp, color: _kPrimary),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: Colors.black87),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            if (locked) ...[
              Icon(Icons.lock_outline_rounded, size: 16.sp, color: Colors.grey.shade500),
              SizedBox(width: 6.w),
            ],
            Icon(Icons.chevron_right_rounded, size: 24.sp, color: Colors.grey.shade500),
          ],
        ),
      ),
    );
  }
}
