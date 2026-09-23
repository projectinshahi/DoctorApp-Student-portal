import 'package:dr_app/View_model/profile_model.dart';
import 'package:dr_app/models/selection_content_model.dart';
import 'package:dr_app/widget/learning_plan_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dr_app/core/utils/website.dart';
import 'package:dr_app/repository/refresh_api_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

ProfileModel _profile({bool? premium, bool? paid, String? accessType}) =>
    ProfileModel.fromJson({
      'id': 43,
      'email': 'student@example.test',
      'name': 'Shareef',
      'role': 'student',
      'status': 'verified',
      if (accessType != null)
        'selectedCourse': {'id': 22, 'title': 'DHA', 'accessType': accessType},
      if (premium != null || paid != null)
        'subscriptionInfo': {
          'isPremiumCourse': premium ?? false,
          'hasPaid': paid ?? false,
        },
    });

SelectionContentModel _content({required bool hasPaid, String? accessType}) =>
    SelectionContentModel.fromJson({
      'course': {'id': 22, 'title': 'DHA', 'accessType': accessType},
      'hasPaid': hasPaid,
      'chapters': const [],
    });

void main() {
  group('when the prompt is owed', () {
    test('a premium course with no plan', () {
      expect(
        learningPlanInactive(
          profile: _profile(premium: true, paid: false),
          content: _content(hasPaid: false, accessType: 'paid'),
        ),
        isTrue,
      );
    });

    test('a paid-up student is never told their plan is inactive', () {
      expect(
        learningPlanInactive(
          profile: _profile(premium: true, paid: true),
          content: _content(hasPaid: true, accessType: 'paid'),
        ),
        isFalse,
      );
    });

    test('a free course has nothing to buy', () {
      expect(
        learningPlanInactive(
          profile: _profile(premium: false, paid: false),
          content: _content(hasPaid: false, accessType: 'free'),
        ),
        isFalse,
      );
    });

    test('nothing loaded yet says nothing', () {
      // An unloaded profile looks exactly like an unpaid one, and accusing a
      // paying student is the worse mistake.
      expect(learningPlanInactive(), isFalse);
      expect(learningPlanInactive(profile: null, content: null), isFalse);
    });

    test('without a subscription block, the course tree decides', () {
      expect(
        learningPlanInactive(content: _content(hasPaid: false, accessType: 'paid')),
        isTrue,
      );
      expect(
        learningPlanInactive(content: _content(hasPaid: true, accessType: 'paid')),
        isFalse,
      );
      // No access type anywhere: not enough to accuse anyone.
      expect(learningPlanInactive(content: _content(hasPaid: false)), isFalse);
    });
  });

  group('the gate itself', () {
    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AuthProvider(),
          child: ScreenUtilInit(
            designSize: const Size(440, 956),
            minTextAdapt: true,
            builder: (context, _) => MaterialApp(
              home: Scaffold(
                body: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Standing in for home underneath.
                    TextButton(
                        onPressed: () => tapped = true,
                        child: const Text('a course')),
                    const LearningPlanGate(),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('says what is wrong and where plans are bought',
        (tester) async {
      await pump(tester);

      expect(find.text('Your learning plan is not active'), findsOneWidget);
      expect(find.textContaining('bought on our website'), findsOneWidget);
      expect(find.text('Explore plans'), findsOneWidget);
    });

    testWidgets('its text sits inside a Material, so it renders as designed',
        (tester) async {
      // The gate sits beside the Scaffold rather than inside it. Without a
      // Material above it, every Text fell back to Flutter's debug styling —
      // monospace with yellow underlines, which is what the screen showed.
      await pump(tester);

      expect(
        find.ancestor(
          of: find.text('Your learning plan is not active'),
          matching: find.byType(Material),
        ),
        findsWidgets,
      );
    });

    testWidgets('Explore plans opens the website', (tester) async {
      final original = launchWebsite;
      Uri? opened;
      launchWebsite = (url) async {
        opened = url;
        return true;
      };
      addTearDown(() => launchWebsite = original);

      await pump(tester);
      await tester.tap(find.text('Explore plans'));
      await tester.pumpAndSettle();

      expect(opened.toString(), websiteUrl);
    });

    testWidgets('has no way to close it', (tester) async {
      // The whole point: a student without a plan cannot dismiss this and
      // carry on using the app.
      await pump(tester);

      expect(find.byIcon(Icons.close_rounded), findsNothing);
      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('nothing behind it can be tapped', (tester) async {
      tapped = false;
      await pump(tester);

      await tester.tap(find.text('a course'), warnIfMissed: false);
      await tester.pump();

      expect(tapped, isFalse, reason: 'the barrier swallowed it');
      expect(find.byType(LearningPlanGate), findsOneWidget);
    });

    testWidgets('signing out is the only way past it', (tester) async {
      // Without this a student who signed into the wrong account is stuck.
      await pump(tester);
      expect(find.text('Sign out'), findsOneWidget);
    });
  });

  group('waiting for a payment to land', () {
    // The webhook that marks the student paid arrives a moment after they
    // come back, so a single look would put the lock straight back on.
    test('stops asking the moment the plan is active', () async {
      var calls = 0;
      var paid = false;

      final active = await pollUntilActive(
        refresh: () async {
          calls++;
          if (calls == 2) paid = true;
        },
        active: () => paid,
        gap: Duration.zero,
      );

      expect(active, isTrue);
      expect(calls, 2, reason: 'no asking on past the answer');
    });

    test('gives up rather than asking forever', () async {
      var calls = 0;

      final active = await pollUntilActive(
        refresh: () async => calls++,
        active: () => false,
        attempts: 3,
        gap: Duration.zero,
      );

      expect(active, isFalse);
      expect(calls, 3);
    });
  });

  test('the website is the one place plans are sold', () {
    expect(websiteUrl, 'https://skms-frontend.vercel.app/');
  });
}

/// Set by the stand-in home button, to prove the barrier blocked it.
bool tapped = false;
