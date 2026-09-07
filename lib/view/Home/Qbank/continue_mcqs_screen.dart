// lib/view/Home/Qbank/continue_mcqs_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../models/quiz_model.dart';
import '../../../services/quiz_service.dart';
import '../../../widget/app_loading.dart';
import 'quiz_screen.dart';

const Color _kPrimary = Color(0xFF87986B);
const Color _kBg = Color(0xFFEFF4E2);

/// Quizzes left half-finished anywhere in the course.
///
/// Backed by `GET /users/me/quiz-attempts?status=in_progress`, which is the
/// only thing that can answer this — per-lesson history would mean walking
/// every lesson in the course to find the two they abandoned.
class ContinueMcqsScreen extends StatefulWidget {
  const ContinueMcqsScreen({super.key});

  @override
  State<ContinueMcqsScreen> createState() => _ContinueMcqsScreenState();
}

class _ContinueMcqsScreenState extends State<ContinueMcqsScreen> {
  final QuizService _service = QuizService();

  List<InProgressAttempt> _attempts = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final attempts = await _service.fetchAttemptsByStatus();
      if (!mounted) return;
      setState(() {
        _attempts = attempts;
        _loading = false;
      });
    } on QuizException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _open(InProgressAttempt attempt) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          lessonId: attempt.lessonId,
          lessonTitle: attempt.lessonTitle,
        ),
      ),
    );
    // They may have finished it, which takes it off this list.
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
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
          "Continue MCQs",
          style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w700, color: Colors.black),
        ),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const AppLoading();

    if (_error != null) {
      return _Message(
        icon: Icons.cloud_off_rounded,
        title: "Couldn't load this",
        message: _error!,
        actionLabel: "Retry",
        onAction: _load,
      );
    }

    if (_attempts.isEmpty) {
      return const _Message(
        icon: Icons.task_alt_rounded,
        title: "Nothing in progress",
        message: "Every quiz you've started is finished. Pick a topic to "
            "start a new one.",
      );
    }

    return RefreshIndicator(
      color: _kPrimary,
      onRefresh: _load,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 24.h),
        itemCount: _attempts.length,
        separatorBuilder: (_, __) => SizedBox(height: 12.h),
        itemBuilder: (context, index) {
          final attempt = _attempts[index];

          return GestureDetector(
            onTap: () => _open(attempt),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: _kPrimary, width: 1.2),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44.w,
                    height: 44.w,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: _kBg, shape: BoxShape.circle),
                    child: Icon(Icons.play_arrow_rounded, size: 22.sp, color: _kPrimary),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          attempt.lessonTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: Colors.black87),
                        ),
                        SizedBox(height: 3.h),
                        Text(
                          attempt.chapterTitle == null
                              ? "${attempt.remainingCount} left of ${attempt.totalQuestions}"
                              : "${attempt.chapterTitle} · ${attempt.remainingCount} left",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: _kPrimary),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
                    decoration: BoxDecoration(
                      color: _kPrimary,
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      "Continue",
                      style: TextStyle(fontSize: 11.5.sp, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _Message({
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
        padding: EdgeInsets.symmetric(horizontal: 40.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40.sp, color: _kPrimary),
            SizedBox(height: 14.h),
            Text(
              title,
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: Colors.black87),
            ),
            SizedBox(height: 8.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5.sp, color: Colors.grey.shade700, height: 1.45),
            ),
            if (actionLabel != null) ...[
              SizedBox(height: 18.h),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.r)),
                ),
                child: Text(actionLabel!, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
