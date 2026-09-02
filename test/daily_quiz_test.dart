import 'package:dr_app/models/daily_quiz_model.dart';
import 'package:dr_app/services/daily_quiz_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('home card summary', () {
    test('score and correctCount stay null until completed', () {
      final inProgress = DailyQuizSummary.fromJson({
        'date': '2026-09-02',
        'state': 'inProgress',
        'totalQuestions': 10,
        'answeredCount': 3,
        'correctCount': null,
        'score': null,
        'currentStreak': 4,
      });

      // Rendering a running total as "the score" would tell a student they
      // scored 2/10 when they have answered three questions.
      expect(inProgress.correctCount, isNull);
      expect(inProgress.score, isNull);
      expect(inProgress.answeredCount, 3);
    });

    test('state drives the card, not the counts', () {
      // 0 answered looks identical in both, so the numbers cannot decide.
      final fresh = DailyQuizSummary.fromJson({
        'state': 'notStarted',
        'totalQuestions': 10,
        'answeredCount': 0,
      });
      final opened = DailyQuizSummary.fromJson({
        'state': 'inProgress',
        'totalQuestions': 10,
        'answeredCount': 0,
      });

      expect(fresh.state, DailyQuizState.notStarted);
      expect(opened.state, DailyQuizState.inProgress);
    });

    test('an unknown state falls back to notStarted', () {
      // A state added server-side must not crash a shipped app.
      expect(
        DailyQuizSummary.fromJson({'state': 'archived'}).state,
        DailyQuizState.notStarted,
      );
    });

    test('nextSetAt keeps its Gulf offset', () {
      final summary = DailyQuizSummary.fromJson({
        'state': 'completed',
        'nextSetAt': '2026-09-03T00:00:00+04:00',
      });

      // Midnight +04:00 is 20:00 UTC the day before. Reading the string as
      // device-local would roll the quiz at the wrong hour.
      expect(summary.nextSetAt!.toUtc(),
          DateTime.utc(2026, 9, 2, 20, 0));
    });
  });

  group('streak', () {
    test('an unfinished today does not zero it', () {
      // The server counts back from yesterday until today is done. A student
      // opening at 9am on day 5 must see 4, not 0 — telling them their run
      // ended before breakfast is what kills the habit.
      final morning = DailyQuizSummary.fromJson({
        'state': 'notStarted',
        'answeredCount': 0,
        'currentStreak': 4,
      });
      expect(morning.currentStreak, 4);
    });
  });

  group("today's set", () {
    test('a half-done day restores its answers and reveals', () {
      final set = DailyQuizSet.fromJson({
        'date': '2026-09-02',
        'totalQuestions': 10,
        'answeredCount': 1,
        'remainingCount': 9,
        'completed': false,
        'currentStreak': 0,
        'questions': [
          {'id': 15, 'questionText': 'Q', 'options': []},
        ],
        'answers': [
          {
            'questionId': 15,
            'selectedOptionId': 268,
            'isCorrect': true,
            'marksAwarded': 2,
          },
        ],
      });

      expect(set.answers[15]!.isCorrect, isTrue);
      expect(set.answers[15]!.selectedOptionId, 268);
    });

    test('the question list carries no answer key', () {
      final set = DailyQuizSet.fromJson({
        'questions': [
          {
            'id': 15,
            'options': [
              {'id': 268, 'optionText': '24 weeks', 'displayOrder': 0},
            ],
          },
        ],
      });

      // The key exists only in the answer and finish responses. If this ever
      // parses non-null, the app is leaking it into the option list.
      expect(set.questions.single.options.single.isCorrect, isNull);
    });

    test('available:false is a state, not an error', () {
      final set = DailyQuizSet.fromJson({
        'available': false,
        'reason': 'No questions are set up for this course yet.',
        'totalQuestions': 0,
        'questions': [],
      });

      expect(set.available, isFalse);
      expect(set.reason, contains('No questions'));
    });

    test('a missing available flag means available', () {
      expect(DailyQuizSet.fromJson({'questions': []}).available, isTrue);
    });
  });

  group('result', () {
    test('skipped is its own state, scoring zero rather than the penalty', () {
      final row = DailyQuizResultRow.fromJson({
        'questionId': 15,
        'answered': false,
        'isCorrect': false,
        'marksAwarded': 0,
        'options': [],
      });

      // Painting this red would tell a student they got it wrong when they
      // deliberately left it — and wrong would have cost them marks.
      expect(row.answered, isFalse);
      expect(row.marksAwarded, 0);
    });

    test('a negative score survives', () {
      final result = DailyQuizResult.fromJson({
        'totalQuestions': 10,
        'answeredCount': 3,
        'correctCount': 0,
        'wrongCount': 3,
        'skippedCount': 7,
        'score': -1.5,
        'accuracy': 0,
        'currentStreak': 1,
        'results': [],
      });

      expect(result.score, -1.5);
    });

    test('accuracy is out of what was answered, not out of ten', () {
      final result = DailyQuizResult.fromJson({
        'totalQuestions': 10,
        'answeredCount': 1,
        'correctCount': 1,
        'skippedCount': 9,
        'score': 2,
        'accuracy': 100,
        'results': [],
      });

      // Answering one and getting it right is 100% on purpose — which is why
      // the count is shown beside it.
      expect(result.accuracy, 100);
      expect(result.answeredCount, 1);
    });
  });

  group('errors', () {
    test('409 covers already-answered and already-finished alike', () {
      expect(
        DailyQuizService.mapError(
                409, {'message': 'You have already answered this question'})
            .kind,
        DailyQuizErrorKind.alreadyDone,
      );
      expect(
        DailyQuizService.mapError(
                409, {'message': 'You have already finished today\'s quiz'})
            .kind,
        DailyQuizErrorKind.alreadyDone,
      );
    });

    test('400 is a question outside the set', () {
      expect(
        DailyQuizService.mapError(
                400, {'message': 'That question is not in today\'s set'})
            .kind,
        DailyQuizErrorKind.invalid,
      );
    });
  });

  group('history', () {
    test('missed days are present, because the gaps are the calendar', () {
      final history = DailyQuizHistory.fromJson({
        'days': 30,
        'currentStreak': 1,
        'history': [
          {'date': '2026-09-02', 'attempted': true, 'completed': true},
          {'date': '2026-09-01', 'attempted': false, 'completed': false},
        ],
      });

      expect(history.days.length, 2);
      expect(history.days.last.attempted, isFalse);
      expect(history.currentStreak, 1);
    });
  });

}
