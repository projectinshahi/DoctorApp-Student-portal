import 'package:dr_app/models/quiz_model.dart';
import 'package:dr_app/models/selection_content_model.dart';
import 'package:dr_app/repository/quiz_provider.dart';
import 'package:dr_app/services/quiz_service.dart';
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
    return history.map(QuizAttemptSummary.fromJson).toList();
  }

  @override
  Future<QuizAttempt> startAttempt(int lessonId) async {
    startCalls++;
    return QuizAttempt.fromJson(_attempt);
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
      'options': [
        {'id': 10, 'optionText': 'A'},
        {'id': 11, 'optionText': 'B'},
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
}
