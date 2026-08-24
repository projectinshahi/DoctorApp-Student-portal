import 'package:dr_app/repository/selection_content_provider.dart';
import 'package:dr_app/view/Home/home_screen.dart';
import 'package:dr_app/view/Home/profile/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('Tapping Profile from the bottom navigation opens the profile screen', (tester) async {
    final provider = SelectionContentProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SelectionContentProvider>.value(value: provider),
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
