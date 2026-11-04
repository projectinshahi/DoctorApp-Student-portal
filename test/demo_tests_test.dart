import 'package:dr_app/core/demo/demo_content.dart';
import 'package:dr_app/models/quiz_model.dart' show QuizException, QuizErrorKind;
import 'package:dr_app/repository/test_provider.dart';
import 'package:dr_app/services/demo_test_service.dart';
import 'package:dr_app/services/test_service.dart';
import 'package:dr_app/repository/selection_content_provider.dart';
import 'package:dr_app/view/Home/tests/tests_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(() {
    DemoMode.reset();
    DemoTestService.reset();
  });

  test('signed out reads the sample, signed in the server', () {
    expect(testServiceForSession(), isNot(isA<DemoTestService>()));
    DemoMode.active = true;
    expect(testServiceForSession(), isA<DemoTestService>());
    expect(TestProvider(), isA<TestProvider>());
  });

  test('a visitor sees one free paper and one locked premium one', () async {
    final tests = await DemoTestService().fetchTests(-1);

    expect(tests, hasLength(2));
    final free = tests.firstWhere((t) => t.id == DemoTestService.freeTestId);
    final premium =
        tests.firstWhere((t) => t.id == DemoTestService.premiumTestId);
    expect(free.accessType, 'free');
    expect(free.locked, isFalse);
    expect(free.lastAttempt, isNull);
    expect(premium.accessType, 'premium');
    expect(premium.locked, isTrue);

    // Started anyway, the premium paper is refused the way the server does.
    await expectLater(
      DemoTestService().startAttempt(DemoTestService.premiumTestId),
      throwsA(isA<QuizException>()
          .having((e) => e.kind, 'kind', QuizErrorKind.locked)),
    );
  });

  test('the free paper can be sat, marked and ranked', () async {
    DemoMode.active = true;
    final provider = TestProvider();
    await provider.start(DemoTestService.freeTestId);
    provider.dispose();

    final service = DemoTestService();
    final attempt = await service.startAttempt(DemoTestService.freeTestId);
    expect(attempt.questions, hasLength(5));
    expect(attempt.secondsRemaining, greaterThan(0));
    // The paper never carries its answers.
    expect(attempt.questions.first.questionText, isNotEmpty);

    final q = attempt.questions;
    await service.answer(attempt.attemptId,
        questionId: q[0].id, selectedOption: 'C'); // right
    await service.answer(attempt.attemptId,
        questionId: q[1].id, selectedOption: 'A'); // wrong
    final cleared = await service.clearAnswer(attempt.attemptId,
        questionId: q[1].id); // back to skipped
    expect(cleared.answeredCount, 1);
    await service.answer(attempt.attemptId,
        questionId: q[2].id, selectedOption: 'D'); // wrong

    final result = await service.submit(attempt.attemptId);
    expect(result.correctCount, 1);
    expect(result.wrongCount, 1);
    expect(result.skippedCount, 3);
    expect(result.score, 0.75); // +1 − 0.25
    expect(result.results.every((r) => r.explanation != null), isTrue);

    // The list now shows the score instead of Start.
    final free = (await service.fetchTests(-1))
        .firstWhere((t) => t.id == DemoTestService.freeTestId);
    expect(free.isSubmitted, isTrue);
    expect(free.lastAttempt!.score, 0.75);

    final board = await service.fetchLeaderboard(DemoTestService.freeTestId);
    expect(board.me!.name, 'You (guest)');
    expect(board.me!.rank, 4);
    expect(board.entries.map((e) => e.rank), [1, 2, 3, 4]);
  });

  test('the real service is a TestService, not the sample', () {
    expect(TestService(), isNot(isA<DemoTestService>()));
  });

  testWidgets('the Grand Tests tab opens for a visitor', (tester) async {
    SharedPreferences.setMockInitialValues({});
    DemoMode.active = true;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final content = SelectionContentProvider();
    await content.loadContent(); // the preview's sample course

    await tester.pumpWidget(
      ChangeNotifierProvider<SelectionContentProvider>.value(
        value: content,
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (context, _) => const MaterialApp(home: TestsTab()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Sample grand test — circulation and genetics'),
        findsOneWidget);
    expect(find.text('Full mock exam — 100 questions'), findsOneWidget);

    // Premium: a visitor is asked to sign in, not shown the plan dialog.
    await tester.tap(find.text('Full mock exam — 100 questions'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in to continue'), findsOneWidget);
  });
}
