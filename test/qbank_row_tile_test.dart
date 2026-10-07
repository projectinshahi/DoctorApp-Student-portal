import 'package:dr_app/models/selection_content_model.dart';
import 'package:dr_app/view/Home/Qbank/qbank_subjects_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dr_app/widget/learning_plan_dialog.dart';
import 'package:flutter_test/flutter_test.dart';

LessonAttemptInfo _attempt({
  required bool completed,
  int answered = 3,
  int remaining = 0,
  int attempts = 1,
}) =>
    LessonAttemptInfo.fromJson({
      'attemptId': 7,
      'completed': completed,
      'answeredCount': answered,
      'remainingCount': remaining,
      'correctCount': 2,
      'score': 6.5,
      'attemptCount': attempts,
    });

Future<void> _pump(WidgetTester tester, Widget row,
    {Size size = const Size(440, 956)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(440, 956),
      minTextAdapt: true,
      builder: (context, _) => MaterialApp(
        home: Scaffold(
          body: Padding(padding: const EdgeInsets.all(20), child: row),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a finished quiz offers Review and Retest, each doing its own job',
      (tester) async {
    var reviews = 0;
    var retests = 0;

    await _pump(
      tester,
      QbankRowTile(
        icon: Icons.help_outline_rounded,
        title: 'cardiology based test',
        subtitle: 'MCQs',
        attempt: _attempt(completed: true),
        onTap: () => reviews++,
        onRetake: () => retests++,
      ),
    );

    expect(find.text('Review'), findsOneWidget);
    expect(find.text('Retest'), findsOneWidget);
    expect(find.text('Last score 6.5 · 1 attempt'), findsOneWidget);

    // Each button is its own target inside a tappable card, so neither one
    // falls through to the other.
    await tester.tap(find.text('Retest'));
    expect(retests, 1);
    expect(reviews, 0);

    await tester.tap(find.text('Review'));
    expect(reviews, 1);
    expect(retests, 1);
  });

  testWidgets('the count reads naturally after a retest', (tester) async {
    await _pump(
      tester,
      QbankRowTile(
        icon: Icons.help_outline_rounded,
        title: 'cardiology based test',
        subtitle: 'MCQs',
        attempt: _attempt(completed: true, attempts: 3),
        onTap: () {},
        onRetake: () {},
      ),
    );
    expect(find.text('Last score 6.5 · 3 attempts'), findsOneWidget);
  });

  testWidgets('without a retest handler a finished row keeps one Review pill',
      (tester) async {
    await _pump(
      tester,
      QbankRowTile(
        icon: Icons.help_outline_rounded,
        title: 'cardiology based test',
        subtitle: 'MCQs',
        attempt: _attempt(completed: true),
        onTap: () {},
      ),
    );
    expect(find.text('Review'), findsOneWidget);
    expect(find.text('Retest'), findsNothing);
  });

  testWidgets('a half-done attempt says Continue — there is nothing to retest',
      (tester) async {
    await _pump(
      tester,
      QbankRowTile(
        icon: Icons.help_outline_rounded,
        title: 'cardiology based test',
        subtitle: 'MCQs',
        attempt: _attempt(completed: false, answered: 2, remaining: 1),
        onTap: () {},
        onRetake: () {},
      ),
    );
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Retest'), findsNothing);
    expect(find.text('Review'), findsNothing);
  });

  testWidgets('a quiz never started shows neither', (tester) async {
    await _pump(
      tester,
      QbankRowTile(
        icon: Icons.help_outline_rounded,
        title: 'testing',
        subtitle: 'MCQs',
        onTap: () {},
        onRetake: () {},
      ),
    );
    expect(find.text('MCQs'), findsOneWidget);
    expect(find.text('Retest'), findsNothing);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
  });

  testWidgets('fits a short phone with a long title and a lock',
      (tester) async {
    await _pump(
      tester,
      QbankRowTile(
        icon: Icons.help_outline_rounded,
        title: 'Cardiology based test — arrhythmias, heart failure and ECG '
            'interpretation for the final exam',
        subtitle: 'MCQs',
        locked: true,
        attempt: _attempt(completed: true, attempts: 12),
        onTap: () {},
        onRetake: () {},
      ),
      size: const Size(375, 667),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Retest'), findsOneWidget);
  });

  testWidgets('a row says whether it is free or premium, as the admin set it',
      (tester) async {
    await _pump(
      tester,
      QbankRowTile(
        icon: Icons.help_outline_rounded,
        title: 'Cardiology',
        subtitle: '40 MCQs',
        accessType: 'premium',
        locked: true,
        onTap: () {},
      ),
    );

    expect(find.text('Premium'), findsOneWidget);
    // The chip says what the lesson is; the padlock says this student cannot
    // open it. A subscriber sees the chip with no padlock.
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
  });

  testWidgets('a free row is labelled free and carries no padlock',
      (tester) async {
    await _pump(
      tester,
      QbankRowTile(
        icon: Icons.help_outline_rounded,
        title: 'Cardiology',
        subtitle: '12 MCQs',
        accessType: 'free',
        onTap: () {},
      ),
    );

    expect(find.text('Free'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);
  });

  testWidgets('a row that is not a lesson wears no chip at all',
      (tester) async {
    // Topics and Recall decks share this row and have no access of their own.
    await _pump(
      tester,
      QbankRowTile(
        icon: Icons.style_outlined,
        title: 'Internal Medicine',
        subtitle: '4 decks',
        onTap: () {},
      ),
    );

    expect(find.text('Free'), findsNothing);
    expect(find.text('Premium'), findsNothing);
  });

  testWidgets('a padlocked quiz says why, and offers the website',
      (tester) async {
    // The server answers a locked lesson with 403 "Subscribe to unlock it",
    // so the quiz screen is never opened: the student gets the reason here.
    await _pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () =>
              showPlanRequiredDialog(context, lessonTitle: 'Cardiology'),
          child: const Text('tap'),
        ),
      ),
    );

    await tester.tap(find.text('tap'));
    await tester.pumpAndSettle();

    expect(find.text('Your learning plan is not active'), findsOneWidget);
    expect(find.textContaining('Cardiology is premium'), findsOneWidget);
    expect(find.text('Explore plans'), findsOneWidget);
  });
}
