import 'package:dr_app/models/selection_content_model.dart';
import 'package:dr_app/repository/selection_content_provider.dart';
import 'package:dr_app/services/lesson_progress_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

StudentLessonModel _lesson(Map<String, dynamic> extra) =>
    StudentLessonModel.fromJson({
      'id': 37,
      'title': 'Cardiology',
      'type': 'video',
      'displayOrder': 1,
      'isFreePreview': true,
      'accessType': 'free',
      'locked': false,
      ...extra,
    });

SelectionContentModel _content(StudentLessonModel lesson) =>
    SelectionContentModel(chapters: [
      StudentChapterModel(
        id: 1,
        title: 'Chapter 1',
        displayOrder: 1,
        lessons: [lesson],
      ),
    ]);

void main() {
  // SelectionContentProvider restores its cached tree on construction, so
  // the binding and a stub store have to exist before one is built.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('watchedPercent', () {
    test('null is "length unknown", never zero', () {
      // A bar pinned at 0% reads as "never watched" for a lesson someone is
      // halfway through, so the two cases must stay distinguishable.
      expect(_lesson({'lastPositionSeconds': 60}).watchedPercent, isNull);
      expect(_lesson({'watchedPercent': 0}).watchedPercent, 0);
    });

    test('notes and quizzes carry no percentage', () {
      final note = _lesson({'type': 'text', 'completed': true});
      expect(note.watchedPercent, isNull);
      // A quiz is still completable — off its attempt, not off a player.
      expect(note.completed, isTrue);
    });

    test('the live row shape parses whole', () {
      final lesson = _lesson({
        'completed': true,
        'watchedPercent': 10,
        'durationSeconds': 600,
        'lastPositionSeconds': 60,
      });

      // Finished, then rewound. Both are correct at once, and the tick must
      // not be derived from the 10%.
      expect(lesson.completed, isTrue);
      expect(lesson.watchedPercent, 10);
      expect(lesson.durationSeconds, 600);
      expect(lesson.lastPositionSeconds, 60);
    });
  });

  group('applyProgress', () {
    test('the tick lands without a refetch', () {
      final provider = SelectionContentProvider()
        ..content = _content(_lesson({'lastPositionSeconds': 120}));

      provider.applyProgress(const LessonProgress(
        lessonId: 37,
        completed: true,
        lastPositionSeconds: 545,
        watchedPercent: 91,
        durationSeconds: 600,
      ));

      final row = provider.content!.chapters.single.lessons.single;
      expect(row.completed, isTrue);
      expect(row.watchedPercent, 91);
      expect(row.lastPositionSeconds, 545);
    });

    test('a rewind never un-finishes a video', () {
      final provider = SelectionContentProvider()
        ..content = _content(_lesson({
          'completed': true,
          'watchedPercent': 91,
          'durationSeconds': 600,
        }));

      // The server keeps completed true after a rewind, and even if it did
      // not, the app must never clear a tick locally.
      provider.applyProgress(const LessonProgress(
        lessonId: 37,
        completed: false,
        lastPositionSeconds: 60,
        watchedPercent: 10,
        durationSeconds: 600,
      ));

      final row = provider.content!.chapters.single.lessons.single;
      expect(row.completed, isTrue, reason: 'the tick only ever turns on');
      expect(row.watchedPercent, 10);
      expect(row.lastPositionSeconds, 60);
    });

    test('progress for a lesson outside the tree changes nothing', () {
      final before = _content(_lesson({}));
      final provider = SelectionContentProvider()..content = before;

      provider.applyProgress(const LessonProgress(
        lessonId: 999,
        completed: true,
        lastPositionSeconds: 10,
      ));

      // Same instance: a deep link into an unloaded lesson must not cost a
      // rebuild of the whole outline.
      expect(identical(provider.content, before), isTrue);
    });
  });

  group('progress response', () {
    test('completed is read, never computed', () {
      // The 90% threshold is the server's. Verified against it on a 600s
      // video: 530s is false, 545s is true — the app must not try to guess
      // where the line is.
      final below = LessonProgress.fromJson({
        'lessonId': 37,
        'completed': false,
        'lastPositionSeconds': 530,
        'durationSeconds': 600,
        'watchedPercent': 88,
      });
      final above = LessonProgress.fromJson({
        'lessonId': 37,
        'completed': true,
        'lastPositionSeconds': 545,
        'durationSeconds': 600,
        'watchedPercent': 91,
      });

      expect(below.completed, isFalse);
      expect(above.completed, isTrue);
    });

    test('a response without a percentage keeps it null', () {
      final progress = LessonProgress.fromJson({
        'lessonId': 37,
        'completed': false,
        'lastPositionSeconds': 60,
      });
      expect(progress.watchedPercent, isNull);
      expect(progress.durationSeconds, isNull);
    });
  });
}
