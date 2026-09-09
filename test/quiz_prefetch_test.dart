import 'package:dr_app/models/quiz_model.dart';
import 'package:dr_app/models/selection_content_model.dart';
import 'package:dr_app/repository/quiz_prefetch.dart';
import 'package:dr_app/repository/quiz_provider.dart';
import 'package:dr_app/services/quiz_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _Service extends QuizService {
  int fetchCalls = 0;
  int startCalls = 0;

  @override
  Future<QuizAttempt> fetchAttempt(int attemptId) async {
    fetchCalls++;
    return QuizAttempt.fromJson(_attemptJson);
  }

  @override
  Future<QuizAttempt> startAttempt(int lessonId) async {
    startCalls++;
    return QuizAttempt.fromJson(_attemptJson);
  }
}

const _attemptJson = {
  'attemptId': 7,
  'resumed': true,
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

StudentLessonModel _quiz({required int id, bool attempted = true, bool locked = false}) =>
    StudentLessonModel.fromJson({
      'id': id,
      'title': 'Quiz $id',
      'type': 'quiz',
      'displayOrder': id,
      'accessType': locked ? 'premium' : 'free',
      'locked': locked,
      if (attempted)
        'attempt': {
          'attemptId': 7,
          'completed': false,
          'answeredCount': 1,
          'remainingCount': 1,
          'correctCount': 1,
          'score': 1,
          'attemptCount': 1,
        },
    });

void main() {
  test('a warmed quiz opens with no call and no spinner', () async {
    final service = _Service();
    final cache = QuizPrefetch(service: service);
    await cache.warm([_quiz(id: 1)]);
    expect(cache.isWarm(1), isTrue);

    final provider = QuizProvider(service: service);
    await provider.load(1, warmed: cache.take(1), treeKnows: true);

    // The whole point: nothing was fetched when the screen opened, so there
    // was nothing to show a spinner for.
    expect(service.startCalls, 0);
    expect(service.fetchCalls, 1, reason: 'the one warm read, done earlier');
    expect(provider.isLoading, isFalse);
    expect(provider.questions, isNotEmpty);
  });

  test('a never-attempted quiz is not warmed, because that would start it',
      () async {
    // POST /attempts is the only endpoint that returns questions for these,
    // and it creates the attempt — filling Continue MCQs with quizzes the
    // student never opened.
    final service = _Service();
    final cache = QuizPrefetch(service: service);

    await cache.warm([_quiz(id: 2, attempted: false)]);

    expect(service.fetchCalls, 0);
    expect(service.startCalls, 0);
    expect(cache.isWarm(2), isFalse);
  });

  test('a locked quiz is not warmed', () async {
    final service = _Service();
    final cache = QuizPrefetch(service: service);
    await cache.warm([_quiz(id: 3, locked: true)]);
    expect(service.fetchCalls, 0);
  });

  test('warming twice does not fetch twice', () async {
    final service = _Service();
    final cache = QuizPrefetch(service: service);
    await cache.warm([_quiz(id: 1)]);
    await cache.warm([_quiz(id: 1)]);
    expect(service.fetchCalls, 1);
  });

  test('taking is one shot, so a reopened quiz reads fresh', () async {
    // The student changes the attempt the moment it opens; handing the same
    // copy out twice would show answers-ago state.
    final cache = QuizPrefetch(service: _Service());
    await cache.warm([_quiz(id: 1)]);

    expect(cache.take(1), isNotNull);
    expect(cache.take(1), isNull);
  });

  test('signing out drops every warmed attempt', () async {
    final cache = QuizPrefetch(service: _Service());
    await cache.warm([_quiz(id: 1)]);
    expect(cache.warmCount, 1);

    cache.clear();

    // They belong to the account that left — opening one on the next account
    // would show the wrong student's answers.
    expect(cache.warmCount, 0);
  });

  test('warming a whole course does not fire an unbounded burst', () async {
    // The QBank tab warms every started quiz in the course. Firing them in
    // parallel measurably starved the foreground request the student was
    // waiting on, so this is both capped and sequential.
    final service = _Service();
    final cache = QuizPrefetch(service: service);

    await cache.warm([for (var i = 1; i <= 40; i++) _quiz(id: i)]);

    expect(service.fetchCalls, lessThanOrEqualTo(6));
    expect(service.fetchCalls, greaterThan(0));
  });
}
