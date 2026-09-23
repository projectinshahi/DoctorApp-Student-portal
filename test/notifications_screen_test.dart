import 'dart:async';

import 'package:dr_app/models/notification_model.dart';
import 'package:dr_app/models/quiz_model.dart'
    show QuizErrorKind, QuizException;
import 'package:dr_app/repository/notification_feed_provider.dart';
import 'package:dr_app/repository/selection_content_provider.dart';
import 'package:dr_app/services/notification_feed_service.dart';
import 'package:dr_app/view/Home/notifications/notifications_screen.dart';
import 'package:dr_app/widget/loading_wave.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _row(
  int id, {
  String type = 'new_test',
  String title = 'New mock test',
  String body = 'DHA Grand Test 3',
  Map<String, String> data = const {'testId': '9', 'courseId': '22'},
  bool read = false,
}) =>
    {
      'id': id,
      'type': type,
      'title': title,
      'body': body,
      'data': data,
      'createdAt': '2026-09-23T06:10:00.000Z',
      'read': read,
    };

class _FakeFeedService extends NotificationFeedService {
  /// Pages, oldest call first. Each is what the server would answer.
  final List<Map<String, dynamic>> pages;
  final List<String> calls = [];
  int _page = 0;

  _FakeFeedService({List<Map<String, dynamic>>? pages})
      : pages = pages ??
            [
              {
                'notifications': [
                  _row(12),
                  _row(11,
                      type: 'admin_message',
                      title: 'From the academy',
                      body: 'Classes resume on Monday.'),
                ],
                'unreadCount': 2,
                'nextBefore': null,
              }
            ];

  bool failMarkRead = false;

  /// Held open to freeze the fetch mid-flight.
  Completer<void>? gate;

  @override
  Future<NotificationFeed> fetch({int limit = 30, String? before}) async {
    calls.add(before == null ? 'fetch' : 'fetch before=$before');
    if (gate != null) await gate!.future;
    // A page back is the next one along; no `before` starts again at the top.
    _page = before == null ? 0 : _page + 1;
    return NotificationFeed.fromJson(
        pages[_page.clamp(0, pages.length - 1)]);
  }

  @override
  Future<int> markRead() async {
    calls.add('read');
    // What the real service throws, and the only thing the provider catches.
    if (failMarkRead) throw QuizException(QuizErrorKind.network, 'offline');
    return 0;
  }
}

