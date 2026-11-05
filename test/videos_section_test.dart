import 'package:dr_app/models/selection_content_model.dart';
import 'package:dr_app/view/Home/dashbord/videos_subjects_screen.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the video section lists under a chapter.
///
/// Videos and notes, never quizzes — those live in QBank. A chapter card
/// used to read the server's lesson total, which counts the quizzes too:
/// "0/4 Lessons" above a list of two videos.
StudentChapterModel _chapter(List<Map<String, dynamic>> lessons) =>
    StudentChapterModel.fromJson({
      'id': 31,
      'title': 'Internal Medicine',
      'progress': {'completedLessons': 0, 'totalLessons': lessons.length},
      'lessons': lessons,
    });

Map<String, dynamic> _video(int id,
        {bool completed = false, bool locked = false}) =>
    {
      'id': id,
      'title': 'Video $id',
      'type': 'video',
      'locked': locked,
      'completed': completed,
      if (!locked) 'videoUrl': 'https://cdn.test/$id.mp4',
    };

Map<String, dynamic> _quiz(int id) =>
    {'id': id, 'title': 'Quiz $id', 'type': 'quiz', 'questionCount': 20};

void main() {
  test('the card counts videos, not the quizzes beside them', () {
    final chapter = _chapter([
      _video(1),
      _quiz(2),
      _quiz(3),
      _video(4),
    ]);

    // Four lessons in the chapter; two of them belong on this tab.
    expect(chapter.lessons, hasLength(4));
    expect(VideosSubjectsScreen.subjectsIn(chapter), hasLength(2));
  });

  test('a premium video still counts — it is listed, with its padlock', () {
    final chapter = _chapter([_video(1), _video(2, locked: true)]);

    expect(VideosSubjectsScreen.subjectsIn(chapter), hasLength(2));
  });

  test('the completed half is counted the same way', () {
    final chapter = _chapter([
      _video(1, completed: true),
      _quiz(2),
      _video(3),
    ]);

    final videos = VideosSubjectsScreen.subjectsIn(chapter);
    expect(videos.where((l) => l.completed), hasLength(1));
    expect(videos, hasLength(2));
  });

  test('a chapter with only quizzes has nothing for this tab', () {
    // Its card still shows — a published subject that disappears reads as a
    // missing subject rather than an empty one — but the pill says "No
    // lessons" instead of counting the quizzes it cannot open.
    expect(VideosSubjectsScreen.subjectsIn(_chapter([_quiz(1), _quiz(2)])), isEmpty);
  });

  test('a chapter with no lessons at all is still a subject', () {
    expect(VideosSubjectsScreen.subjectsIn(_chapter(const [])), isEmpty);
  });

  group('a subject card', () {
    test('counts the videos inside the lesson, not the lessons', () {
      // The design asks for "Cardiology · 8 Videos", and a lesson is a
      // container of videos now.
      final subject = StudentLessonModel.fromJson({
        'id': 1,
        'title': 'Cardiology',
        'type': 'video',
        'videos': [
          {'id': 1, 'title': 'Part 1', 'videoUrl': 'https://cdn.test/1.mp4'},
          {'id': 2, 'title': 'Part 2', 'videoUrl': 'https://cdn.test/2.mp4'},
          {'id': 3, 'title': 'Part 3', 'locked': true},
        ],
      });

      expect(VideosSubjectsScreen.videoCount(subject), 3);
    });

    test('a lesson the server still sends as one video counts as one', () {
      final subject = StudentLessonModel.fromJson({
        'id': 1,
        'title': 'Cardiology',
        'type': 'video',
        'videoUrl': 'https://cdn.test/one.mp4',
      });

      expect(VideosSubjectsScreen.videoCount(subject), 1);
    });
  });
}
