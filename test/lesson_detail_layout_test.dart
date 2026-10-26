import 'package:dr_app/core/demo/demo_content.dart';
import 'package:dr_app/models/selection_content_model.dart';
import 'package:dr_app/repository/comment_provider.dart';
import 'package:dr_app/repository/daily_quiz_provider.dart';
import 'package:dr_app/repository/saved_provider.dart';
import 'package:dr_app/repository/selection_content_provider.dart';
import 'package:dr_app/view/Home/lessons/student_lesson_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(DemoMode.reset);

  testWidgets('a long description wraps instead of overflowing',
      (tester) async {
    // The report: "An internal medicine subspecialty, endocrinology,
    // diabetes, …" ran 876px off the right edge of a phone.
    DemoMode.active = true;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const description = 'An internal medicine subspecialty, endocrinology, '
        'diabetes, and metabolism deals with hormones and glands: the '
        'thyroid, pituitary, adrenals, pancreas and gonads, and the '
        'disorders that follow when any of them makes too much or too little.';

    final lesson = StudentLessonModel.fromJson({
      'id': -900,
      'title': 'Internal Medicine (Endocrinology)',
      'description': description,
      'type': 'text',
      'accessType': 'free',
      'locked': false,
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SavedProvider()),
          ChangeNotifierProvider(create: (_) => SelectionContentProvider()),
          ChangeNotifierProvider(create: (_) => HomeSummaryProvider()),
          ChangeNotifierProvider(create: (_) => CommentProvider()),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (context, _) =>
              MaterialApp(home: StudentLessonDetailScreen(lesson: lesson)),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text(description), findsOneWidget);
    // Wrapped: several lines tall, and inside the screen's width.
    final box = tester.getRect(find.text(description));
    expect(box.right, lessThanOrEqualTo(390));
    expect(box.height, greaterThan(40));
  });
}
