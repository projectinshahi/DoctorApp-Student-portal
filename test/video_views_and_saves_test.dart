import 'package:dr_app/models/saved_model.dart';
import 'package:dr_app/models/selection_content_model.dart';
import 'package:flutter_test/flutter_test.dart';

LessonVideo _video(Map<String, dynamic> json) => LessonVideo.fromJson({
      'id': 7,
      'title': 'Part 1',
      'videoUrl': 'https://cdn.test/1.mp4',
      ...json,
    });

void main() {
  group('how a view count reads', () {
    // The design asks for "18.4k views", and the rounding is the part that
    // looks wrong first.
    test('under a thousand, as it is', () {
      expect(_video({'viewCount': 950}).viewsLabel, '950 views');
    });

    test('exactly one is singular', () {
      expect(_video({'viewCount': 1}).viewsLabel, '1 view');
    });

    test('thousands and millions are shortened', () {
      expect(_video({'viewCount': 1200}).viewsLabel, '1.2k views');
      expect(_video({'viewCount': 18400}).viewsLabel, '18.4k views');
      expect(_video({'viewCount': 1200000}).viewsLabel, '1.2M views');
    });

    test('zero says nothing rather than "0 views"', () {
      expect(_video({'viewCount': 0}).viewsLabel, isNull);
      expect(_video(const {}).viewsLabel, isNull);
    });
  });

  group('a saved video', () {
    test('the tree says which videos this student saved', () {
      expect(_video({'isSaved': true}).isSaved, isTrue);
      expect(_video(const {}).isSaved, isFalse);
    });

    test('a play updates the count without touching anything else', () {
      final before = _video({'viewCount': 10, 'isSaved': true});
      final after = before.copyWith(viewCount: 11);

      expect(after.viewCount, 11);
      expect(after.isSaved, isTrue);
      expect(after.videoUrl, before.videoUrl);
      expect(after.title, before.title);
    });
  });

  group('the saved list', () {
    test('a saved video carries the lesson it came from', () {
      // "Part 2" means nothing on its own in a list of bookmarks.
      final saved = SavedVideo.fromJson({
        'id': 7,
        'title': 'Part 2',
        'durationSeconds': 610,
        'viewCount': 18400,
        'lesson': {
          'id': 42,
          'title': 'Cardiology',
          'chapter': {'id': 3, 'title': 'Internal Medicine'},
        },
      });

      expect(saved.videoId, 7);
      expect(saved.lessonId, 42);
      expect(saved.lessonTitle, 'Cardiology');
      expect(saved.chapterTitle, 'Internal Medicine');
    });

    test('a bundle without videos is not an error', () {
      // What the server sends until the branch deploys.
      final bundle = SavedBundle.fromJson({
        'counts': {'question': 2},
        'questions': const [],
        'lessons': const [],
      });

      expect(bundle.videos, isEmpty);
    });
  });
}
