import 'package:dr_app/models/selection_content_model.dart';
import 'package:dr_app/services/lesson_progress_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records calls instead of hitting the network.
class _FakeProgressService implements LessonProgressService {
  final calls = <Map<String, Object?>>[];

  @override
  Future<void> save(int lessonId, {int? positionSeconds, bool? completed}) async {
    calls.add({'id': lessonId, 'pos': positionSeconds, 'done': completed});
  }
}

void main() {
  group('progress writer', () {
    test('a run of ticks holds one position, not one write each', () {
      final writer = LessonProgressWriter(lessonId: 7, service: _FakeProgressService());

      for (var second = 1; second <= 30; second++) {
        writer.record(second);
      }

      // Nothing sent yet; only the newest second is queued.
      expect(writer.pendingPosition, 30);
      expect(writer.lastSentPosition, isNull);
    });

    test('flush writes once, and a paused player does not rewrite it', () async {
      final service = _FakeProgressService();
      final writer = LessonProgressWriter(lessonId: 7, service: service);

      writer.record(42);
      await writer.flush();
      // A paused video keeps ticking at the same second — the writer must not
      // post it again and again for as long as it sits there.
      await writer.flush();
      await writer.flush();

      expect(service.calls, [
        {'id': 7, 'pos': 42, 'done': null},
      ]);
    });

    test('close flushes the last position on the way out', () async {
      final service = _FakeProgressService();
      final writer = LessonProgressWriter(lessonId: 7, service: service);

      writer.record(96);
      writer.close();
      await Future<void>.delayed(Duration.zero);

      expect(service.calls.single['pos'], 96);
    });
  });

  group('lesson progress fields', () {
    test('a locked lesson keeps its position even with the video stripped', () {
      // The lock strip nulls videoUrl. Reading locked:true as "no progress"
      // would lose the place of anyone who resubscribes.
      final lesson = StudentLessonModel.fromJson({
        'id': 5,
        'title': 'Cardio',
        'type': 'video',
        'locked': true,
        'videoUrl': null,
        'lastPositionSeconds': 133,
        'completed': false,
      });

      expect(lesson.locked, isTrue);
      expect(lesson.hasVideo, isFalse);
      expect(lesson.lastPositionSeconds, 133);
    });

    test('completed is read, never derived from type', () {
      final quiz = StudentLessonModel.fromJson(
          {'id': 1, 'title': 'Q', 'type': 'quiz', 'completed': true});
      final video = StudentLessonModel.fromJson(
          {'id': 2, 'title': 'V', 'type': 'video', 'completed': true});

      expect(quiz.completed, isTrue);
      expect(video.completed, isTrue);
    });

    test('an absent field falls back to never-watched, not null', () {
      final lesson =
          StudentLessonModel.fromJson({'id': 3, 'title': 'V', 'type': 'video'});

      expect(lesson.lastPositionSeconds, 0);
      expect(lesson.completed, isFalse);
    });
  });

  group('ProgressInfo', () {
    test('locked lessons stay in the denominator', () {
      final chapter = StudentChapterModel.fromJson({
        'id': 1,
        'title': 'C',
        'lessons': const [],
        'progress': {'completedLessons': 2, 'totalLessons': 10, 'percent': 20},
      });

      expect(chapter.progress!.completedLessons, 2);
      expect(chapter.progress!.totalLessons, 10);
      expect(chapter.progress!.percent, 20);
    });

    test('an absent progress block is unknown, not zero', () {
      final chapter = StudentChapterModel.fromJson(
          {'id': 1, 'title': 'C', 'lessons': const []});

      expect(chapter.progress, isNull);
    });

    test('0 of 0 is 0 percent, not a crash and not complete', () {
      final progress = ProgressInfo.maybeFrom(
          {'completedLessons': 0, 'totalLessons': 0})!;

      expect(progress.percent, 0);
      expect(progress.isComplete, isFalse);
    });

    test('the server capping at 99 keeps percent == 100 meaningful', () {
      expect(ProgressInfo.maybeFrom({'percent': 99})!.isComplete, isFalse);
      expect(ProgressInfo.maybeFrom({'percent': 100})!.isComplete, isTrue);
    });
  });
  group('module count', () {
    SelectionContentModel tree(List<Map<String, dynamic>?> progressPerChapter) =>
        SelectionContentModel.fromJson({
          // The course block counts lessons, not chapters — deliberately
          // different numbers here so a mix-up would fail this test.
          'progress': {'total': 6, 'completed': 4, 'percent': 67},
          'chapters': [
            for (var i = 0; i < progressPerChapter.length; i++)
              {
                'id': i + 1,
                'title': 'C${i + 1}',
                'lessons': const [],
                if (progressPerChapter[i] != null)
                  'progress': progressPerChapter[i],
              },
          ],
        });

    test('counts chapters at 100%, not the course lesson total', () {
      final content = tree([
        {'total': 2, 'completed': 2, 'percent': 100},
        {'total': 3, 'completed': 1, 'percent': 33},
        {'total': 1, 'completed': 1, 'percent': 100},
      ]);

      // Two chapters done. The course block says "4 completed" — of lessons.
      expect(content.completedModules, 2);
      expect(content.totalModules, 3);
      expect(content.progress!.completedLessons, 4);
    });

    test('99% is not complete', () {
      expect(tree([{'total': 10, 'completed': 9, 'percent': 99}]).completedModules, 0);
    });

    test('a chapter with no progress block counts in neither', () {
      final content = tree([null]);
      expect(content.completedModules, 0);
      expect(content.totalModules, 0);
    });
  });
}
