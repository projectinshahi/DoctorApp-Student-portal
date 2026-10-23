import 'package:dr_app/widget/app_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

/// The bar after the phone has been turned.
///
/// Playing a video forces landscape, and ScreenUtil's .h and .sp are taken
/// from the screen's current height — so the bar came back from a video
/// squashed, with its labels shrunk away. These pump it at the sizes that
/// used to break it.
Future<void> _pump(WidgetTester tester, Size screen,
    {EdgeInsets viewPadding = EdgeInsets.zero}) async {
  tester.view.physicalSize = screen;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(440, 956),
      minTextAdapt: true,
      builder: (context, _) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: screen, viewPadding: viewPadding),
          child: Scaffold(
            bottomNavigationBar:
                AppBottomNav(currentIndex: 0, onTap: (_) {}),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  for (final entry in <String, Size>{
    'a tall phone': const Size(440, 956),
    'a short phone': const Size(360, 640),
    'landscape, as a video leaves it': const Size(956, 440),
  }.entries) {
    testWidgets('every label is readable on ${entry.key}', (tester) async {
      await _pump(tester, entry.value);

      for (final label in ['Home', 'QBank', 'Tests', 'AI Videos', 'Recall']) {
        expect(find.text(label), findsOneWidget);
      }

      // Not scaled away: the label a narrow bar squeezes hardest is the
      // longest one, and it still has to be legible.
      final painted = tester.renderObject<RenderBox>(find.text('AI Videos'));
      expect(painted.size.height, greaterThan(8));
    });
  }

  testWidgets('the bar keeps its height whichever way the phone is held',
      (tester) async {
    await _pump(tester, const Size(440, 956));
    final portrait =
        tester.getSize(find.byType(AppBottomNav).first).height;

    await _pump(tester, const Size(956, 440));
    final landscape =
        tester.getSize(find.byType(AppBottomNav).first).height;

    expect(landscape, portrait,
        reason: 'it used to shrink with the screen and never grow back');
  });

  testWidgets('it clears the system navigation, whatever shape it is',
      (tester) async {
    // Gesture bar and three buttons give very different insets, and the bar
    // sat on top of the buttons on the phone in the photo.
    await _pump(tester, const Size(440, 956));
    final noInset = tester.getSize(find.byType(AppBottomNav)).height;

    await _pump(tester, const Size(440, 956),
        viewPadding: const EdgeInsets.only(bottom: 48));
    final withButtons = tester.getSize(find.byType(AppBottomNav)).height;

    expect(withButtons, greaterThan(noInset));
  });
}
