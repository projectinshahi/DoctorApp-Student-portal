import 'dart:async';
import 'package:dr_app/models/quiz_model.dart';
import 'package:dr_app/models/selection_content_model.dart';
import 'package:dr_app/repository/quiz_provider.dart';
import 'package:dr_app/services/quiz_service.dart';
import 'package:dr_app/view/Home/Qbank/quiz_screen.dart';
import 'package:flutter_test/flutter_test.dart';

/// Counts the calls that opening a quiz makes.
///
/// The count is the point: this used to be a history fetch followed by
/// startAttempt — two round trips in a row before a single question appeared.
class _Service extends QuizService {
  int historyCalls = 0;
  int startCalls = 0;
  int fetchCalls = 0;

  /// What the server would say the history is, if anyone asked.
  List<Map<String, dynamic>> history = const [];

  @override
  Future<List<QuizAttemptSummary>> fetchHistory(int lessonId) async {
    historyCalls++;
    if (historyGate != null) await historyGate!.future;
    return history.map(QuizAttemptSummary.fromJson).toList();
  }

  /// Serve the keyed shape instead, to exercise the instant-reveal path.
  bool keyed = false;

  /// Held open to freeze the answer POST mid-flight.
  Completer<void>? answerGate;
  int answerCalls = 0;

  /// Make the next [failCount] saves fail, as a flaky network would.
  int failCount = 0;

  /// Held open to freeze the history fetch, which must not gate the review.
  Completer<void>? historyGate;

  /// The id the next started attempt gets — a retake is a new attempt.
  int? nextAttemptId;

  @override
  Future<QuizAttempt> startAttempt(int lessonId) async {
    startCalls++;
    final base = keyed ? _keyedAttempt : _attempt;
    return QuizAttempt.fromJson(
        nextAttemptId == null ? base : {...base, 'attemptId': nextAttemptId});
  }

  @override
  Future<QuizAttemptResult> finishAttempt(int attemptId) async =>
      QuizAttemptResult.fromJson({
        'attemptId': attemptId,
        'totalQuestions': 1,
        'attemptedCount': 1,
        'correctCount': 1,
        'score': 1.0,
        'results': const [],
      });

  @override
  Future<QuizAnswerResponse> answerQuestion(int attemptId,
      {required int questionId, required int optionId}) async {
    answerCalls++;
    if (answerGate != null) await answerGate!.future;
    if (failCount > 0) {
      failCount--;
      throw QuizException(QuizErrorKind.network, 'offline');
    }
    return QuizAnswerResponse.fromJson({
      'answeredCount': 1,
      'remainingCount': 0,
      'result': {
        'questionId': questionId,
        'questionText': 'Q1',
        'selectedOptionId': optionId,
        'correctOptionId': 10,
        'isCorrect': optionId == 10,
        'answered': true,
        'marksAwarded': optionId == 10 ? 1.0 : -0.25,
        'explanation': 'Because A.',
        'options': const [],
      },
    });
  }

  @override
  Future<QuizAttempt> fetchAttempt(int attemptId) async {
    fetchCalls++;
    return QuizAttempt.fromJson(_attempt);
  }
}

const _attempt = {
  'attemptId': 7,
  'resumed': false,
  'questions': [
    {
      'id': 1,
      'questionText': 'Q1',
      'marksCorrect': 1.0,
      'marksIncorrect': -0.25,
      'options': [
        {'id': 10, 'optionText': 'A'},
        {'id': 11, 'optionText': 'B'},
      ],
    },
  ],
  'answered': <String, dynamic>{},
};

/// The same attempt, but with the key on every option — what the server
/// sends if it ships the answer alongside the question.
const _keyedAttempt = {
  'attemptId': 7,
  'resumed': false,
  'questions': [
    {
      'id': 1,
      'questionText': 'Q1',
      'marksCorrect': 1.0,
      'marksIncorrect': -0.25,
      'correctOptionId': 10,
      'explanation': 'Because A.',
      'options': [
        {'id': 10, 'optionText': 'A', 'isCorrect': true},
        {'id': 11, 'optionText': 'B', 'isCorrect': false},
      ],
    },
  ],
  'answered': <String, dynamic>{},
};

