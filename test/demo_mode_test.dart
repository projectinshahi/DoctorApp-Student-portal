import 'package:dr_app/core/demo/demo_content.dart';
import 'package:dr_app/models/daily_quiz_model.dart';
import 'package:dr_app/models/home_summary_model.dart';
import 'package:dr_app/models/selection_content_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// The preview is the real screens reading sample content, so the sample has
/// to parse exactly as a server response does. If a model ever stops
/// accepting it, the preview breaks before anyone opens the app.
void main() {
  tearDown(DemoMode.reset);

  test('the sample course tree parses as a real one', () {
    final content = SelectionContentModel.fromJson(DemoContent.courseTree);

    expect(content.course?.title, 'GP Gulf Licensing Exam');
    expect(content.chapters, hasLength(2));
    expect(content.chapters.first.lessons, hasLength(3));
  });

  test('the sample shows both a free lesson and a locked one', () {
    // A preview where everything is open says nothing about what a plan buys;
    // one where everything is locked shows nothing at all.
    final lessons = SelectionContentModel.fromJson(DemoContent.courseTree)
        .chapters
        .expand((c) => c.lessons);

    expect(lessons.where((l) => l.isOpen), isNotEmpty);
    expect(lessons.where((l) => !l.isOpen), isNotEmpty);
  });

  test('the sample day has a question that can be read', () {
    final set = DailyQuizSet.fromJson(DemoContent.dailyQuiz);

    expect(set.available, isTrue);
    expect(set.questions, isNotEmpty);
    expect(set.questions.first.options, hasLength(4));
  });

  test('the sample home summary carries the daily quiz', () {
    final home = HomeSummary.fromJson(DemoContent.homeSummary);

    expect(home.dailyQuiz, isNotNull);
    expect(home.dailyQuiz!.totalQuestions, 10);
    // Nothing in progress: there is no student to have started anything.
    expect(home.inProgressVideos, isEmpty);
  });

  test('the preview is off unless it is switched on', () {
    expect(DemoMode.active, isFalse);
  });
}
