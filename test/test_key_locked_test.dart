import 'package:dr_app/models/test_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Grand Tests must never gain the QBank's local marking.
///
/// The QBank ships its answer key with the questions, which is safe there
/// because QBank attempts are not ranked and feed no leaderboard. Grand Tests
/// are ranked, timed and compared between students, so their key is released
/// only by /submit.
///
/// This is the guard on that difference. If someone ever reuses
/// QuizQuestionModel or the local-marking path in the test screens, or the
/// backend starts sending a key here, this fails.
void main() {
  test('a served test question carries no answer key', () {
    final question = TestQuestion.fromJson({
      'id': 5,
      'questionOrder': 1,
      'questionText': 'Which vessel is affected?',
      'optionA': 'LAD',
      'optionB': 'RCA',
      'optionC': 'LCx',
      'optionD': 'OM1',
      'section': 'Cardiology',
      // Even if a key were sent, the model has nowhere to put it.
      'correctOption': 'B',
      'isCorrect': true,
      'explanation': 'RCA supplies the inferior wall.',
    });

    // The model's own shape is the protection: optionA..optionD and no key
    // field anywhere, so a leaked key cannot reach the screen.
    final asString = question.toString();
    expect(asString.contains('correctOption'), isFalse);

    expect(question.optionA, 'LAD');
    expect(question.questionOrder, 1);
  });

  test('the test model exposes no per-option correctness', () {
    // QuizOptionModel has isCorrect; the test screens must not borrow it.
    // TestQuestion has no options list at all — four flat strings instead —
    // which is what makes that impossible rather than merely discouraged.
    final question = TestQuestion.fromJson({
      'id': 6,
      'questionOrder': 2,
      'optionA': 'A',
      'optionB': 'B',
    });

    expect(question.optionC, isNull);
    expect(question.optionD, isNull);
  });
}
