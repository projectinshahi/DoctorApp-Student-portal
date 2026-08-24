import 'package:flutter_test/flutter_test.dart';
import 'package:dr_app/models/quiz_model.dart';
import 'package:dr_app/services/quiz_service.dart';

void main() {
  test('questions parse without an answer key and keep server order', () {
    final model = QuizQuestionsModel.fromJson({
      'lessonId': 26,
      'quiz': {'id': 11, 'title': 'ENT', 'questionCount': 1},
      'totalQuestions': 1,
      'totalMarks': 10,
      'questions': [
        {
          'id': 57,
          'questionText': 'Which lab finding confirms DKA?',
          'questionImageUrl': null,
          'difficulty': 'medium',
          'marksCorrect': 2,
          'marksIncorrect': -0.5,
          'options': [
            {'id': 764, 'optionText': 'Hyperglycemia, ketosis, acidosis', 'displayOrder': 0},
            {'id': 765, 'optionText': 'Hyperglycemia alone', 'displayOrder': 1},
          ],
        }
      ],
    });

    final q = model.questions.single;
    expect(q.marksIncorrect, -0.5); // genuine negative, never absolute
    expect(model.hasNegativeMarking, isTrue);
    expect(q.options.map((o) => o.id), [764, 765]); // not re-sorted, not shuffled
    expect(q.options.first.isCorrect, isNull); // never sent to students
  });

  test('a locked lesson parses with a null quiz and its unlock plans', () {
    final lesson = QuizLessonDetail.fromJson({
      'lesson': {'id': 26, 'title': 'ENT', 'type': 'quiz', 'quizId': 11, 'quiz': null, 'locked': true},
      'requiredPlans': [
        {'id': 3, 'title': 'Monthly', 'price': 499, 'durationDays': 30}
      ],
    });

    expect(lesson.isQuiz, isTrue);
    expect(lesson.locked, isTrue);
    expect(lesson.quiz, isNull);
    expect(lesson.requiredPlans.single.title, 'Monthly');
  });

  test('every documented failure maps to its own kind', () {
    QuizException map(int status, String message, {List? plans}) => QuizService.mapError(status, {
          'error': {'message': message},
          if (plans != null) 'requiredPlans': plans,
        });

    expect(map(409, 'Select a course before opening a lesson').kind, QuizErrorKind.noCourseSelected);
    expect(map(404, 'Lesson not found').kind, QuizErrorKind.lessonNotFound);
    expect(map(403, 'This lesson is not part of your selected course').kind, QuizErrorKind.notInCourse);
    expect(map(409, 'This lesson has no quiz linked').kind, QuizErrorKind.noQuizLinked);
    expect(map(409, 'The quiz linked to this lesson is inactive').kind, QuizErrorKind.quizInactive);

    final locked = map(403, 'This lesson is locked. Subscribe to unlock it.', plans: [
      {'id': 3, 'title': 'Monthly', 'price': 499, 'durationDays': 30}
    ]);
    expect(locked.kind, QuizErrorKind.locked);
    expect(locked.requiredPlans, isNotEmpty); // paywall needs no second call
  });
}
