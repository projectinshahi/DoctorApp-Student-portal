import 'package:dr_app/view/Home/profile/legal_document.dart';
import 'package:dr_app/view/Home/profile/legal_text.dart';
import 'package:dr_app/view/Home/profile/terms_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester,
    {Size size = const Size(440, 956)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(440, 956),
      minTextAdapt: true,
      builder: (context, _) => const MaterialApp(home: TermsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('all nine points are present and in order', (tester) async {
    await _pump(tester);

    const titles = [
      'One account, one person',
      'Free and premium content',
      'Subscriptions and payment',
      'How quizzes are scored',
      'Video lessons',
      'The content stays ours',
      'Screenshots and recording',
      'Comments',
      'Misuse, and changes to these terms',
    ];

    // Scrolled to, not just queried: a ListView only builds what is near the
    // viewport, so this actually walks the whole document.
    for (final title in titles) {
      final finder = find.text(title);
      await tester.scrollUntilVisible(finder, 300,
          scrollable: find.byType(Scrollable).first);
      expect(finder, findsOneWidget, reason: title);
    }
  });

  testWidgets('the rules the platform actually enforces are stated',
      (tester) async {
    // Each of these is a business rule from the Scope of Work. If one is
    // dropped in a later edit, the document quietly stops matching the app.
    await _pump(tester);

    for (final rule in [
      'only one device can be signed in',   // single session
      'watched 90% of it',                  // video completion
      'runs on our server',                 // server-enforced timer
      'best attempt counts',                // leaderboard
      'Razorpay',                           // payment gateway
      'reviewed afterwards',                // post-moderation
    ]) {
      final finder = find.textContaining(rule);
      await tester.scrollUntilVisible(finder, 300,
          scrollable: find.byType(Scrollable).first);
      expect(finder, findsWidgets, reason: rule);
    }
  });

  testWidgets('it stays short enough to read', (tester) async {
    // The point of the rewrite, and a guard rather than a style note: the
    // previous version reached sixteen sections one edit at a time.
    await _pump(tester);

    final scaffold = tester.widget<LegalScaffold>(find.byType(LegalScaffold));
    expect(scaffold.points.length, lessThanOrEqualTo(10));
    for (final point in scaffold.points) {
      expect(point.body.length, lessThan(400), reason: point.title);
    }
  });

  testWidgets('the draft banner shows while details are placeholders',
      (tester) async {
    await _pump(tester);

    // It is driven by the values themselves, so it cannot be left up after
    // they are filled, or forgotten while they are not.
    expect(LegalDetails.isIncomplete, isTrue);
    expect(find.textContaining('still to be filled in'), findsOneWidget);
  });

  testWidgets('the app is named as students know it', (tester) async {
    // The source document says "SAS LMS"; students only ever see this name.
    await _pump(tester);

    expect(LegalDetails.appName, "Dr. SKM's Academy");
    expect(find.textContaining("Dr. SKM's Academy"), findsWidgets);
    expect(find.textContaining('SAS LMS'), findsNothing);
  });

  testWidgets('lays out on a short phone', (tester) async {
    await _pump(tester, size: const Size(375, 667));
    expect(tester.takeException(), isNull);
  });

  test('completeness is decided by the values, not a flag', () {
    // A hand-set boolean would drift from the content it describes.
    expect(LegalDetails.companyName.startsWith('['), isTrue);
    expect(LegalDetails.isIncomplete, isTrue);
  });
}
