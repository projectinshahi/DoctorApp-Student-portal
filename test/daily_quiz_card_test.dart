import 'package:dr_app/models/daily_quiz_model.dart';
import 'package:dr_app/services/daily_quiz_service.dart';
import 'package:dr_app/view/Home/daily_quiz/daily_quiz_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

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

  @override
  Future<DailyQuizSet> fetchToday(int courseId) async => DailyQuizSet.fromJson({
        'date': '2026-09-02',
        'totalQuestions': 1,
        'answeredCount': 0,
        'remainingCount': 1,
        'completed': false,
        'currentStreak': 3,
        'questions': [_question],
        'answers': const [],
      });

  @override
  Future<DailyQuizAnswerResult> answer(int courseId,
      {required int questionId, required int optionId}) async {
    answerCalls++;
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

Future<_FakeService> _pump(WidgetTester tester, {String state = 'inProgress'}) async {
  tester.view.physicalSize = const Size(440, 956);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final service = _FakeService();

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
  return service;
}

void main() {
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
}
