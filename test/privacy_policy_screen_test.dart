import 'package:dr_app/view/Home/profile/legal_document.dart';
import 'package:dr_app/view/Home/profile/legal_text.dart';
import 'package:dr_app/view/Home/profile/privacy_policy_screen.dart';
import 'package:dr_app/view/Home/profile/terms_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget screen,
    {Size size = const Size(440, 956)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(440, 956),
      minTextAdapt: true,
      builder: (context, _) => MaterialApp(home: screen),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('all nine points are present and in order', (tester) async {
    await _pump(tester, const PrivacyPolicyScreen());

    const titles = [
      'Your account details',
      'What you do while learning',
      'Your subscription',
      'Email we send you',
      'Who else sees it',
      'Comments are public',
      'How it is protected',
      'How long we keep it',
      'Younger students, and changes',
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

  testWidgets('the promises that matter most are stated', (tester) async {
    // Each of these is a commitment a student would care about, and each is
    // grounded in the Scope of Work. Dropping one silently would be the
    // worst kind of edit to this file.
    await _pump(tester, const PrivacyPolicyScreen());

    for (final promise in [
      'never reach us',          // card details stay with Razorpay
      'do not sell',             // no data sale
      'No marketing',            // the four transactional emails only
      'no self-service delete',  // stated rather than hidden
    ]) {
      final finder = find.textContaining(promise);
      await tester.scrollUntilVisible(finder, 300,
          scrollable: find.byType(Scrollable).first);
      expect(finder, findsWidgets, reason: promise);
    }
  });

  testWidgets('both documents are built from the same layout', (tester) async {
    // They are read back to back. A reader should not be able to tell they
    // were written at different times.
    for (final screen in [const TermsScreen(), const PrivacyPolicyScreen()]) {
      await _pump(tester, screen);

      final scaffold =
          tester.widget<LegalScaffold>(find.byType(LegalScaffold));
      expect(scaffold.points.length, lessThanOrEqualTo(10), reason: '$screen');
      expect(scaffold.closing, isNotEmpty, reason: '$screen');

      // Scrolled to: the contact block sits at the foot, and a ListView only
      // builds what is near the viewport.
      final contact = find.text('Questions about this?');
      await tester.scrollUntilVisible(contact, 400,
          scrollable: find.byType(Scrollable).first);
      expect(contact, findsOneWidget, reason: '$screen');
    }
  });

  testWidgets('each document points at its own contact address',
      (tester) async {
    // A privacy request may need to reach someone other than support.
    await _pump(tester, const PrivacyPolicyScreen());
    expect(
        tester.widget<LegalScaffold>(find.byType(LegalScaffold)).contactEmail,
        LegalDetails.privacyEmail);

    await _pump(tester, const TermsScreen());
    expect(
        tester.widget<LegalScaffold>(find.byType(LegalScaffold)).contactEmail,
        LegalDetails.supportEmail);
  });

  testWidgets('the app is named as students know it', (tester) async {
    // The source document says "SAS LMS"; students only ever see this name.
    await _pump(tester, const PrivacyPolicyScreen());

    expect(find.textContaining("Dr. SKM's Academy"), findsWidgets);
    expect(find.textContaining('SAS LMS'), findsNothing);
  });

  testWidgets('the draft banner shows while details are placeholders',
      (tester) async {
    await _pump(tester, const PrivacyPolicyScreen());

    expect(LegalDetails.isIncomplete, isTrue);
    expect(find.textContaining('still to be filled in'), findsOneWidget);
  });

  testWidgets('lays out on a short phone', (tester) async {
    await _pump(tester, const PrivacyPolicyScreen(),
        size: const Size(375, 667));
    expect(tester.takeException(), isNull);
  });
}
