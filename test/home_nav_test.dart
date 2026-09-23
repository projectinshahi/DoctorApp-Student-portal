import 'dart:convert';

import 'package:dr_app/core/constant/local_storage.dart';
import 'package:dr_app/repository/daily_quiz_provider.dart';
import 'package:dr_app/repository/notification_feed_provider.dart';
import 'package:dr_app/repository/plan_access_provider.dart';
import 'package:dr_app/repository/profile_provider.dart';
import 'package:dr_app/repository/rapid_recall_provider.dart';
import 'package:dr_app/repository/saved_provider.dart';
import 'package:dr_app/repository/settings_provider.dart';
import 'package:dr_app/repository/selection_content_provider.dart';
import 'package:dr_app/view/Home/home_screen.dart';
import 'package:dr_app/view/Home/profile/profile_screen.dart';
import 'package:dr_app/view/Home/recall/recall_lists_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_screen_test.dart' show FakeNotifications;

/// Enough of a course tree to get the home screen past its skeleton — the
/// header only draws when there is content to draw under it.
const _tree = {
  'chapters': [
    {
      'id': 1,
      'title': 'Gynaecology',
      'displayOrder': 1,
      'lessons': <Map<String, dynamic>>[],
    },
  ],
};

Future<void> _pumpHome(WidgetTester tester) async {
  // A phone-sized surface, matching the app's design size. The default
  // 800x600 test window is wider and much shorter than any device this ships
  // to, and the home header legitimately does not fit in 600px of height.
  tester.view.physicalSize = const Size(440, 956);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        // Homescreen reads all of these on its first frame; without them the
        // tree throws ProviderNotFoundException before the nav bar builds.
        ChangeNotifierProvider<SelectionContentProvider>(
            create: (_) => SelectionContentProvider()),
        ChangeNotifierProvider<ProfileProvider>(create: (_) => ProfileProvider()),
        ChangeNotifierProvider<SavedProvider>(create: (_) => SavedProvider()),
        ChangeNotifierProvider<HomeSummaryProvider>(
            create: (_) => HomeSummaryProvider()),
        // The nav's fifth slot opens Rapid Recall, which reads this one.
        ChangeNotifierProvider<RapidRecallProvider>(
            create: (_) => RapidRecallProvider()),
        // The bell's unread badge reads this.
        ChangeNotifierProvider<NotificationFeedProvider>(
            create: (_) => NotificationFeedProvider()),
        // Home shows the "activating notifications" strip from this.
        ChangeNotifierProvider<PlanAccessProvider>(
            create: (_) => PlanAccessProvider()),
        ChangeNotifierProvider<SettingsProvider>(
            create: (_) =>
                SettingsProvider(notifications: FakeNotifications())),
      ],
      child: ScreenUtilInit(
        designSize: const Size(440, 956),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) => const MaterialApp(home: Homescreen()),
      ),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the fifth nav slot opens Rapid Recall', (tester) async {
    await _pumpHome(tester);

    expect(find.text('Recall'), findsOneWidget);
    await tester.tap(find.text('Recall'));

    // Not pumpAndSettle: the loading spinner animates forever, so "settled"
    // never arrives. Two pumps are enough to run the route transition.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(RecallTopicsScreen), findsOneWidget);
  });

  testWidgets('Profile is still one tap away from the header', (tester) async {
    // Profile gave up its nav slot to Recall. It was always reachable from
    // the header icon too — this is the check that the slot was the second
    // way in, not the only one.
    await LocalStorage.saveCourseTree(jsonEncode(_tree));
    await _pumpHome(tester);
    // One turn of the event loop for the disk restore.
    await tester.pump();

    expect(find.text('Profile'), findsNothing);

    // The skeleton stands down when there is a tree to draw and the MCQ
    // card's 1200ms cap has passed.
    await tester.pump(const Duration(milliseconds: 1500));

    await tester.tap(find.byType(IconButton).first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(ProfileScreen), findsOneWidget);
  });
}
