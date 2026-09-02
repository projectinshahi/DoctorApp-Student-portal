import 'package:dr_app/models/home_summary_model.dart';
import 'package:dr_app/models/selection_content_model.dart';
import 'package:dr_app/view/Home/continue_learning_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

StudentLessonModel _lesson({
  int id = 1,
  String title = 'Cardiology',
  bool completed = false,
  bool locked = false,
  int position = 0,
}) =>
    StudentLessonModel.fromJson({
      'id': id,
      'title': title,
      'type': 'video',
      'videoUrl': locked ? null : 'https://x/v.mp4',
      'displayOrder': id,
      'isFreePreview': !locked,
      'accessType': locked ? 'premium' : 'free',
      'locked': locked,
      'completed': completed,
      'lastPositionSeconds': position,
    });

SelectionContentModel _content(List<StudentLessonModel> lessons) =>
    SelectionContentModel(chapters: [
      StudentChapterModel(
          id: 1, title: 'C', displayOrder: 1, lessons: lessons),
    ]);

/// Pumps the row the way the home screen does: inside a scroll view, so the
/// available height is **unbounded**. That is the condition the row shipped
/// broken under — a `CrossAxisAlignment.stretch` Row asked its cards to fill
/// an infinite height and threw during layout. Model tests cannot see it.
Future<void> _pumpInScrollView(WidgetTester tester, List<LearningItem> items) async {
  tester.view.physicalSize = const Size(440, 956);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(440, 956),
      minTextAdapt: true,
      builder: (context, child) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                ContinueLearningRow(items: items, onOpen: (_) {}),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lays out inside a scroll view without an infinite height',
      (tester) async {
    await _pumpInScrollView(tester, [
      LearningItem(lesson: _lesson(id: 1, title: 'Cardiology'), resumeAt: '1:35'),
      LearningItem(lesson: _lesson(id: 2, title: 'Obstetrics')),
    ]);

    expect(tester.takeException(), isNull);
    expect(find.text('Continue Learning'), findsOneWidget);
    expect(find.text('Cardiology'), findsOneWidget);
    expect(find.text('Obstetrics'), findsOneWidget);
  });

  testWidgets('a single card still lays out', (tester) async {
    await _pumpInScrollView(tester,
        [LearningItem(lesson: _lesson(title: 'Only one'), resumeAt: '0:40')]);

    expect(tester.takeException(), isNull);
    expect(find.text('Only one'), findsOneWidget);
  });

  testWidgets('an empty list renders nothing at all', (tester) async {
    await _pumpInScrollView(tester, const []);

    expect(tester.takeException(), isNull);
    expect(find.text('Continue Learning'), findsNothing);
  });

  testWidgets('only the resumed card shows the Resume pill', (tester) async {
    await _pumpInScrollView(tester, [
      LearningItem(lesson: _lesson(id: 1), resumeAt: '2:30'),
      LearningItem(lesson: _lesson(id: 2, title: 'Next up')),
    ]);

    expect(find.text('Resume'), findsOneWidget);
    expect(find.text('at 2:30'), findsOneWidget);
  });

  group('picking', () {
    test('the resumed video leads, and never repeats as the next card', () {
      final video = InProgressVideo.fromJson({
        'lessonId': 7,
        'title': 'Cardiology',
        'lastPositionSeconds': 95,
        'videoUrl': 'https://x/v.mp4',
        'locked': false,
      });

      final items = pickLearningItems(
        inProgress: [video],
        content: _content([
          _lesson(id: 7, title: 'Cardiology'),
          _lesson(id: 8, title: 'Obstetrics'),
        ]),
      );

      expect(items.length, 2);
      expect(items[0].lesson.id, 7);
      expect(items[0].resumeAt, '1:35');
      // 7 is already the left card; showing it twice is the obvious bug.
      expect(items[1].lesson.id, 8);
    });

    test('a completed lesson is never "next"', () {
      final items = pickLearningItems(
        inProgress: const [],
        content: _content([
          _lesson(id: 1, completed: true),
          _lesson(id: 2, title: 'Unfinished'),
        ]),
      );

      expect(items.single.lesson.id, 2);
    });

    test('a locked lesson keeps its place but loses its url', () {
      final items = pickLearningItems(
        inProgress: const [],
        content: _content([_lesson(id: 3, locked: true, position: 40)]),
      );

      // The resume point is not the media — but a null url is what sends the
      // tap to the paywall instead of a null controller.
      expect(items.single.lesson.locked, isTrue);
      expect(items.single.lesson.videoUrl, isNull);
      expect(items.single.resumeAt, '0:40');
    });
  });
}
