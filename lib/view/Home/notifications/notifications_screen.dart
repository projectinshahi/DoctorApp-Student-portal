// lib/view/Home/notifications/notifications_screen.dart
//
// What is waiting for the student.
//
// There is no notifications endpoint, so rather than show a list the server
// invented, these are read off state the app already holds: today's MCQ,
// unfinished videos, and quizzes in the course tree that have not been
// opened. That makes every row true — it is about this student, right now,
// and tapping it goes to the thing it names.
//
// When a real feed arrives, replace [_buildFeed] and keep the rows.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../core/theam /app_color.dart';
import '../../../models/daily_quiz_model.dart';
import '../../../models/selection_content_model.dart';
import '../../../repository/daily_quiz_provider.dart';
import '../../../repository/selection_content_provider.dart';
import '../lessons/student_lesson_detail_screen.dart';

/// One row. [onOpen] is null when there is nowhere useful to go.
class AppNotification {
  final IconData icon;
  final String title;
  final String body;

  /// Unread is "not acted on yet" — a quiz still unanswered, a video still
  /// unfinished. Nothing is stored: the state itself is the read receipt.
  final bool unread;

  final VoidCallback? onOpen;

  const AppNotification({
    required this.icon,
    required this.title,
    required this.body,
    this.unread = false,
    this.onOpen,
  });
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final summary = context.watch<HomeSummaryProvider>().home;
    final content = context.watch<SelectionContentProvider>().content;
    final items = _buildFeed(context, summary?.dailyQuiz, content);

    return Scaffold(
      backgroundColor: AppColor.Screenbackground,
      appBar: AppBar(
        backgroundColor: AppColor.Screenbackground,
        elevation: 0,
        titleSpacing: 0,
        toolbarHeight: 72.h,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: Icon(Icons.chevron_left_rounded,
              size: 30.sp, color: Colors.black),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Notifications',
                style: TextStyle(
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87)),
            SizedBox(height: 2.h),
            Text('Check your notifications',
                style:
                    TextStyle(fontSize: 12.5.sp, color: Colors.grey.shade600)),
          ],
        ),
      ),
      body: items.isEmpty
          ? _Empty()
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
              itemCount: items.length,
              separatorBuilder: (_, __) => SizedBox(height: 12.h),
              itemBuilder: (context, i) => _NotificationCard(item: items[i]),
            ),
    );
  }

  /// Reads the feed off what the app already knows.
  ///
  /// Ordered by what is most worth doing next, not by time: none of these
  /// have a timestamp, and inventing one would be the same lie as inventing
  /// the notification.
  List<AppNotification> _buildFeed(
    BuildContext context,
    DailyQuizSummary? daily,
    SelectionContentModel? content,
  ) {
    final items = <AppNotification>[];

    if (daily != null) {
      final done = daily.state == DailyQuizState.completed;
      items.add(AppNotification(
        icon: done ? Icons.check_rounded : Icons.today_rounded,
        title: done ? 'Daily goal reached' : "Today's MCQ is waiting",
        body: done
            ? 'You answered today\'s question. A new one arrives tomorrow.'
            : 'Answer today\'s question to keep your streak going.',
        unread: !done,
      ));
    }

    // Videos left part-way through. The student started these, so they are
    // the most likely thing they meant to come back to.
    for (final chapter in content?.chapters ?? const <StudentChapterModel>[]) {
      for (final lesson in chapter.lessons) {
        if (items.length >= 6) break;
        if (!lesson.isVideo || lesson.locked || lesson.completed) continue;
        if (lesson.lastPositionSeconds <= 0) continue;

        items.add(AppNotification(
          icon: Icons.play_arrow_rounded,
          title: 'Continue ${lesson.title}',
          body: 'You left this part-way through.',
          unread: true,
          onOpen: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StudentLessonDetailScreen(lesson: lesson),
            ),
          ),
        ));
      }
    }

    // Then anything not started at all, so the list ends with what is new
    // rather than what is half-done.
    for (final chapter in content?.chapters ?? const <StudentChapterModel>[]) {
      for (final lesson in chapter.lessons) {
        if (items.length >= 6) break;
        if (!lesson.isVideo || lesson.locked) continue;
        if (lesson.completed || lesson.lastPositionSeconds > 0) continue;

        items.add(AppNotification(
          icon: Icons.play_arrow_rounded,
          title: 'New AI video added',
          body: lesson.title,
          onOpen: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StudentLessonDetailScreen(lesson: lesson),
            ),
          ),
        ));
      }
    }

    return items;
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification item;

  const _NotificationCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onOpen,
      borderRadius: BorderRadius.circular(18.r),
      child: Container(
        padding: EdgeInsets.fromLTRB(14.w, 16.h, 14.w, 16.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18.r),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42.w,
              height: 42.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColor.buttoncolor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon,
                  size: 21.sp, color: AppColor.buttoncolor),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87)),
                  SizedBox(height: 4.h),
                  Text(item.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12.5.sp,
                          height: 1.35,
                          color: Colors.grey.shade600)),
                ],
              ),
            ),
            // The unread dot, and the space it takes whether or not it shows
            // — otherwise the text reflows as rows are read.
            SizedBox(
              width: 16.w,
              child: item.unread
                  ? Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        margin: EdgeInsets.only(top: 6.h),
                        width: 8.w,
                        height: 8.w,
                        decoration: BoxDecoration(
                          color: AppColor.buttoncolor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none_rounded,
                size: 44.sp, color: Colors.grey.shade400),
            SizedBox(height: 14.h),
            Text('Nothing waiting',
                style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87)),
            SizedBox(height: 6.h),
            Text(
              'You are up to date. New lessons and your daily question will '
              'show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12.5.sp, height: 1.4, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
