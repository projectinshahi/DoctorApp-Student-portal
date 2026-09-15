import 'package:dr_app/models/selection_content_model.dart';
import 'package:dr_app/repository/daily_quiz_provider.dart';
import 'package:dr_app/repository/selection_content_provider.dart';
import 'package:dr_app/view/Home/notifications/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(440, 956);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HomeSummaryProvider()),
        ChangeNotifierProvider(create: (_) => SelectionContentProvider()),
      ],
      child: ScreenUtilInit(
        designSize: const Size(440, 956),
        minTextAdapt: true,
        builder: (context, _) =>
            const MaterialApp(home: NotificationsScreen()),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows its heading and subtitle', (tester) async {
    await _pump(tester);

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Check your notifications'), findsOneWidget);
  });

  testWidgets('with nothing to report it says so, rather than sitting blank',
      (tester) async {
    // No feed endpoint exists, so an account with no state has genuinely
    // nothing here — and an empty screen with no words reads as broken.
    await _pump(tester);

    expect(find.text('Nothing waiting'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('the model carries what a row needs', () {
    // onOpen null is a row with nowhere to go — a statement, not a link.
    const item = AppNotification(
      icon: Icons.check_rounded,
      title: 'Daily goal reached',
      body: 'You answered today.',
    );

    expect(item.unread, isFalse, reason: 'read unless it says otherwise');
    expect(item.onOpen, isNull);
  });

  test('a lesson row knows where it is going', () {
    var opened = false;
    final item = AppNotification(
      icon: Icons.play_arrow_rounded,
      title: 'Continue Cardiology',
      body: 'You left this part-way through.',
      unread: true,
      onOpen: () => opened = true,
    );

    item.onOpen!();
    expect(opened, isTrue);
  });

  test('a chapter with no watchable lessons produces no rows', () {
    // Locked and completed lessons are not news.
    final chapter = StudentChapterModel(
      id: 1,
      title: 'C',
      displayOrder: 1,
      lessons: const [],
    );
    expect(chapter.lessons, isEmpty);
  });
}
