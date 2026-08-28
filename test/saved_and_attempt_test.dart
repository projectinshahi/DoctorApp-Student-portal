// test/saved_and_attempt_test.dart
//
// The nullable fields the backend warned about. A non-nullable one here
// crashes on the first unrevealed bookmark or the first un-started quiz —
// both of which are the normal case, not an edge case.

import 'package:dr_app/models/quiz_model.dart';
import 'package:dr_app/models/saved_model.dart';
import 'package:dr_app/models/selection_content_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dr_app/repository/quiz_provider.dart';

void main() {
  group('saved question reveal gate', () {
    test('an unrevealed question parses with the whole key stripped', () {
      final question = SavedQuestion.fromJson({
        'questionId': 6,
        'questionText': 'Which virus causes this?',
        'revealed': false,
        'correctOptionId': null,
        'explanation': null,
        'marksCorrect': 2,
        'marksIncorrect': -0.5,
        'options': [
          {'id': 90, 'optionText': 'Hepatitis C', 'isCorrect': null, 'displayOrder': 0},
          {'id': 91, 'optionText': 'Hepatitis B', 'isCorrect': null, 'displayOrder': 1},
        ],
      });

      expect(question.revealed, isFalse);
      expect(question.correctOptionId, isNull);
      expect(question.explanation, isNull);
      // Null must read as "unknown", never as "wrong" — `== true` is what
      // keeps the UI from highlighting anything here.
      expect(question.options.every((o) => o.isCorrect == null), isTrue);
      expect(question.options.any((o) => o.isCorrect == true), isFalse);

      // The question itself still renders; only the answer is withheld.
      expect(question.questionText, isNotEmpty);
      expect(question.options.first.optionText, 'Hepatitis C');
    });

    test('a revealed question carries the key', () {
      final question = SavedQuestion.fromJson({
        'questionId': 2,
        'questionText': 'Inferior leads?',
        'revealed': true,
        'correctOptionId': 216,
        'explanation': 'II, III, aVF.',
        'lessonId': 38,
        'lessonTitle': 'Cardiology',
        'options': [
          {'id': 216, 'optionText': 'Inferior wall', 'isCorrect': true, 'displayOrder': 0},
          {'id': 217, 'optionText': 'Lateral wall', 'isCorrect': false, 'displayOrder': 1},
        ],
      });

      expect(question.revealed, isTrue);
      expect(question.correctOptionId, 216);
      expect(question.explanation, isNotNull);
      expect(question.options.first.isCorrect, isTrue);
      expect(question.lessonTitle, 'Cardiology');
    });

    test('count comes off the response, and falls back to the list length', () {
      final withCount = SavedQuestionsResponse.fromJson({
        'count': 12,
        'questions': [
          {'questionId': 1, 'revealed': false, 'options': []},
        ],
      });
      expect(withCount.count, 12);

      final withoutCount = SavedQuestionsResponse.fromJson({
        'questions': [
          {'questionId': 1, 'revealed': false, 'options': []},
          {'questionId': 2, 'revealed': false, 'options': []},
        ],
      });
      expect(withoutCount.count, 2);
    });
  });

  group('lesson.attempt on the content tree', () {
    test('is null on a quiz never started', () {
      final lesson = StudentLessonModel.fromJson({
        'id': 40,
        'title': 'Pulmonology',
        'type': 'quiz',
        'quizId': 21,
      });

      expect(lesson.attempt, isNull);
      expect(lesson.isQuiz, isTrue);
    });

    test('is null on a non-quiz lesson', () {
      final lesson = StudentLessonModel.fromJson({
        'id': 36,
        'title': 'Cardiology video',
        'type': 'video',
        'videoUrl': 'https://example.com/a.mp4',
      });

      expect(lesson.attempt, isNull);
    });

    test('drives the three row states', () {
      LessonAttemptInfo attempt(Map<String, dynamic> json) =>
          StudentLessonModel.fromJson({
            'id': 38,
            'type': 'quiz',
            'attempt': json,
          }).attempt!;

      final finished = attempt({
        'attemptId': 3,
        'completed': true,
        'answeredCount': 3,
        'remainingCount': 0,
        'correctCount': 2,
        'score': 3.5,
        'attemptCount': 3,
      });
      expect(finished.completed, isTrue);
      expect(finished.isInProgress, isFalse);
      expect(finished.score, 3.5);
      expect(finished.attemptCount, 3);

      final halfDone = attempt({
        'attemptId': 5,
        'completed': false,
        'answeredCount': 1,
        'remainingCount': 2,
        'attemptCount': 1,
      });
      expect(halfDone.isInProgress, isTrue);

      // Opened and abandoned without answering. Continuing it is just
      // starting it, so the row must not offer "Continue".
      final untouched = attempt({
        'attemptId': 6,
        'completed': false,
        'answeredCount': 0,
        'remainingCount': 3,
      });
      expect(untouched.isInProgress, isFalse);
    });

    test('a negative score survives as a negative', () {
      final attempt = StudentLessonModel.fromJson({
        'id': 38,
        'type': 'quiz',
        'attempt': {'attemptId': 1, 'completed': true, 'score': -1.5},
      }).attempt!;

      expect(attempt.score, -1.5);
    });
  });

  group('in-progress attempts', () {
    test('reads the rows the Continue card needs', () {
      final attempts = InProgressAttempt.listFromJson({
        'status': 'in_progress',
        'count': 1,
        'attempts': [
          {
            'attemptId': 5,
            'lessonId': 38,
            'lessonTitle': 'Cardiology',
            'chapterTitle': 'Internal Medicine',
            'answeredCount': 1,
            'totalQuestions': 3,
            'startedAt': '2026-08-28T09:45:39.671Z',
          },
        ],
      });

      final row = attempts.single;
      expect(row.lessonId, 38);
      expect(row.lessonTitle, 'Cardiology');
      expect(row.remainingCount, 2);
      expect(row.startedAt, isNotNull);
    });

    test('an empty list is a legal answer, not a failure', () {
      expect(
        InProgressAttempt.listFromJson({
          'status': 'in_progress',
          'count': 0,
          'attempts': [],
        }),
        isEmpty,
      );
    });
  });

  group('one attempt per quiz', () {
    QuizAttemptSummary row({required int id, required bool completed}) =>
        QuizAttemptSummary.fromJson({
          'attemptId': id,
          'completed': completed,
          'totalQuestions': 3,
          'answeredCount': completed ? 3 : 0,
          'correctCount': completed ? 1 : 0,
          'score': completed ? 0.5 : 0,
        });

    test('finds the completed attempt under an abandoned empty one', () {
      // Newest first, exactly as the API sends it: #4 was opened and closed
      // without answering anything, on top of the finished #3.
      final history = [
        row(id: 4, completed: false),
        row(id: 3, completed: true),
      ];

      expect(QuizProvider.firstCompleted(history)?.attemptId, 3);
    });

    test('null when nothing has ever been finished', () {
      expect(QuizProvider.firstCompleted([row(id: 1, completed: false)]), isNull);
      expect(QuizProvider.firstCompleted(const []), isNull);
    });
  });

  group('disposed provider', () {
    test('notifying a disposed provider is a no-op, not a crash', () {
      final provider = QuizProvider();
      var rebuilds = 0;
      provider.addListener(() => rebuilds++);

      provider.dispose();

      // What an in-flight load() does when the student has already left the
      // quiz screen. Before the guard this threw and took down the isolate.
      expect(provider.notifyListeners, returnsNormally);
      expect(rebuilds, 0);
    });
  });
}
