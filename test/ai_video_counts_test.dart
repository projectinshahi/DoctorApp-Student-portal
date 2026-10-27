import 'package:dr_app/models/selection_content_model.dart';
import 'package:dr_app/view/Home/dashbord/ai_video_tab.dart';
import 'package:flutter_test/flutter_test.dart';

/// What a chapter card in AI Videos counts.
///
/// It used to read the server's lesson total, which counts the quizzes too —
/// "0/4 Lessons" on a chapter whose list below it had two videos in it.
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
    expect(AiVideoTab.videosIn(chapter), hasLength(2));
  });

  test('a premium video still counts — it is listed, with its padlock', () {
    final chapter = _chapter([_video(1), _video(2, locked: true)]);

    expect(AiVideoTab.videosIn(chapter), hasLength(2));
  });

  test('the completed half is counted the same way', () {
    final chapter = _chapter([
      _video(1, completed: true),
      _quiz(2),
      _video(3),
    ]);

    final videos = AiVideoTab.videosIn(chapter);
    expect(videos.where((l) => l.completed), hasLength(1));
    expect(videos, hasLength(2));
  });

  test('a chapter with only quizzes has nothing for this tab', () {
    // Its card still shows — a published subject that disappears reads as a
    // missing subject rather than an empty one — but the pill says "No
    // lessons" instead of counting the quizzes it cannot open.
    expect(AiVideoTab.videosIn(_chapter([_quiz(1), _quiz(2)])), isEmpty);
  });

  test('a chapter with no lessons at all is still a subject', () {
    expect(AiVideoTab.videosIn(_chapter(const [])), isEmpty);
  });
}
