// lib/view/Home/notifications/notifications_screen.dart
//
// What the backend has sent this student.
//
// The list is the server's, not the app's. It decides what a student can see,
// and that changes with the course they have selected — so nothing is cached
// here, and switching course switches the list.
//
// A row carries the same data map a push does, so tapping one goes exactly
// where tapping the notification would.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../core/constant/local_storage.dart';
import '../../../core/theam /app_color.dart';
import '../../../models/notification_model.dart';
import '../../../models/selection_content_model.dart';
import '../../../repository/notification_feed_provider.dart';
import '../../../repository/plan_access_provider.dart';
import '../../../repository/selection_content_provider.dart';
import '../../../widget/app_loading.dart';
import '../../../widget/learning_plan_dialog.dart';
import '../../../widget/loading_wave.dart';
import '../../../widget/app_refresh.dart';
import '../../subjectSelection/select_exam_screen.dart';
import '../Qbank/qbank_tab.dart';
import '../Qbank/quiz_screen.dart';
import '../lessons/student_lesson_detail_screen.dart';
import '../recall/recall_cards_screen.dart';
import '../tests/tests_tab.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  static const String routeName = 'notifications';

  /// Opens the list, replacing one already on top.
  ///
  /// Two ways in — the bell, and a tapped notification — and both can fire
  /// while it is already open. Stacked copies meant Back walked through the
  /// same screen twice.
  static Future<void> open(BuildContext context) {
    final navigator = Navigator.of(context);
    navigator.popUntil((route) => route.settings.name != routeName);
    return navigator.push(MaterialPageRoute(
      settings: const RouteSettings(name: routeName),
      builder: (_) => const NotificationsScreen(),
    ));
  }

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // After the first frame: both of these notify the provider, and notifying
    // during a build throws.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final feed = context.read<NotificationFeedProvider>();
      await feed.load();
      // Opening the screen is what marks them read — there is one timestamp
      // per student, and no endpoint for a single row.
      await feed.markRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<NotificationFeedProvider>();
    final items = feed.items;

    final Widget body;
    if (!feed.hasLoaded && items.isEmpty) {
      // Shaped like the rows it is about to show, rather than a spinner in
      // the middle of a blank screen.
      body = const _NotificationsSkeleton();
    } else if (items.isEmpty) {
      body = AppRefresh.fill(
        onRefresh: feed.load,
        child: _Message(
          text: feed.errorMessage ??
              'Nothing yet. New tests, lessons and quizzes for your course '
                  'will show up here.',
        ),
      );
    } else {
      body = AppRefresh(
        onRefresh: feed.load,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
          // One extra row at the foot while there are older pages to fetch.
          itemCount: items.length + (feed.hasMore ? 1 : 0),
          separatorBuilder: (_, _) => SizedBox(height: 12.h),
          itemBuilder: (context, index) {
            if (index >= items.length) return _LoadMore(feed: feed);
            final item = items[index];
            return _NotificationCard(
              item: item,
              onTap: () => openNotification(context, item),
            );
          },
        ),
      );
    }

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
      body: body,
    );
  }
}

/// The foot of the list: asks for the next page as soon as it is built, which
/// is when the student has scrolled to it.
class _LoadMore extends StatefulWidget {
  final NotificationFeedProvider feed;

  const _LoadMore({required this.feed});

  @override
  State<_LoadMore> createState() => _LoadMoreState();
}

class _LoadMoreState extends State<_LoadMore> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.feed.loadMore();
    });
  }

  @override
  Widget build(BuildContext context) =>
      Padding(padding: EdgeInsets.symmetric(vertical: 16.h), child: const AppLoading());
}

