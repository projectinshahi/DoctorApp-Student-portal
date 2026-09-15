import 'package:dr_app/repository/daily_quiz_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dr_app/core/constant/local_storage.dart';
import 'dart:convert';
import 'dart:async';
import 'package:dr_app/models/daily_quiz_model.dart';
import 'package:dr_app/services/daily_quiz_service.dart';
import 'package:dr_app/view/Home/daily_quiz/daily_quiz_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

const _second = {
  'id': 16,
  'questionText': 'Which organism most commonly causes pneumonia?',
  'options': [
    {'id': 5, 'optionText': 'Streptococcus pneumoniae', 'displayOrder': 0},
    {'id': 6, 'optionText': 'Aspergillus fumigatus', 'displayOrder': 1},
  ],
};

const _question = {
  'id': 15,
  'questionText':
      'A 6-month-old presented with a genetic disorder attributed to '
          'multifactorial inheritance. Which disorder is most likely?',
  'options': [
    {'id': 1, 'optionText': 'Achondroplasia', 'displayOrder': 0},
    {'id': 2, 'optionText': 'Lysosomal storage disease', 'displayOrder': 1},
    {'id': 3, 'optionText': 'Cleft lip', 'displayOrder': 2},
    {'id': 4, 'optionText': 'Huntington disease', 'displayOrder': 3},
  ],
};

/// Answers the way the live backend does: the key arrives only after the
/// student commits.
class _FakeService extends DailyQuizService {
  int answerCalls = 0;

  /// Held open to freeze the request mid-flight — the only way to observe
  /// what the card shows while it is waiting.
  final Completer<void>? answerGate;

  _FakeService({this.answerGate});

  @override
  Future<DailyQuizSet> fetchToday(int courseId) async => DailyQuizSet.fromJson({
        'date': '2026-09-02',
        'totalQuestions': 2,
        'answeredCount': 0,
        'remainingCount': 2,
        'completed': false,
        'currentStreak': 3,
        'questions': [_question, _second],
        'answers': const [],
      });

  @override
  Future<DailyQuizAnswerResult> answer(int courseId,
      {required int questionId, required int optionId}) async {
    answerCalls++;
    if (answerGate != null) await answerGate!.future;
    return DailyQuizAnswerResult.fromJson({
      'questionId': questionId,
      'selectedOptionId': optionId,
      // 3 (Cleft lip) is the right answer in this fixture.
      'isCorrect': optionId == 3,
      'correctOptionId': 3,
      'explanation': 'Cleft lip is multifactorial; the others are single-gene.',
      'marksAwarded': optionId == 3 ? 2 : -0.5,
      'answeredCount': 1,
      'remainingCount': 0,
      'allAnswered': false,
    });
  }
}

Future<_FakeService> _pump(WidgetTester tester,
    {String state = 'inProgress'}) async {
  final service = _FakeService();
  await _pumpWith(tester, service, state: state);
  return service;
}

