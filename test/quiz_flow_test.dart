// test/quiz_flow_test.dart
//
// The three rules from the API contract that silently break the UI if missed.
// Parsing only — no network, no widgets.

import 'package:dr_app/models/quiz_model.dart';
import 'package:dr_app/services/quiz_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('start response', () {
    // Rule 1: isCorrect must be nullable. It is absent on start and present
    // on answer/finish; a required field crashes here.
    test('parses with no answer key on any option', () {
      final attempt = QuizAttempt.fromJson({
        'attemptId': 1,
        'resumed': false,
        'lessonId': 38,
        'quiz': {'id': 20, 'title': 'Cardiology'},
        'totalQuestions': 3,
        'totalMarks': 6,
        'answered': [],
        'questions': [
          {
            'id': 2,
            'questionText': 'Which leads are inferior?',
            'difficulty': 'medium',
            'marksCorrect': 2,
            'marksIncorrect': -0.5,
            'options': [
              {'id': 216, 'optionText': 'Inferior wall', 'displayOrder': 0},
              {'id': 217, 'optionText': 'Lateral wall', 'displayOrder': 1},
            ],
          },
        ],
      });

      expect(attempt.attemptId, 1);
      expect(attempt.resumed, isFalse);
      expect(attempt.completed, isFalse);
      expect(attempt.review, isNull);
      // The QBank now ships the key, but this fixture is a payload without
      // one — correctOptionId is what says so. isCorrect is false-by-default
      // and so cannot distinguish "withheld" from "wrong".
      expect(attempt.questions.single.correctOptionId, isNull);
      expect(attempt.questions.single.options.any((o) => o.isCorrect), isFalse);
      expect(attempt.answeredCount, 0);
      expect(attempt.remainingCount, 3);
      expect(attempt.hasNegativeMarking, isTrue);
    });

    test('resumed attempt restores the earlier picks', () {
      final attempt = QuizAttempt.fromJson({
        'attemptId': 7,
        'resumed': true,
        'totalQuestions': 3,
        'answered': [
          {'questionId': 2, 'optionId': 216},
        ],
        'questions': const [],
      });

      expect(attempt.resumed, isTrue);
      expect(attempt.answered[2], 216);
      expect(attempt.answeredIds, {2});
      expect(attempt.remainingCount, 2);
    });

    // The contract pins the field name but not the element shape. Bare ids
    // must still mark the question answered, or a resumed student is asked
    // to redo work the server has already recorded.
    test('bare ids in `answered` still count as answered', () {
      final attempt = QuizAttempt.fromJson({
        'attemptId': 7,
        'totalQuestions': 3,
        'answered': [2, 5],
        'questions': const [],
      });

      expect(attempt.answeredIds, {2, 5});
      expect(attempt.answered, isEmpty); // no optionId to restore
      expect(attempt.answeredCount, 2);
    });
  });

  group('answer response', () {
    test('carries the key, the explanation and the option flags', () {
      final response = QuizAnswerResponse.fromJson({
        'answeredCount': 1,
        'remainingCount': 2,
        'result': {
          'questionId': 2,
          'selectedOptionId': 216,
          'correctOptionId': 216,
          'isCorrect': true,
          'answered': true,
          'marksAwarded': 2,
          'explanation': 'II, III, aVF are the inferior leads.',
          'options': [
            {'id': 216, 'optionText': 'Inferior wall', 'isCorrect': true},
            {'id': 217, 'optionText': 'Lateral wall', 'isCorrect': false},
          ],
        },
      });

      expect(response.remainingCount, 2);
      expect(response.result.isCorrect, isTrue);
      expect(response.result.correctOption?.optionText, 'Inferior wall');
      expect(response.result.explanation, isNotNull);
    });
  });

  group('finish response', () {
    // Rule 3: skipped is not wrong. It scores 0 with no penalty, so the two
    // states must stay distinguishable.
    test('separates correct, wrong and skipped, and keeps negatives signed', () {
      final result = QuizAttemptResult.fromJson({
        'score': 1.5,
        'totalMarks': 6,
        'totalQuestions': 3,
        'correctCount': 1,
        'wrongCount': 1,
        'skippedCount': 1,
        'startedAt': '2026-08-28T10:00:00.000Z',
        'completedAt': '2026-08-28T10:05:00.000Z',
        'results': [
          {
            'questionId': 1,
            'selectedOptionId': 10,
            'correctOptionId': 10,
            'isCorrect': true,
            'answered': true,
            'marksAwarded': 2,
          },
          {
            'questionId': 2,
            'selectedOptionId': 20,
            'correctOptionId': 21,
            'isCorrect': false,
            'answered': true,
            'marksAwarded': -0.5,
          },
          {
            'questionId': 3,
            'selectedOptionId': null,
            'correctOptionId': 31,
            'isCorrect': false,
            'answered': false,
            'marksAwarded': 0,
          },
        ],
      });

      final correct = result.forQuestion(1)!;
      final wrong = result.forQuestion(2)!;
      final skipped = result.forQuestion(3)!;

      expect(correct.isCorrect, isTrue);

      expect(wrong.isCorrect, isFalse);
      expect(wrong.isSkipped, isFalse);
      expect(wrong.marksAwarded, -0.5); // signed, never absolute

      expect(skipped.isSkipped, isTrue);
      expect(skipped.selectedOptionId, isNull);
      expect(skipped.marksAwarded, 0); // no penalty

      expect(result.completedAt, isNotNull);
    });

    test('a completed GET exposes the same review inline', () {
      final attempt = QuizAttempt.fromJson({
        'attemptId': 1,
        'completed': true,
        'score': 1.5,
        'totalMarks': 6,
        'totalQuestions': 3,
        'correctCount': 1,
        'wrongCount': 1,
        'skippedCount': 1,
        'results': [
          {
            'questionId': 1,
            'correctOptionId': 10,
            'isCorrect': true,
            'answered': true,
            'marksAwarded': 2,
          },
        ],
      });

      expect(attempt.completed, isTrue);
      expect(attempt.review?.score, 1.5);
      expect(attempt.review?.forQuestion(1)?.isCorrect, isTrue);
    });
  });

  group('history', () {
    test('reads summary rows and leaves server order alone', () {
      final attempts = QuizAttemptSummary.listFromJson({
        'attempts': [
          {
            'attemptId': 3,
            'completed': false,
            'totalQuestions': 3,
            'answeredCount': 1,
            'correctCount': 0,
            'score': 0,
          },
          {
            'attemptId': 1,
            'completed': true,
            'totalQuestions': 3,
            'answeredCount': 2,
            'correctCount': 1,
            'score': 1.5,
          },
        ],
      });

      expect(attempts.map((a) => a.attemptId), [3, 1]); // newest first, untouched
      expect(attempts.first.completed, isFalse);
      expect(attempts.last.score, 1.5);
    });
  });

  group('error mapping', () {
    test('the 409s that need their own screen are told apart', () {
      QuizErrorKind kindOf(int status, String message) =>
          QuizService.mapError(status, {
            'error': {'message': message},
          }).kind;

      expect(kindOf(409, 'This quiz has no questions yet'), QuizErrorKind.noQuestions);
      expect(kindOf(409, 'No quiz linked to this lesson'), QuizErrorKind.noQuizLinked);
      expect(kindOf(409, 'This attempt is already finished'), QuizErrorKind.attemptFinished);
      expect(kindOf(404, 'Attempt not found'), QuizErrorKind.attemptNotFound);
      expect(kindOf(404, 'Lesson not found'), QuizErrorKind.lessonNotFound);
      expect(kindOf(500, ''), QuizErrorKind.serverError);
    });

    test('403 with plans is the paywall, without is the wrong course', () {
      final locked = QuizService.mapError(403, {
        'error': {'message': 'Lesson locked'},
        'requiredPlans': [
          {'id': 1, 'title': 'Pro', 'price': 600, 'durationDays': 30},
        ],
      });
      expect(locked.kind, QuizErrorKind.locked);
      expect(locked.requiredPlans.single.price, 600);

      expect(
        QuizService.mapError(403, {
          'error': {'message': 'Not your course'},
        }).kind,
        QuizErrorKind.notInCourse,
      );
    });
  });
}