LessonAttemptInfo _info({required bool completed}) =>
    LessonAttemptInfo.fromJson({
      'attemptId': 7,
      'completed': completed,
      'answeredCount': completed ? 1 : 0,
      'remainingCount': 0,
      'correctCount': 1,
      'score': 1,
      'attemptCount': 1,
    });

void main() {
  group('opening a quiz costs one call when the tree already knows', () {
    test('never attempted goes straight to startAttempt', () async {
      final service = _Service();
      await QuizProvider(service: service).load(1, treeKnows: true);

      expect(service.historyCalls, 0, reason: 'the tree already answered this');
      expect(service.startCalls, 1);
    });

    test('an unfinished attempt resumes, still without the history fetch',
        () async {
      final service = _Service();
      await QuizProvider(service: service)
          .load(1, known: _info(completed: false), treeKnows: true);

      expect(service.historyCalls, 0);
      expect(service.startCalls, 1);
    });

    test('a finished attempt reopens as a review and starts nothing',
        () async {
      // The important half. startAttempt on a finished quiz does not fail —
      // it opens attempt #2 — so this path must never reach it.
      final service = _Service();
      final provider = QuizProvider(service: service);
      await provider.load(1, known: _info(completed: true), treeKnows: true);

      expect(service.startCalls, 0, reason: 'that would be attempt #2');
      expect(service.fetchCalls, 1);
      expect(provider.finished, isTrue);
    });
  });

  group('without tree data the careful path still runs', () {
    test('the history is checked before anything is started', () async {
      final service = _Service();
      await QuizProvider(service: service).load(1);

      expect(service.historyCalls, 1);
      expect(service.startCalls, 1);
    });

    test('a finished attempt found in the history opens as a review', () async {
      final service = _Service()
        ..history = [
          {'attemptId': 7, 'completed': true},
        ];
      final provider = QuizProvider(service: service);
      await provider.load(1);

      expect(service.startCalls, 0);
      expect(provider.finished, isTrue);
    });
  });

  group('answer checking', () {
    test('with the key on the question the verdict is instant', () async {
      // POST .../answers measured 3254ms on device. When the key is already
      // here there is nothing to wait for.
      final gate = Completer<void>();
      final service = _Service()
        ..keyed = true
        ..answerGate = gate;
      final provider = QuizProvider(service: service);
      await provider.load(1, treeKnows: true);

      // Returns without touching the network — awaiting it does not block,
      // because the POST is detached.
      await provider.answer(1, 11);
      expect(provider.isChecking(provider.questions.first.id), isFalse);
      expect(provider.resultFor(provider.questions.first)?.isCorrect, isFalse);
      // Already-negative marks must not be flipped into a reward.
      expect(provider.resultFor(provider.questions.first)?.marksAwarded, -0.25);

      // Let the detached POST land, then confirm the server's row replaced
      // the local one — same verdict, but with its counts and explanation.
      gate.complete();
      await Future<void>.delayed(Duration.zero);

      expect(service.answerCalls, 1);
      expect(provider.resultFor(provider.questions.first)?.explanation, 'Because A.');
    });

    test('without the key it waits, rather than guessing', () async {
      final gate = Completer<void>();
      final service = _Service()..answerGate = gate;
      final provider = QuizProvider(service: service);
      await provider.load(1, treeKnows: true);

      final pending = provider.answer(1, 11);
      expect(provider.isChecking(1), isTrue);
      expect(provider.resultFor(provider.questions.first), isNull);

      gate.complete();
      await pending;
      expect(provider.isChecking(1), isFalse);
    });
  });

  group('a save that fails is queued, not lost', () {
    test('the student keeps their answer and the write retries', () async {
      // With the key local, the reveal already happened — the student has
      // moved on. Telling them to "tap again" is useless, because the
      // question now counts as answered and re-tapping is blocked.
      final service = _Service()
        ..keyed = true
        ..failCount = 1;
      final provider = QuizProvider(service: service);
      await provider.load(1, treeKnows: true);

      await provider.answer(1, 10);

      expect(provider.resultFor(provider.questions.first)?.isCorrect, isTrue,
          reason: 'the verdict was local, so it survived the failure');
      expect(provider.pendingSaveCount, 1);
      expect(provider.submitError, isNull,
          reason: 'nothing for the student to do about it');

      // finish() flushes before scoring — a queued save that never lands is
      // a question the server thinks was skipped, and the review comes from
      // the server.
      await provider.finish();
      expect(provider.pendingSaveCount, 0);
    });

    test('without a local key a failure still tells the student', () async {
      // Here the reveal itself failed, so there is something to retry and
      // re-tapping is the way to do it.
      final service = _Service()..failCount = 1;
      final provider = QuizProvider(service: service);
      await provider.load(1, treeKnows: true);

      await provider.answer(1, 10);

      expect(provider.submitError, isNotNull);
      expect(provider.pendingSaveCount, 0);
    });

    test('counts come from the save response, not a refetch', () async {
      final service = _Service()..keyed = true;
      final provider = QuizProvider(service: service);
      await provider.load(1, treeKnows: true);
      final fetchesBefore = service.fetchCalls;

      await provider.answer(1, 10);

      expect(provider.answeredCount, 1);
      expect(provider.remainingCount, 0);
      expect(service.fetchCalls, fetchesBefore,
          reason: 'the attempt must not be re-read for numbers just given');
    });
  });

  group('the answer POST is out of the way entirely', () {
    test('answer() completes while the request is still hanging', () async {
      // The measured call was 3254ms. With the key local, none of that may
      // reach the student — not before the reveal, and not before whatever
      // the caller does next either.
      final never = Completer<void>();
      final service = _Service()
        ..keyed = true
        ..answerGate = never;
      final provider = QuizProvider(service: service);
      await provider.load(1, treeKnows: true);

      final watch = Stopwatch()..start();
      await provider.answer(1, 10).timeout(const Duration(seconds: 1));
      watch.stop();

      expect(watch.elapsedMilliseconds, lessThan(500),
          reason: 'it must not have waited on the POST');
      expect(provider.resultFor(provider.questions.first)?.isCorrect, isTrue);
      // And it really did go out.
      expect(service.answerCalls, 1);

      never.complete();
    });

    test('without a key the tap still waits, because nothing else knows',
        () async {
      final gate = Completer<void>();
      final service = _Service()..answerGate = gate;
      final provider = QuizProvider(service: service);
      await provider.load(1, treeKnows: true);

      var done = false;
      final pending = provider.answer(1, 10).then((_) => done = true);
      await Future<void>.delayed(Duration.zero);

      expect(done, isFalse, reason: 'the server is the only thing that knows');
      expect(provider.isChecking(provider.questions.first.id), isTrue);

      gate.complete();
      await pending;
      expect(done, isTrue);
    });
  });

  group('retakes', () {
    test('a finished quiz can be taken again, as a fresh attempt', () async {
      final service = _Service()..keyed = true;
      final provider = QuizProvider(service: service);
      await provider.load(1, treeKnows: true);
      await provider.answer(1, 10);
      expect(await provider.finish(), isTrue);
      expect(provider.finished, isTrue);

      service.nextAttemptId = 8;
      await provider.retake();

      expect(service.startCalls, 2);
      expect(provider.attempt?.attemptId, 8);
      expect(provider.finished, isFalse, reason: 'back to the questions');
      expect(provider.result, isNull);
      expect(provider.isAnswered(1), isFalse,
          reason: 'the first attempt\'s answers do not carry over');
      expect(provider.questions, isNotEmpty);
    });

    test('a review reopened from the list offers the same retake', () async {
      final service = _Service()..nextAttemptId = 8;
      final provider = QuizProvider(service: service);
      await provider.load(1, known: _info(completed: true), treeKnows: true);

      expect(provider.finished, isTrue);
      expect(service.startCalls, 0, reason: 'opening a review starts nothing');

      await provider.retake();
      expect(service.startCalls, 1);
      expect(provider.attempt?.attemptId, 8);
      expect(provider.finished, isFalse);
    });

    test('a reopened review lists past attempts without waiting on them',
        () async {
      // With retakes the attempts list is real content, so a review reopened
      // from the list fetches it too — but it must not hold the review up.
      final never = Completer<void>();
      final service = _Service()..historyGate = never;
      final provider = QuizProvider(service: service);

      await provider
          .load(1, known: _info(completed: true), treeKnows: true)
          .timeout(const Duration(seconds: 1));

      expect(provider.finished, isTrue, reason: 'the review did not wait');
      expect(service.historyCalls, 1, reason: 'but the list was asked for');
      never.complete();
    });

    test('the careful path does not fetch the attempts list twice', () async {
      // It already read the history to decide on the review.
      final service = _Service()
        ..history = [
          {'attemptId': 7, 'completed': true},
        ];
      await QuizProvider(service: service).load(1);
      await Future<void>.delayed(Duration.zero);

      expect(service.historyCalls, 1);
    });
  });

  group('Retest from the list', () {
    test('goes straight into a new attempt, past the review', () async {
      final service = _Service()..nextAttemptId = 8;
      final provider = QuizProvider(service: service);

      // A finished quiz, which would ordinarily open on its review.
      await provider.load(1,
          known: _info(completed: true), treeKnows: true, startFresh: true);

      expect(service.fetchCalls, 0, reason: 'the review was never opened');
      expect(service.startCalls, 1);
      expect(provider.attempt?.attemptId, 8);
      expect(provider.finished, isFalse);
      expect(provider.isLoading, isFalse,
          reason: 'the initial loading state must not block it');
      expect(provider.questions, isNotEmpty);
    });

    test('a warmed copy of the old attempt is ignored', () async {
      final service = _Service()..nextAttemptId = 8;
      final provider = QuizProvider(service: service);

      await provider.load(1,
          warmed: QuizAttempt.fromJson(_attempt),
          treeKnows: true,
          startFresh: true);

      expect(provider.attempt?.attemptId, 8,
          reason: 'the retest, not the cached #7');
    });
  });

  group('a prefetched attempt is only trusted while it is current', () {
    QuizAttempt warmed(int id) =>
        QuizAttempt.fromJson({..._attempt, 'attemptId': id});
    LessonAttemptInfo latest(int id) => LessonAttemptInfo.fromJson({
          'attemptId': id,
          'completed': true,
          'answeredCount': 1,
          'remainingCount': 0,
          'correctCount': 1,
          'score': 1,
          'attemptCount': 2,
        });

    test('the attempt the list reports is used', () {
      expect(
        QuizScreen.usableWarm(warmed(7), stateKnown: true, known: latest(7))
            ?.attemptId,
        7,
      );
    });

    test('a copy from before a retake is dropped', () {
      // Warmed as #7, but a retake has made #8 current. Using the copy would
      // reopen the old review over the new attempt.
      expect(
        QuizScreen.usableWarm(warmed(7), stateKnown: true, known: latest(8)),
        isNull,
      );
    });

    test('nothing warmed is right when the list says no attempt', () {
      expect(QuizScreen.usableWarm(warmed(7), stateKnown: true), isNull);
    });

    test('a caller that knows nothing takes the copy, as before', () {
      expect(
        QuizScreen.usableWarm(warmed(7), stateKnown: false)?.attemptId,
        7,
      );
    });
  });

  test('the review appears without waiting on past attempts', () async {
    // History is a section at the foot of the review that self-hides unless
    // there is more than one attempt. Waiting on it put a measured 1541ms
    // between tapping Submit and seeing the score.
    final never = Completer<void>();
    final service = _Service()
      ..keyed = true
      ..historyGate = never;
    final provider = QuizProvider(service: service);
    await provider.load(1, treeKnows: true);

    final watch = Stopwatch()..start();
    final ok = await provider.finish().timeout(const Duration(seconds: 1));
    watch.stop();

    expect(ok, isTrue);
    expect(provider.finished, isTrue);
    expect(provider.result, isNotNull, reason: 'the score is in hand');
    expect(watch.elapsedMilliseconds, lessThan(500),
        reason: 'it must not have waited on the history fetch');

    never.complete();
  });
}
