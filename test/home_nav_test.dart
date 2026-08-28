import 'package:dr_app/repository/profile_provider.dart';
import 'package:dr_app/repository/saved_provider.dart';
import 'package:dr_app/repository/selection_content_provider.dart';
import 'package:dr_app/view/Home/home_screen.dart';
import 'package:dr_app/view/Home/profile/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('Tapping Profile from the bottom navigation opens the profile screen', (tester) async {
    // A phone-sized surface, matching the app's design size. The default
    // 800x600 test window is wider and much shorter than any device this ships
    // to, and the home header legitimately does not fit in 600px of height.
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final provider = SelectionContentProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SelectionContentProvider>.value(value: provider),
          // Homescreen reads both on its first frame; without them the tree
          // throws ProviderNotFoundException before the nav bar even builds.
          ChangeNotifierProvider<ProfileProvider>(create: (_) => ProfileProvider()),
          ChangeNotifierProvider<SavedProvider>(create: (_) => SavedProvider()),
        ],
        child: ScreenUtilInit(
          designSize: const Size(440, 956),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, child) => const MaterialApp(home: Homescreen()),
        ),
      ),
    );

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsOneWidget);
  });
}