Future<NotificationFeedProvider> _pump(
  WidgetTester tester, {
  _FakeFeedService? service,
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(440, 956);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final feed = NotificationFeedProvider(service: service ?? _FakeFeedService());

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<NotificationFeedProvider>.value(value: feed),
        ChangeNotifierProvider(create: (_) => SelectionContentProvider()),
      ],
      child: ScreenUtilInit(
        designSize: const Size(440, 956),
        minTextAdapt: true,
        builder: (context, _) => const MaterialApp(home: NotificationsScreen()),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
  return feed;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('reading the server', () {
    test('a row keeps its data map, ids and all, as strings', () {
      final item = NotificationItem.fromJson(_row(12));

      expect(item.id, 12);
      expect(item.title, 'New mock test');
      expect(item.data['testId'], '9');
      // FCM refuses a number in data, so ids arrive as text and are parsed.
      expect(item.idFrom('testId'), 9);
      expect(item.idFrom('missing'), isNull);
      expect(item.read, isFalse);
      expect(item.createdAt, isNotNull);
    });

    test('a page says whether there is another', () {
      final last = NotificationFeed.fromJson({
        'notifications': [_row(1)],
        'unreadCount': 0,
        'nextBefore': null,
      });
      expect(last.nextBefore, isNull, reason: 'the last page: stop asking');

      final more = NotificationFeed.fromJson({
        'notifications': [_row(2)],
        'unreadCount': 1,
        'nextBefore': '2026-09-21T09:00:00.000Z',
      });
      expect(more.nextBefore, '2026-09-21T09:00:00.000Z');
    });
  });

  group('where a row leads', () {
    NotificationItem item(String type, Map<String, String> data) =>
        NotificationItem.fromJson(_row(1, type: type, data: data));

    test('each type opens what it names', () {
      expect(targetOf(item('new_course', {})).action,
          NotificationAction.courseList);
      expect(targetOf(item('course_join', {'courseId': '22'})).id, 22);
      expect(targetOf(item('new_test', {'testId': '9'})).id, 9);
      expect(targetOf(item('new_lesson', {'lessonId': '4'})).action,
          NotificationAction.lesson);
      expect(targetOf(item('new_quiz', {'lessonId': '4'})).action,
          NotificationAction.quiz);
      expect(targetOf(item('new_rapid_recall', {'rapidRecallId': '7'})).id, 7);
      expect(targetOf(item('new_questions', {'subjectId': '8'})).action,
          NotificationAction.questionBank);
    });

    test('a plan about to run out leads to the renewal prompt', () {
      final target = targetOf(item('subscription_expiring',
          {'subscriptionId': '5', 'courseId': '22', 'daysLeft': '3'}));

      expect(target.action, NotificationAction.subscription);
      expect(target.id, 22, reason: 'the course, not the subscription row');
      expect(iconFor('subscription_expiring'), Icons.schedule_rounded);
    });

    test('an announcement, and a type this app has never heard of, stay put',
        () {
      // Types are added on the server without an app release, so an unknown
      // one must be a row that does nothing — never a crash.
      expect(targetOf(item('admin_message', {})).action,
          NotificationAction.none);
      expect(targetOf(item('something_new_in_2027', {})).action,
          NotificationAction.none);
      expect(iconFor('something_new_in_2027'), isNotNull);
    });
  });

  group('the list', () {
    test('a second page is added to the first, and then it stops asking',
        () async {
      final service = _FakeFeedService(pages: [
        {
          'notifications': [_row(12)],
          'unreadCount': 1,
          'nextBefore': '2026-09-21T09:00:00.000Z',
        },
        {
          'notifications': [_row(11)],
          'unreadCount': 1,
          'nextBefore': null,
        },
      ]);
      final feed = NotificationFeedProvider(service: service);

      await feed.load();
      expect(feed.items, hasLength(1));
      expect(feed.hasMore, isTrue);

      await feed.loadMore();
      expect(feed.items.map((i) => i.id), [12, 11]);
      expect(feed.hasMore, isFalse);

      await feed.loadMore();
      expect(service.calls, ['fetch', 'fetch before=2026-09-21T09:00:00.000Z'],
          reason: 'the last page is not asked for twice');
    });

    test('marking read clears the badge', () async {
      final service = _FakeFeedService();
      final feed = NotificationFeedProvider(service: service);
      await feed.load();
      expect(feed.unreadCount, 2);

      await feed.markRead();
      expect(feed.unreadCount, 0);
      expect(service.calls, contains('read'));
    });

    test('a failed mark-read puts the badge back, rather than lying', () async {
      final service = _FakeFeedService()..failMarkRead = true;
      final feed = NotificationFeedProvider(service: service);
      await feed.load();

      await feed.markRead();
      expect(feed.unreadCount, 2);
    });

    test('a push while the app is open moves the badge on its own', () async {
      // The row is already stored on the server; the list catches up later.
      final feed = NotificationFeedProvider(service: _FakeFeedService());
      await feed.load();

      feed.bumpUnread();
      expect(feed.unreadCount, 3);
    });

    test('signing out empties it', () async {
      final feed = NotificationFeedProvider(service: _FakeFeedService());
      await feed.load();

      feed.clear();
      expect(feed.items, isEmpty);
      expect(feed.unreadCount, 0);
    });
  });

  group('the screen', () {
    testWidgets('shows the rows, and marks them read on opening',
        (tester) async {
      final service = _FakeFeedService();
      final feed = await _pump(tester, service: service);

      expect(find.text('New mock test'), findsOneWidget);
      expect(find.text('DHA Grand Test 3'), findsOneWidget);
      // Opening the screen is what clears the badge — there is one timestamp
      // per student, and no endpoint for a single row.
      expect(service.calls, ['fetch', 'read']);
      expect(feed.unreadCount, 0);
    });

    testWidgets('an empty list says so, and is not an error', (tester) async {
      await _pump(
        tester,
        service: _FakeFeedService(pages: [
          {'notifications': [], 'unreadCount': 0, 'nextBefore': null}
        ]),
      );

      expect(find.textContaining('Nothing yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('waits with a skeleton, rather than saying "nothing yet"',
        (tester) async {
      // The screen is built before its own fetch has even started, so
      // "loading" cannot mean "a request is in flight" — it means nothing has
      // come back yet.
      final gate = Completer<void>();
      final service = _FakeFeedService()..gate = gate;
      await _pump(tester, service: service, settle: false);

      expect(find.byType(WaveBar), findsWidgets);
      expect(find.textContaining('Nothing yet'), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.text('New mock test'), findsOneWidget);
      expect(find.byType(WaveBar), findsNothing);
    });

    testWidgets('opening it twice leaves one, so Back goes straight home',
        (tester) async {
      // The bell and a tapped notification both open it, and either can fire
      // while it is already up.
      final feed = NotificationFeedProvider(service: _FakeFeedService());
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<NotificationFeedProvider>.value(value: feed),
            ChangeNotifierProvider(create: (_) => SelectionContentProvider()),
          ],
          child: ScreenUtilInit(
            designSize: const Size(440, 956),
            minTextAdapt: true,
            builder: (context, _) => MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => NotificationsScreen.open(context),
                    child: const Text('bell'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('bell'));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsScreen), findsOneWidget);

      // A second open, from the screen itself — what a tapped push does.
      NotificationsScreen.open(tester.element(find.byType(NotificationsScreen)));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsScreen), findsOneWidget,
          reason: 'the second replaced the first rather than stacking');

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(find.text('bell'), findsOneWidget, reason: 'one Back, not two');
    });

    testWidgets('lays out on a short phone', (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      await _pump(tester);
      expect(tester.takeException(), isNull);
    });
  });
}
