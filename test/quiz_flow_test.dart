import 'package:dr_app/models/quiz_model.dart';
import 'package:dr_app/repository/quiz_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _question(int id, {required int correctId}) => {
      'id': id,
      'questionText': 'Q$id',
      'marksCorrect': 2,
      'marksIncorrect': -0.5,
      'correctOptionId': correctId,
      'explanation': 'Because Q$id.',
      'options': [
        {'id': id * 10, 'optionText': 'A', 'displayOrder': 1},
        {'id': id * 10 + 1, 'optionText': 'B', 'displayOrder': 2},
      ],
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('answer key parses; correct option resolves from correctOptionId', () {
    final q = QuizQuestionModel.fromJson(_question(1, correctId: 11));
    expect(q.correctOption?.id, 11);
    expect(q.explanation, 'Because Q1.');
    expect(q.hasAnswerKey, isTrue);
  });

  test('no answer key -> no verdict, no score', () {
    final q = QuizQuestionModel.fromJson({
      'id': 9,
      'questionText': 'Q9',
      'marksCorrect': 1,
      'marksIncorrect': 0,
      'options': [
        {'id': 90, 'optionText': 'A', 'displayOrder': 1},
      ],
    });
    expect(q.correctOption, isNull);
    expect(q.hasAnswerKey, isFalse);
  });

  test('marks: one right (+2), one wrong (-0.5), one skipped (0)', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = QuizProvider();
    provider.questions = QuizQuestionsModel.fromJson({
      'lessonId': 1,
      'totalMarks': 6,
      'questions': [
        _question(1, correctId: 11), // answer right
        _question(2, correctId: 21), // answer wrong
        _question(3, correctId: 31), // skip
      ],
    });

    provider.select(1, 11);
    await provider.submitCurrent();
    provider.next();
    provider.select(2, 20);
    await provider.submitCurrent();

    expect(provider.attemptedCount, 2);
    expect(provider.skippedCount, 1);
    expect(provider.correctCount, 1);
    expect(provider.wrongCount, 1);
    expect(provider.scoredMarks, 1.5); // 2 + (-0.5)
  });

  test('a submitted answer is locked and cannot be changed', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = QuizProvider();
    provider.questions = QuizQuestionsModel.fromJson({
      'lessonId': 1,
      'questions': [_question(1, correctId: 11)],
    });

    provider.select(1, 10);
    await provider.submitCurrent();
    provider.select(1, 11); // ignored — already submitted

    expect(provider.selectedOption(1), 10);
    expect(provider.resultFor(provider.allQuestions.first), false);
  });
}
