import 'package:dr_app/models/test_model.dart';
import 'package:dr_app/view/Home/tests/test_instructions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

TestSummary _test({double marksIncorrect = -0.25, int questions = 40}) =>
    TestSummary.listFromJson({
      'tests': [
        {
          'id': 1,
          'name': 'Grand Test 1',
          'totalQuestions': questions,
          'durationMinutes': 42,
          'marksCorrect': 4,
          'marksIncorrect': marksIncorrect,
          'attemptCount': 0,
          'lastAttempt': null,
        },
      ],
    }).single;

Future<void> _pump(WidgetTester tester, TestSummary test) async {
  tester.view.physicalSize = const Size(440, 956);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(440, 956),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) =>
          MaterialApp(home: TestInstructionsScreen(test: test)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the rules come from the test, not from a hardcoded list',
      (tester) async {
    await _pump(tester, _test());

    // A 40-question, 42-minute paper must not claim to be anything else.
    expect(find.textContaining('40 questions'), findsOneWidget);
    expect(find.textContaining('42 minutes'), findsOneWidget);
    expect(find.textContaining('loses 0.25'), findsOneWidget);
  });

  testWidgets('a paper without negative marking says so', (tester) async {
    await _pump(tester, _test(marksIncorrect: 0));

    // Telling a student to avoid guessing when guessing is free is bad advice.
    expect(find.textContaining('no negative marking'), findsOneWidget);
    expect(find.textContaining('skipping is safer'), findsNothing);
  });

  testWidgets('starting asks once, and says the timer cannot be paused',
      (tester) async {
    await _pump(tester, _test());

    expect(find.text('Yes, continue'), findsOneWidget);
    expect(find.text('No, exit'), findsOneWidget);

    await tester.tap(find.text('Yes, continue'));
    await tester.pumpAndSettle();

    // The clock starts on the server the moment the attempt is created and
    // nothing the student does afterwards pauses it. That has to be said
    // before they commit, not discovered when they come back.
    expect(
      find.text('Once you start, the test timer cannot be paused. Continue?'),
      findsOneWidget,
    );
    expect(find.text('YES'), findsOneWidget);
    expect(find.text('No, may be later'), findsOneWidget);
  });

  testWidgets('backing out of the confirm does not start the paper',
      (tester) async {
    await _pump(tester, _test());

    await tester.tap(find.text('Yes, continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No, may be later'));
    await tester.pumpAndSettle();

    // Still on the instructions, no attempt created.
    expect(find.text('Instructions'), findsOneWidget);
  });

  testWidgets('the one-attempt rule is stated before the paper opens',
      (tester) async {
    await _pump(tester, _test());

    // The whole point of the gate. A student who thinks they can retake will
    // treat the first sitting as practice and burn it.
    expect(find.textContaining('one attempt'), findsOneWidget);
    expect(find.textContaining('no retake'), findsOneWidget);
  });
}
