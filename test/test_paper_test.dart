import 'package:dr_app/models/quiz_model.dart' show QuizErrorKind, QuizException;
import 'package:dr_app/models/test_model.dart';
import 'package:dr_app/repository/test_provider.dart';
import 'package:dr_app/services/test_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _ExpiredService extends TestService {
  bool fetchedResult = false;

  @override
  Future<TestResult> submit(int attemptId) async =>
      throw QuizException(QuizErrorKind.attemptFinished,
          'Time is up. This attempt was submitted automatically.');

  @override
  Future<TestResult> fetchResult(int attemptId) async {
    fetchedResult = true;
    return TestResult.fromJson({
      'attemptId': attemptId,
      'testId': 1,
      'score': 0.75,
      'totalQuestions': 2,
      'correctCount': 1,
      'wrongCount': 1,
      'skippedCount': 0,
      'timeTakenSeconds': 232,
      'results': const [],
    });
  }

  @override
  Future<Leaderboard> fetchLeaderboard(int testId, {int limit = 50}) async =>
      throw QuizException(QuizErrorKind.network, 'no leaderboard');
}

void main() {
  group('test list', () {
    TestSummary summary(Map<String, dynamic>? lastAttempt) =>
        TestSummary.fromJson({
          'id': 1,
          'name': 'Grand Test 1',
          'type': 'GRAND_TEST',
          'totalQuestions': 2,
          'durationMinutes': 30,
          'marksCorrect': 1,
          'marksIncorrect': -0.25,
          'attemptCount': lastAttempt == null ? 0 : 1,
          if (lastAttempt != null) 'lastAttempt': lastAttempt,
        });

    test('lastAttempt alone decides Start / Resume / View result', () {
      expect(summary(null).isInProgress, isFalse);
      expect(summary(null).isSubmitted, isFalse);

      final resuming = summary({'attemptId': 2, 'submittedAt': null, 'inProgress': true});
      expect(resuming.isInProgress, isTrue);
      expect(resuming.isSubmitted, isFalse);

      final done = summary({
        'attemptId': 1,
        'submittedAt': '2026-08-29T10:00:00.000Z',
        'score': 1,
        'inProgress': false,
      });
      expect(done.isSubmitted, isTrue);
      expect(done.isInProgress, isFalse);
    });

    test('negative marking is kept negative for the card warning', () {
      expect(summary(null).marksIncorrect, -0.25);
      expect(summary(null).hasNegativeMarking, isTrue);
    });
  });

  group('attempt', () {
    Map<String, dynamic> payload({
      required bool resumed,
      required int secondsRemaining,
      List<Map<String, dynamic>> answered = const [],
    }) =>
        {
          'attemptId': 1,
          'resumed': resumed,
          'test': {
            'id': 1,
            'name': 'Grand Test 1',
            'totalQuestions': 2,
            'durationMinutes': 30,
            'marksCorrect': 1,
            'marksIncorrect': -0.25,
          },
          'secondsRemaining': secondsRemaining,
          'answered': answered,
          'questions': [
            {
              'id': 1,
              'questionOrder': 1,
              'questionText': null,
              'questionImageUrl': 'https://cdn/ecg.png',
              'optionA': 'Afib',
              'optionB': 'Sinus',
              'optionC': null,
              'optionD': null,
            },
          ],
        };

    test('the clock comes from secondsRemaining, not durationMinutes', () {
      // A resumed paper has less time left. Reading durationMinutes would
      // hand out a fresh 30 minutes on every reopen.
      final attempt = TestAttempt.fromJson(payload(resumed: true, secondsRemaining: 240));

      expect(attempt.secondsRemaining, 240);
      expect(attempt.durationMinutes, 30);
    });

    test('a resumed attempt restores the answers already given', () {
      final attempt = TestAttempt.fromJson(payload(
        resumed: true,
        secondsRemaining: 900,
        answered: [
          {'testQuestionId': 1, 'selectedOption': 'B'},
        ],
      ));

      expect(attempt.resumed, isTrue);
      expect(attempt.answered[1], 'B');
    });

    test('a question can be an image with no text, and offer fewer than four options', () {
      final question =
          TestAttempt.fromJson(payload(resumed: false, secondsRemaining: 1800)).questions.single;

      expect(question.questionText, isNull);
      expect(question.questionImageUrl, isNotNull);
      // C and D are absent — an option with neither text nor image is not one.
      expect(question.letters, ['A', 'B']);
    });
  });

  group('result', () {
    test('skipped is its own outcome, not a wrong answer', () {
      final result = TestResult.fromJson({
        'score': 1,
        'totalMarks': 2,
        'timeTakenSeconds': 39,
        'correctCount': 1,
        'wrongCount': 0,
        'skippedCount': 1,
        'results': [
          {'selectedOption': 'A', 'correctOption': 'A', 'isCorrect': true, 'answered': true, 'marksAwarded': 1},
          {'selectedOption': null, 'correctOption': 'C', 'isCorrect': false, 'answered': false, 'marksAwarded': 0},
        ],
      });

      final skipped = result.results.last;
      expect(skipped.answered, isFalse);
      expect(skipped.isCorrect, isFalse);
      // Zero, not the -0.25 a wrong answer would cost.
      expect(skipped.marksAwarded, 0);
    });

    test('a negative mark survives as negative', () {
      final result = TestResult.fromJson({
        'score': -0.25,
        'totalMarks': 2,
        'results': [
          {'selectedOption': 'B', 'correctOption': 'A', 'isCorrect': false, 'answered': true, 'marksAwarded': -0.25},
        ],
      });

      expect(result.score, -0.25);
      expect(result.results.single.marksAwarded, -0.25);
    });
  });

  group('leaderboard', () {
    test('me is separate, and ranks come from the server', () {
      final board = Leaderboard.fromJson({
        'totalParticipants': 2,
        'me': {'rank': 2, 'name': 'Keerthana', 'score': 1, 'correctCount': 1, 'timeTakenSeconds': 39},
        'entries': [
          {'rank': 1, 'name': 'Theertha', 'score': 2, 'correctCount': 2, 'timeTakenSeconds': 8},
        ],
      });

      expect(board.me!.rank, 2);
      expect(board.entries.single.rank, 1);
      // Not in the top slice, so the pinned row is needed.
      expect(board.meIsListed, isFalse);
    });

    test('a tie shares a rank and the next one skips', () {
      final board = Leaderboard.fromJson({
        'totalParticipants': 3,
        'entries': [
          {'rank': 1, 'name': 'A', 'score': 2},
          {'rank': 1, 'name': 'B', 'score': 2},
          {'rank': 3, 'name': 'C', 'score': 1},
        ],
      });

      // Rendering a row index here would show 1, 2, 3 and invent a winner.
      expect(board.entries.map((e) => e.rank), [1, 1, 3]);
    });
  });

  test('clearing an answer does not stop the clock', () {
    // The live DELETE reply, verbatim — it carries no secondsRemaining.
    final cleared = TestAnswerResponse.fromJson({
      'attemptId': 4,
      'testQuestionId': 1,
      'cleared': true,
      'answeredCount': 0,
      'remainingCount': 2,
    });

    // Absent means "unchanged", not "expired". Reading it as 0 stopped the
    // countdown and locked the student out of a paper with 29 minutes left.
    expect(cleared.secondsRemaining, isNull);

    expect(
      TestAnswerResponse.fromJson({
        'answeredCount': 1,
        'remainingCount': 1,
        'secondsRemaining': 1779,
      }).secondsRemaining,
      1779,
    );
  });

  test('a paper the server already expired still reaches its result', () {
    // Expiry is lazy: the server closes the attempt on the next request that
    // touches it, so our submit can arrive after it has already been marked.
    // The 409 that comes back is the same outcome, not a failure.
    final service = _ExpiredService();
    final provider = TestProvider(service: service)
      ..attempt = TestAttempt(
        attemptId: 4,
        resumed: true,
        testId: 1,
        testName: 'Grand Test 1',
        totalQuestions: 2,
        durationMinutes: 30,
        marksCorrect: 1,
        marksIncorrect: -0.25,
        secondsRemaining: 0,
        answered: const {},
        questions: const [],
      );

    return provider.submit().then((ok) {
      expect(ok, isTrue, reason: 'a 409 here must not read as a failed submit');
      expect(service.fetchedResult, isTrue);
      expect(provider.result?.score, 0.75);
      expect(provider.actionError, isNull);
    });
  });

  test('a submitted test offers no retake', () {
    final tests = TestSummary.listFromJson({
      'tests': [
        {
          'id': 1,
          'name': 'Grand Test 1',
          'totalQuestions': 2,
          'durationMinutes': 30,
          'marksCorrect': 1,
          'marksIncorrect': -0.25,
          'attemptCount': 2,
          'lastAttempt': {
            'attemptId': 4,
            'startedAt': '2026-08-31T10:36:06.473Z',
            'submittedAt': '2026-08-31T10:39:58.487Z',
            'score': 0.75,
            'inProgress': false,
          },
        },
      ],
    });

    // One sitting per test: submitted is terminal. If this ever reads as
    // "not submitted", the card grows a Start button and the leaderboard
    // stops meaning anything.
    expect(tests.single.isSubmitted, isTrue);
    expect(tests.single.isInProgress, isFalse);
    expect(tests.single.secondsLeftOnAttempt, isNull,
        reason: 'a finished paper has no clock left to run');
  });

  test('a running attempt derives its own deadline', () {
    // The list endpoint sends startedAt but no secondsRemaining, so the card
    // does the same arithmetic the server does: startedAt + durationMinutes.
    final startedAt =
        DateTime.now().toUtc().subtract(const Duration(minutes: 10));
    final tests = TestSummary.listFromJson({
      'tests': [
        {
          'id': 1,
          'name': 'Grand Test 1',
          'totalQuestions': 2,
          'durationMinutes': 30,
          'marksCorrect': 1,
          'marksIncorrect': -0.25,
          'attemptCount': 1,
          'lastAttempt': {
            'attemptId': 4,
            'startedAt': startedAt.toIso8601String(),
            'score': null,
            'inProgress': true,
          },
        },
      ],
    });

    // 30 minutes allotted, 10 gone: about 20 left, never the full duration.
    final left = tests.single.secondsLeftOnAttempt;
    expect(left, isNotNull);
    expect(left, closeTo(20 * 60, 5));
  });

  test('an abandoned paper past its deadline reports zero, not negative', () {
    final tests = TestSummary.listFromJson({
      'tests': [
        {
          'id': 3,
          'name': 'Grand Test 2',
          'totalQuestions': 2,
          'durationMinutes': 20,
          'marksCorrect': 1,
          'marksIncorrect': -0.25,
          'attemptCount': 1,
          'lastAttempt': {
            'attemptId': 2,
            'startedAt': '2026-08-29T07:03:56.813Z',
            'score': null,
            'inProgress': true,
          },
        },
      ],
    });

    // Days late. A negative number would render as "Resume - -1:-2:-3".
    expect(tests.single.secondsLeftOnAttempt, 0);
  });


  test('the marked paper sums to the number of questions', () {
    final result = TestResult.fromJson({
      'attemptId': 4,
      'score': 0.75,
      'totalMarks': 2,
      'timeTakenSeconds': 232,
      'correctCount': 1,
      'wrongCount': 1,
      'skippedCount': 0,
      'results': const [],
    });

    // The gauges divide by this. Taking it from results.length instead would
    // read 0 here and draw three empty rings on a scored paper.
    expect(result.totalQuestions, 2);
  });
}
