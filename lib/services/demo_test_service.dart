// lib/services/demo_test_service.dart
//
// Grand Tests for a visitor who has not signed in.
//
// The same six calls as TestService, answered on the phone instead of the
// server, so the list, the timed paper, the result and the leaderboard are
// the real screens. One free paper on the preview's own topics — the AI
// videos and Rapid Recall decks — and one premium paper listed locked.
import '../core/demo/demo_content.dart';
import '../models/quiz_model.dart' show QuizException, QuizErrorKind;
import '../models/test_model.dart';
import 'test_service.dart';

/// The service for whoever is using the app now: the sample while signed
/// out, the server once signed in.
TestService testServiceForSession() =>
    DemoMode.active ? DemoTestService() : TestService();

class DemoTestService extends TestService {
  static const int freeTestId = -501;
  static const int premiumTestId = -502;
  static const int _attemptId = -601;
  static const double _right = 1, _wrong = -0.25;

  // Kept for the session, like a real attempt, so the list can say Resume
  // or show the score. Reset by DemoTestService.reset().
  static final Map<int, String> _answers = {};
  static DateTime? _startedAt;
  static DateTime? _submittedAt;

  static void reset() {
    _answers.clear();
    _startedAt = null;
    _submittedAt = null;
  }

  static const _duration = 10;

  static const List<Map<String, String>> _questions = [
    {
      'q': 'Which vessel carries deoxygenated blood from the right ventricle '
          'to the lungs?',
      'A': 'Aorta',
      'B': 'Pulmonary vein',
      'C': 'Pulmonary artery',
      'D': 'Superior vena cava',
      'answer': 'C',
      'subject': 'Cardiovascular system',
      'why': 'The pulmonary artery is the only artery that carries '
          'deoxygenated blood. The pulmonary veins bring oxygenated blood '
          'back to the left atrium.',
    },
    {
      'q': 'The first heart sound (S1) is made by the closure of the '
          'tricuspid valve and which other valve?',
      'A': 'Aortic',
      'B': 'Mitral',
      'C': 'Pulmonary',
      'D': 'Eustachian',
      'answer': 'B',
      'subject': 'Cardiovascular system',
      'why': 'S1 is the atrioventricular valves closing — mitral and '
          'tricuspid. S2 is the aortic and pulmonary valves closing.',
    },
    {
      'q': 'Both parents carry an autosomal recessive condition. What is the '
          'risk that each child is affected?',
      'A': '0%',
      'B': '25%',
      'C': '50%',
      'D': '100%',
      'answer': 'B',
      'subject': 'Genetics',
      'why': 'Each parent passes on the variant half the time, so a child '
          'inherits two copies with a probability of ½ × ½ = 25%. Half of '
          'the children will be carriers.',
    },
    {
      'q': "Huntington's disease is caused by the expansion of which "
          'trinucleotide repeat in the HTT gene?',
      'A': 'CGG',
      'B': 'CTG',
      'C': 'CAG',
      'D': 'GAA',
      'answer': 'C',
      'subject': "Huntington's disease",
      'why': 'CAG codes for glutamine; 36 or more repeats give a toxic '
          'polyglutamine huntingtin. CGG is fragile X, CTG myotonic '
          "dystrophy and GAA Friedreich's ataxia.",
    },
    {
      'q': "In Huntington's disease, atrophy of which structure gives the "
          '"boxcar" appearance of the lateral ventricles?',
      'A': 'Caudate nucleus',
      'B': 'Cerebellum',
      'C': 'Hippocampus',
      'D': 'Thalamus',
      'answer': 'A',
      'subject': "Huntington's disease",
      'why': 'The caudate nucleus forms the lateral wall of the lateral '
          'ventricle. As it shrinks, the frontal horns widen into the '
          'boxcar shape.',
    },
  ];

  static int _questionId(int i) => -700 - i;

  static Map<String, dynamic> _test({
    required int id,
    required String name,
    required int questions,
    required int minutes,
    required bool premium,
  }) =>
      {
        'id': id,
        'name': name,
        'type': 'grand',
        'totalQuestions': questions,
        'durationMinutes': minutes,
        'marksCorrect': _right,
        'marksIncorrect': _wrong,
        'attemptCount': 0,
        'accessType': premium ? 'premium' : 'free',
        'locked': premium,
      };

  @override
  Future<List<TestSummary>> fetchTests(int courseId) async {
    final free = _test(
      id: freeTestId,
      name: 'Sample grand test — circulation and genetics',
      questions: _questions.length,
      minutes: _duration,
      premium: false,
    );
    if (_startedAt != null) {
      free['lastAttempt'] = {
        'attemptId': _attemptId,
        'startedAt': _startedAt!.toIso8601String(),
        'submittedAt': _submittedAt?.toIso8601String(),
        'score': _submittedAt == null ? null : _score(),
        'inProgress': _submittedAt == null,
      };
    }
    return TestSummary.listFromJson({
      'tests': [
        free,
        _test(
          id: premiumTestId,
          name: 'Full mock exam — 100 questions',
          questions: 100,
          minutes: 120,
          premium: true,
        ),
      ],
    });
  }

