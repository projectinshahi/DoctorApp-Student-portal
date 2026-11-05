import 'package:dr_app/models/selection_content_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// A lesson used to be a video. It is a container of them now, and the tier
/// is per part: Part 1 free inside a paid lesson is the sample that sells
/// the rest.
StudentLessonModel _lesson(Map<String, dynamic> json) =>
    StudentLessonModel.fromJson({
      'id': 42,
      'title': 'Pituitary gland',
      'type': 'video',
      ...json,
    });

Map<String, dynamic> _part(int id, String title,
        {bool locked = false, String access = 'free', int seconds = 600}) =>
    {
      'id': id,
      'title': title,
      'durationSeconds': seconds,
      'accessType': access,
      'locked': locked,
      'videoUrl': locked ? null : 'https://cdn.test/$id.mp4',
    };

void main() {
  test('a server without per-video access still has one part', () {
    // What every response looks like until the migration lands: no videos[],
    // just the lesson's own url and lock.
    final lesson = _lesson({'videoUrl': 'https://cdn.test/one.mp4'});

    expect(lesson.videos, isEmpty);
    expect(lesson.videoParts, hasLength(1));
    expect(lesson.videoParts.single.videoUrl, 'https://cdn.test/one.mp4');
    expect(lesson.firstOpenPart, isNotNull);
  });

  test('the free part of a paid lesson opens, the rest do not', () {
    final lesson = _lesson({
      'locked': false,
      'contentLocked': true,
      'videos': [
        _part(7, 'Part 1'),
        _part(8, 'Part 2', locked: true, access: 'premium'),
        _part(9, 'Part 3', locked: true, access: 'premium'),
      ],
    });

    expect(lesson.openPartCount, 1);
    expect(lesson.lockedPartCount, 2);
    expect(lesson.firstOpenPart!.id, 7);
    // The row says there is something to watch rather than wearing a padlock.
    expect(lesson.hasFreePreviewParts, isTrue);
    // And the quiz and notes are still behind the plan.
    expect(lesson.contentLocked, isTrue);
  });

  test('it opens on the first part that plays, not blindly on part one', () {
    final lesson = _lesson({
      'videos': [
        _part(7, 'Part 1', locked: true, access: 'premium'),
        _part(8, 'Part 2'),
      ],
    });

    expect(lesson.firstOpenPart!.id, 8);
  });

  test('every part locked is a locked lesson, and no preview chip', () {
    final lesson = _lesson({
      'locked': true,
      'videos': [
        _part(7, 'Part 1', locked: true, access: 'premium'),
        _part(8, 'Part 2', locked: true, access: 'premium'),
      ],
    });

    expect(lesson.firstOpenPart, isNull);
    expect(lesson.hasFreePreviewParts, isFalse);
  });

  test('a part unlocked with no url is not something to open', () {
    // An empty player is a worse answer than a padlock.
    final lesson = _lesson({
      'videos': [
        {'id': 7, 'title': 'Part 1', 'locked': false, 'videoUrl': null},
      ],
    });

    expect(lesson.videoParts.single.isOpen, isFalse);
    expect(lesson.firstOpenPart, isNull);
  });

  test('a part says how long it is', () {
    expect(LessonVideo.fromJson(_part(7, 'Part 1', seconds: 610)).lengthLabel,
        '10:10');
    expect(LessonVideo.fromJson(_part(8, 'Part 2', seconds: 0)).lengthLabel,
        isNull);
  });

  group('what a row shows', () {
    test('a sample lesson is open, and wears no padlock', () {
      final lesson = _lesson({
        'locked': false,
        'videos': [
          _part(7, 'Part 1'),
          _part(8, 'Part 2', locked: true, access: 'premium'),
        ],
      });

      expect(lesson.isOpen, isTrue);
      expect(lesson.hasFreePreviewParts, isTrue);
    });

    test('a lesson whose sample is part two still opens', () {
      // Its own videoUrl is part one's, which is locked and therefore null.
      final lesson = _lesson({
        'locked': false,
        'videoUrl': null,
        'videos': [
          _part(7, 'Part 1', locked: true, access: 'premium'),
          _part(8, 'Part 2'),
        ],
      });

      expect(lesson.isOpen, isTrue);
      expect(lesson.firstOpenPart!.id, 8);
    });

    test('all parts locked keeps the padlock', () {
      final lesson = _lesson({
        'locked': true,
        'videos': [_part(7, 'Part 1', locked: true, access: 'premium')],
      });

      expect(lesson.isOpen, isFalse);
      expect(lesson.hasFreePreviewParts, isFalse);
    });

    test('the quiz follows contentLocked, not the lesson', () {
      final lesson = _lesson({
        'locked': false,
        'contentLocked': true,
        'videos': [_part(7, 'Part 1')],
      });

      expect(lesson.isOpen, isTrue, reason: 'the free part plays');
      expect(lesson.contentLocked, isTrue, reason: 'the quiz does not');
    });

    test('an older response has contentLocked follow the lesson', () {
      expect(_lesson({'locked': true}).contentLocked, isTrue);
      expect(_lesson({'locked': false}).contentLocked, isFalse);
    });
  });
}
