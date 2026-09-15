import 'package:dr_app/models/test_model.dart';
import 'package:flutter_test/flutter_test.dart';

TestSummary _test({
  required bool inProgress,
  DateTime? startedAt,
  DateTime? submittedAt,
  int durationMinutes = 60,
}) =>
    TestSummary.fromJson({
      'id': 3,
      'name': 'Grand Test 1',
      'type': 'grand',
      'totalQuestions': 100,
      'durationMinutes': durationMinutes,
      'marksCorrect': 1,
      'marksIncorrect': -0.25,
      'attemptCount': inProgress || submittedAt != null ? 1 : 0,
      if (inProgress || submittedAt != null)
        'lastAttempt': {
          'attemptId': 9,
          'inProgress': inProgress,
          'startedAt': startedAt?.toIso8601String(),
          'submittedAt': submittedAt?.toIso8601String(),
        },
    });

void main() {
  group('which tab a paper belongs on', () {
    test('never opened is still to sit', () {
      final paper = _test(inProgress: false);
      expect(paper.isFinished, isFalse);
    });

    test('running with time left is still to sit', () {
      final paper = _test(
        inProgress: true,
        startedAt: DateTime.now().subtract(const Duration(minutes: 10)),
      );
      expect(paper.secondsLeftOnAttempt, greaterThan(0));
      expect(paper.isFinished, isFalse);
    });

    test('submitted is finished', () {
      final paper = _test(inProgress: false, submittedAt: DateTime.now());
      expect(paper.isSubmitted, isTrue);
      expect(paper.isFinished, isTrue);
    });

    test('running but out of time is finished, not still to sit', () {
      // This is the one that was wrong: the clock had run out, the server had
      // not recorded the auto-submit yet, and the card sat on the "to sit"
      // tab reading "Time is up" — the one state a student cannot act on.
      final paper = _test(
        inProgress: true,
        startedAt: DateTime.now().subtract(const Duration(minutes: 90)),
        durationMinutes: 60,
      );

      expect(paper.secondsLeftOnAttempt, 0);
      expect(paper.isSubmitted, isFalse, reason: 'the server has not caught up');
      expect(paper.isTimedOut, isTrue);
      expect(paper.isFinished, isTrue);
    });

    test('a paper that was never started cannot be timed out', () {
      // No clock has run, so "out of time" is meaningless.
      final paper = _test(inProgress: false);
      expect(paper.isTimedOut, isFalse);
    });
  });
}