class _NotificationCard extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onTap;

  const _NotificationCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // A row already read sits back: same card, quieter ink, no dot. It is
    // what separates "this is new" from "you have seen this" at a glance.
    final read = item.read;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18.r),
      child: Container(
        padding: EdgeInsets.fromLTRB(14.w, 16.h, 16.w, 16.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18.r),
        ),
        child: Row(
          children: [
            Container(
              width: 46.w,
              height: 46.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColor.Screenbackground,
                shape: BoxShape.circle,
              ),
              child: Icon(
                iconFor(item.type),
                size: 22.sp,
                color: read
                    ? Colors.grey.shade500
                    // Amber for the one row with a deadline on it.
                    : item.type == 'subscription_expiring'
                        ? const Color(0xFF8A5B18)
                        : AppColor.buttoncolor,
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15.sp,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                      color: read ? Colors.grey.shade600 : Colors.black87,
                    ),
                  ),
                  if (item.body.isNotEmpty) ...[
                    SizedBox(height: 5.h),
                    Text(
                      item.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.sp,
                        height: 1.4,
                        color: read ? Colors.grey.shade500 : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Centred beside the text, as in the design — and absent once
            // read, rather than greyed, so the column reads as a list of what
            // is still new.
            if (!read) ...[
              SizedBox(width: 10.w),
              Container(
                width: 9.w,
                height: 9.w,
                decoration: BoxDecoration(
                  color: AppColor.buttoncolor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Three rows in the shape of the real ones, lit in turn by the app's wave.
class _NotificationsSkeleton extends StatelessWidget {
  const _NotificationsSkeleton();

  @override
  Widget build(BuildContext context) {
    return LoadingWave(
      steps: 3,
      builder: (context, lift) => ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
        itemCount: 3,
        separatorBuilder: (_, _) => SizedBox(height: 12.h),
        itemBuilder: (context, index) => Container(
          padding: EdgeInsets.fromLTRB(14.w, 16.h, 16.w, 16.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18.r),
          ),
          child: Row(
            children: [
              WaveBar(
                  width: 46.w, height: 46.w, radius: 23.w, lift: lift(index)),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WaveBar(width: 150.w, height: 13.h, lift: lift(index)),
                    SizedBox(height: 9.h),
                    WaveBar(height: 11.h, lift: lift(index)),
                  ],
                ),
              ),
            ],
          ),
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
          padding: EdgeInsets.symmetric(horizontal: 36.w),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13.sp, height: 1.5, color: Colors.grey.shade600),
          ),
        ),
      );
}

/// What a row looks like, by type. An unknown type still draws: types are
/// added on the server without an app release.
IconData iconFor(String type) => switch (type) {
      'new_course' => Icons.auto_stories_rounded,
      'course_join' => Icons.celebration_rounded,
      'new_test' => Icons.description_outlined,
      'new_quiz' => Icons.help_outline_rounded,
      'new_lesson' => Icons.play_circle_outline_rounded,
      'new_rapid_recall' => Icons.style_outlined,
      'new_questions' => Icons.quiz_outlined,
      'admin_message' => Icons.campaign_outlined,
      'subscription_expiring' => Icons.schedule_rounded,
      _ => Icons.notifications_none_rounded,
    };

/// Where a notification leads.
enum NotificationAction {
  courseList,
  selectedCourse,
  tests,
  lesson,
  quiz,
  rapidRecall,
  questionBank,

  /// A plan about to run out: the renewal prompt, which leads to the website.
  subscription,

  /// An announcement, or a type this app has not heard of: stay put.
  none,
}

/// The target of a row, and the id it names.
@immutable
class NotificationTarget {
  final NotificationAction action;
  final int? id;

  const NotificationTarget(this.action, [this.id]);
}

/// Read from the row's own data map — every value a string, ids included,
/// because FCM refuses a message with a number in it.
NotificationTarget targetOf(NotificationItem item) => switch (item.type) {
      'new_course' => const NotificationTarget(NotificationAction.courseList),
      'course_join' => NotificationTarget(
          NotificationAction.selectedCourse, item.idFrom('courseId')),
      'new_test' =>
        NotificationTarget(NotificationAction.tests, item.idFrom('testId')),
      'new_lesson' =>
        NotificationTarget(NotificationAction.lesson, item.idFrom('lessonId')),
      'new_quiz' =>
        NotificationTarget(NotificationAction.quiz, item.idFrom('lessonId')),
      'new_rapid_recall' => NotificationTarget(
          NotificationAction.rapidRecall, item.idFrom('rapidRecallId')),
      'new_questions' => NotificationTarget(
          NotificationAction.questionBank, item.idFrom('subjectId')),
      'subscription_expiring' => NotificationTarget(
          NotificationAction.subscription, item.idFrom('courseId')),
      _ => const NotificationTarget(NotificationAction.none),
    };

/// Opens what a row names.
Future<void> openNotification(
    BuildContext context, NotificationItem item) async {
  final target = targetOf(item);

  switch (target.action) {
    case NotificationAction.courseList:
      await openCoursePicker(context);

    case NotificationAction.selectedCourse:
      // The app shows one course at a time — the selected one, which is home.
      // A notification about another course opens the picker rather than
      // switching what the whole app shows without asking.
      final selected =
          context.read<SelectionContentProvider>().content?.course?.id;
      if (target.id != null && target.id == selected) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        await openCoursePicker(context);
      }

    case NotificationAction.tests:
      // The paper itself needs data this row does not carry, so this opens
      // the list it is at the top of.
      _push(context, const TestsTab());

    case NotificationAction.lesson:
      final lesson = _lessonById(context, target.id);
      if (lesson != null) {
        _push(context, StudentLessonDetailScreen(lesson: lesson));
      }

    case NotificationAction.quiz:
      final lesson = _lessonById(context, target.id);
      if (lesson != null) {
        _push(
          context,
          QuizScreen(
            lessonId: lesson.id,
            lessonTitle: lesson.title,
            knownAttempt: lesson.attempt,
            attemptStateKnown: true,
          ),
        );
      }

    case NotificationAction.rapidRecall:
      if (target.id != null) {
        _push(context, RecallCardsScreen(deckId: target.id!));
      }

    case NotificationAction.questionBank:
      _push(context, const QbankTab());

    case NotificationAction.subscription:
      // Stays on this screen. Renewing happens on the website like every
      // other purchase, so a plans screen in between would be a step whose
      // only button is the same link.
      //
      // The days are read from the plan as it stands now, not from the row: a
      // reminder left unread for three days would otherwise still say three
      // days. The row's own number is the fallback for a plan not loaded yet.
      final live = context.read<PlanAccessProvider>().daysLeftOnPlan;
      await showRenewPlanDialog(context,
          daysLeft: live ?? item.idFrom('daysLeft'));

    case NotificationAction.none:
      break; // An announcement: it has been read by being on screen.
  }
}

void _push(BuildContext context, Widget screen) => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );

/// The lesson with this id in the course tree the app already holds. Null
/// when it is not in the student's course — locked, moved, or unpublished.
StudentLessonModel? _lessonById(BuildContext context, int? id) {
  if (id == null) return null;
  final content = context.read<SelectionContentProvider>().content;
  for (final chapter in content?.chapters ?? const <StudentChapterModel>[]) {
    for (final lesson in chapter.lessons) {
      if (lesson.id == id) return lesson;
    }
  }
  return null;
}

/// The course picker, with the tokens it needs.
Future<void> openCoursePicker(BuildContext context) async {
  final tokens = await Future.wait([
    LocalStorage.getAccessToken(),
    LocalStorage.getRefreshToken(),
    LocalStorage.getDeviceId(),
  ]);
  if (!context.mounted) return;

  _push(
    context,
    ExamSelectionScreen(
      accessToken: tokens[0] ?? '',
      refreshToken: tokens[1] ?? '',
      deviceId: tokens[2] ?? '',
    ),
  );
}