  @override
  Future<TestAttempt> startAttempt(int testId) async {
    if (testId != freeTestId) {
      throw QuizException(
          QuizErrorKind.locked, 'Sign in to sit the premium tests.');
    }
    // A submitted paper starts over, as a new attempt would.
    if (_submittedAt != null) reset();
    final resumed = _startedAt != null;
    _startedAt ??= DateTime.now();

    return TestAttempt.fromJson({
      'attemptId': _attemptId,
      'resumed': resumed,
      'secondsRemaining': _secondsRemaining(),
      'test': {
        'id': freeTestId,
        'name': 'Sample grand test — circulation and genetics',
        'totalQuestions': _questions.length,
        'durationMinutes': _duration,
        'marksCorrect': _right,
        'marksIncorrect': _wrong,
      },
      'answered': [
        for (final entry in _answers.entries)
          {'testQuestionId': entry.key, 'selectedOption': entry.value},
      ],
      'questions': [
        for (var i = 0; i < _questions.length; i++)
          {
            'id': _questionId(i),
            'questionOrder': i + 1,
            'questionText': _questions[i]['q'],
            for (final letter in const ['A', 'B', 'C', 'D'])
              'option$letter': _questions[i][letter],
          },
      ],
    });
  }

  int _secondsRemaining() {
    final used = DateTime.now().difference(_startedAt!).inSeconds;
    return (_duration * 60 - used).clamp(0, _duration * 60);
  }

  TestAnswerResponse _counts() => TestAnswerResponse(
        answeredCount: _answers.length,
        remainingCount: _questions.length - _answers.length,
        secondsRemaining: _secondsRemaining(),
      );

  @override
  Future<TestAnswerResponse> answer(
    int attemptId, {
    required int questionId,
    required String selectedOption,
  }) async {
    _answers[questionId] = selectedOption;
    return _counts();
  }

  @override
  Future<TestAnswerResponse> clearAnswer(
    int attemptId, {
    required int questionId,
  }) async {
    _answers.remove(questionId);
    return _counts();
  }

  @override
  Future<TestResult> submit(int attemptId) async {
    _startedAt ??= DateTime.now();
    _submittedAt ??= DateTime.now();
    return _result();
  }

  @override
  Future<TestResult> fetchResult(int attemptId) async => _result();

  double _score() {
    var score = 0.0;
    for (var i = 0; i < _questions.length; i++) {
      final chosen = _answers[_questionId(i)];
      if (chosen == null) continue;
      score += chosen == _questions[i]['answer'] ? _right : _wrong;
    }
    return score;
  }

  TestResult _result() {
    final results = <Map<String, dynamic>>[];
    var correct = 0, wrong = 0;
    for (var i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      final chosen = _answers[_questionId(i)];
      final isCorrect = chosen == q['answer'];
      if (chosen != null) isCorrect ? correct++ : wrong++;
      results.add({
        'testQuestionId': _questionId(i),
        'questionText': q['q'],
        'selectedOption': chosen,
        'correctOption': q['answer'],
        'isCorrect': isCorrect,
        'answered': chosen != null,
        'marksAwarded': chosen == null ? 0 : (isCorrect ? _right : _wrong),
        'explanation': q['why'],
        'subject': q['subject'],
      });
    }
    final end = _submittedAt ?? DateTime.now();
    return TestResult.fromJson({
      'score': _score(),
      'totalMarks': _questions.length * _right,
      'timeTakenSeconds': end.difference(_startedAt ?? end).inSeconds,
      'correctCount': correct,
      'wrongCount': wrong,
      'skippedCount': _questions.length - correct - wrong,
      'results': results,
    });
  }

  @override
  Future<Leaderboard> fetchLeaderboard(int testId, {int limit = 50}) async {
    // A sample table, with the visitor placed by their own score.
    final others = [
      {'name': 'Sample student A', 'score': 5.0, 'correctCount': 5, 'timeTakenSeconds': 312},
      {'name': 'Sample student B', 'score': 3.75, 'correctCount': 4, 'timeTakenSeconds': 401},
      {'name': 'Sample student C', 'score': 2.5, 'correctCount': 3, 'timeTakenSeconds': 455},
    ];
    final me = {
      'name': 'You (guest)',
      'score': _score(),
      'correctCount': _result().correctCount,
      'timeTakenSeconds': _result().timeTakenSeconds,
    };
    final all = [...others, me]
      ..sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
    final ranked = [
      for (var i = 0; i < all.length; i++) {...all[i], 'rank': i + 1},
    ];
    return Leaderboard.fromJson({
      'totalParticipants': ranked.length,
      'me': ranked.firstWhere((e) => e['name'] == 'You (guest)'),
      'entries': ranked,
    });
  }
}