Future<void> _pumpWith(WidgetTester tester, _FakeService service,
    {String state = 'inProgress'}) async {
  tester.view.physicalSize = const Size(440, 956);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(440, 956),
      minTextAdapt: true,
      builder: (context, child) => MaterialApp(
        home: Scaffold(
          // A scroll view, as on the home screen: unbounded height is where
          // layout bugs hide.
          body: SingleChildScrollView(
            child: DailyQuizCard(
              summary: DailyQuizSummary.fromJson(
                  {'state': state, 'totalQuestions': 1, 'currentStreak': 3}),
              courseId: 22,
              onChanged: () {},
              service: service,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The same set, but with the key on every option — what the server sends
/// if it ships the answer with the question.
Map<String, dynamic> _keyed(Map<String, dynamic> question, int correctId) => {
      ...question,
      'options': [
        for (final o in question['options'] as List)
          {...o as Map<String, dynamic>, 'isCorrect': o['id'] == correctId},
      ],
    };

class _KeyedService extends _FakeService {
  _KeyedService({super.answerGate});

  @override
  Future<DailyQuizSet> fetchToday(int courseId) async => DailyQuizSet.fromJson({
        'date': '2026-09-02',
        'totalQuestions': 1,
        'answeredCount': 0,
        'remainingCount': 1,
        'completed': false,
        'currentStreak': 3,
        'questions': [_keyed(_question, 3)],
        'answers': const [],
      });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _cacheTests();

  testWidgets('shows the question and four options, and lays out clean',
      (tester) async {
    await _pump(tester);

    expect(tester.takeException(), isNull);
    expect(find.textContaining('multifactorial inheritance'), findsOneWidget);
    for (final letter in ['A', 'B', 'C', 'D']) {
      expect(find.text(letter), findsOneWidget);
    }
    expect(find.text('Achondroplasia'), findsOneWidget);

    // Nothing revealed before the student commits.
    expect(find.text('Correct'), findsNothing);
    expect(find.text('Incorrect'), findsNothing);
  });

  testWidgets('a wrong answer reveals the verdict and the explanation',
      (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Achondroplasia'));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect'), findsOneWidget);
    expect(find.textContaining('multifactorial; the others'), findsOneWidget);
    // Negative marks print as sent — never "--0.5".
    expect(find.text('-0.5'), findsOneWidget);
  });

  testWidgets('a right answer reveals Correct and the marks gained',
      (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Cleft lip'));
    await tester.pumpAndSettle();

    expect(find.text('Correct'), findsOneWidget);
    expect(find.text('+2.0'), findsOneWidget);
  });

  testWidgets('the options lock once answered — re-answering is a 409',
      (tester) async {
    final service = await _pump(tester);

    await tester.tap(find.text('Achondroplasia'));
    await tester.pumpAndSettle();
    expect(service.answerCalls, 1);

    // Tapping another option after the reveal must not fire a second write.
    // Changing your mind after reading the explanation is what would make
    // the score meaningless, and the server rejects it anyway.
    await tester.tap(find.text('Cleft lip'));
    await tester.pumpAndSettle();
    expect(service.answerCalls, 1);
  });

  testWidgets('a fresh day shows the question straight away', (tester) async {
    await _pump(tester, state: 'notStarted');

    // By request: no "Start today's set" gate. The trade-off is real and
    // deliberate — fetching the question is what creates the day's attempt,
    // so opening the app now starts today's quiz.
    expect(find.textContaining('multifactorial inheritance'), findsOneWidget);
    expect(find.text('Start today\'s set'), findsNothing);
  });

  testWidgets('one question a day — it never advances after answering',
      (tester) async {
    await _pump(tester);

    // Only today's question is on the card, even though the set has more.
    expect(find.textContaining('multifactorial inheritance'), findsOneWidget);
    expect(find.textContaining('causes pneumonia'), findsNothing);

    await tester.tap(find.text('Cleft lip'));
    await tester.pumpAndSettle();

    // Still the same question, with its explanation. Advancing here would
    // slide the answer the student just read out from under them and put a
    // fresh question in its place.
    expect(find.textContaining('multifactorial inheritance'), findsOneWidget);
    expect(find.text('Correct'), findsOneWidget);
    expect(find.textContaining('causes pneumonia'), findsNothing);
  });

  testWidgets('no question counter and nothing to navigate with',
      (tester) async {
    await _pump(tester);

    // "Question 1 of 10" only invites hunting for the other nine.
    expect(find.textContaining('of 10'), findsNothing);
    expect(find.text('Next question'), findsNothing);
    expect(find.text('Previous'), findsNothing);
    expect(find.text("Today's question"), findsOneWidget);
  });

  testWidgets('after answering it says the next one is tomorrow',
      (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Achondroplasia'));
    await tester.pumpAndSettle();

    expect(find.text('Answered — new question tomorrow'), findsOneWidget);
  });

  testWidgets('the loader ends when the response lands, not on a timer',
      (tester) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(440, 956),
        minTextAdapt: true,
        builder: (context, child) => MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DailyQuizCard(
                summary: DailyQuizSummary.fromJson(
                    {'state': 'inProgress', 'totalQuestions': 2}),
                courseId: 22,
                onChanged: () {},
                service: _FakeService(),
              ),
            ),
          ),
        ),
      ),
    );

    // Nothing yet: the fetch is in flight.
    expect(find.textContaining('multifactorial inheritance'), findsNothing);

    // No simulated time passes here — pump() only flushes the microtask the
    // fake resolved on. The question is up because the answer arrived, which
    // is the whole point: there is no clock left to wait out.
    await tester.pump();
    expect(find.textContaining('multifactorial inheritance'), findsOneWidget);
  });

  testWidgets('the tapped option lights up before the server answers',
      (tester) async {
    // The whole complaint: the tap changed nothing on screen until the round
    // trip came back, which on a cold backend is seconds of the student
    // wondering whether it registered at all.
    final gate = Completer<void>();
    final service = _FakeService(answerGate: gate);
    await _pumpWith(tester, service);

    await tester.tap(find.text('Achondroplasia'));
    await tester.pump();

    // Acknowledged on this frame, with the request still in flight — and
    // still no verdict, because the answer key is deliberately absent from
    // the question payload and only the server can rule.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(service.answerCalls, 1);
  });

  testWidgets('when the key ships with the question, the reveal is instant',
      (tester) async {
    // The POST still goes out — it records the answer and returns the
    // explanation — but the student must not wait on it to learn whether
    // they were right.
    final gate = Completer<void>();
    await _pumpWith(tester, _KeyedService(answerGate: gate));

    await tester.tap(find.text('Achondroplasia'));
    await tester.pump();

    // Wrong pick: 3 (Cleft lip) is the key in this fixture. Revealed with
    // the request still in flight.
    expect(find.text('Cleft lip'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('without the key it still waits, rather than guessing',
      (tester) async {
    // The ordinary payload carries no isCorrect, and a guessed verdict would
    // be wrong half the time.
    final gate = Completer<void>();
    await _pumpWith(tester, _FakeService(answerGate: gate));

    await tester.tap(find.text('Achondroplasia'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('the card shows nothing while loading — the page covers it',
      (tester) async {
    // The card used to draw its own skeleton, which left the home screen
    // complete except for one box. The page now holds its whole skeleton
    // until onReady fires, so the card itself must stay quiet.
    final gate = Completer<void>();
    final service = _GatedLoadService(gate);

    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var readyCalls = 0;
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(440, 956),
        minTextAdapt: true,
        builder: (context, child) => MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DailyQuizCard(
                summary: DailyQuizSummary.fromJson(
                    {'state': 'inProgress', 'totalQuestions': 1}),
                courseId: 22,
                onChanged: () {},
                onReady: () => readyCalls++,
                service: service,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(readyCalls, 0, reason: 'the question has not landed yet');

    gate.complete();
    await tester.pumpAndSettle();

    expect(readyCalls, 1, reason: 'fired once, when the question arrived');
    expect(find.textContaining('multifactorial'), findsOneWidget);
  });
}

/// Holds the *set* fetch open, which is the state the card shows a skeleton
/// for — distinct from _FakeService's gate, which holds an answer.
class _GatedLoadService extends _FakeService {
  final Completer<void> loadGate;

  _GatedLoadService(this.loadGate);

  @override
  Future<DailyQuizSet> fetchToday(int courseId) async {
    await loadGate.future;
    return super.fetchToday(courseId);
  }
}

void _cacheTests() {
  group("today's set is restored before the network", () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('a stored set for this course is used', () async {
      await LocalStorage.saveCached(
        LocalStorage.dailyQuizKey,
        jsonEncode({
          'courseId': 22,
          'set': {
            'date': '2026-09-10',
            'totalQuestions': 1,
            'answeredCount': 0,
            'remainingCount': 1,
            'completed': false,
            'questions': [_question],
            'answers': const [],
          },
        }),
      );

      final provider = DailyQuizProvider(courseId: 22, service: _FakeService());
      expect(await provider.restoreCached(), isTrue);
      expect(provider.questions, isNotEmpty);
      expect(provider.isLoading, isFalse);
    });

    test('a set stored for another course is refused', () async {
      // Switching course must not restore the previous course's question.
      await LocalStorage.saveCached(
        LocalStorage.dailyQuizKey,
        jsonEncode({'courseId': 99, 'set': const {}}),
      );

      final provider = DailyQuizProvider(courseId: 22, service: _FakeService());
      expect(await provider.restoreCached(), isFalse);
      expect(provider.questions, isEmpty);
    });

    test('a set written by an older build is discarded, not crashed on',
        () async {
      await LocalStorage.saveCached(LocalStorage.dailyQuizKey, '{ not json');

      final provider = DailyQuizProvider(courseId: 22, service: _FakeService());
      expect(await provider.restoreCached(), isFalse);
    });
  });
}
