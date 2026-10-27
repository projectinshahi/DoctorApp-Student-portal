import 'dart:async';

import 'package:dr_app/View_model/Course_get_model.dart';
import 'package:dr_app/View_model/profile_model.dart';
import 'package:dr_app/core/theam%20/app_color.dart';
import 'package:dr_app/repository/course_get_provider.dart';
import 'package:dr_app/repository/profile_provider.dart';
import 'package:dr_app/repository/selection_provider.dart';
import 'package:dr_app/view/subjectSelection/select_exam_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Courses extends CourseListGetProvider {
  @override
  Future<void> fetchCourses({
    String? status,
    String? accessType,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    courses = [
      CourseListGetModel.fromJson({
        'id': 22,
        'title': 'GP GULF LICENSING EXAM',
        'status': 'published',
        'accessType': 'premium',
        'courseTypes': [
          {'id': 36, 'title': 'Kuwait Prometric Exam', 'status': 'published', 'accessType': 'premium'},
          {'id': 37, 'title': 'DHA Exam', 'status': 'published', 'accessType': 'premium'},
        ],
      }),
    ];
    notifyListeners();
  }
}

/// Holds the save open until the test lets it finish.
class _Selection extends SelectionProvider {
  final saving = Completer<bool>();
  int? savedType;

  @override
  Future<bool> selectCourse({int? courseId, int? courseTypeId}) {
    savedType = courseTypeId;
    isSaving = true;
    notifyListeners();
    return saving.future;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<_Selection> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final profile = ProfileProvider()
      ..profile = ProfileModel.fromJson({
        'id': 1,
        'email': 'a@b.c',
        'name': 'Student',
        'role': 'student',
        'status': 'active',
        'selectedCourse': {'id': 22, 'title': 'GP GULF LICENSING EXAM'},
        'selectedCourseType': {'id': 36, 'title': 'Kuwait Prometric Exam'},
      });
    final selection = _Selection();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ProfileProvider>.value(value: profile),
          ChangeNotifierProvider<CourseListGetProvider>(
              create: (_) => _Courses()),
          ChangeNotifierProvider<SelectionProvider>.value(value: selection),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (context, _) => const MaterialApp(
            home: ExamSelectionScreen(
                accessToken: '', refreshToken: '', deviceId: ''),
          ),
        ),
      ),
    );
    await tester.pump();
    return selection;
  }

  testWidgets('the current course is marked, and Done on it saves nothing',
      (tester) async {
    final selection = await pump(tester);

    expect(find.text('Current'), findsOneWidget);
    // On the Kuwait row, which starts out ticked.
    final kuwaitRow = find.ancestor(
        of: find.text('Kuwait Prometric Exam'), matching: find.byType(Row));
    expect(find.descendant(of: kuwaitRow.first, matching: find.text('Current')),
        findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Change your course?'), findsNothing);
    expect(selection.savedType, isNull);
  });

  testWidgets('a new course is confirmed first, and saving keeps it green',
      (tester) async {
    final selection = await pump(tester);

    await tester.tap(find.text('DHA Exam'));
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // Asked, naming both courses.
    expect(find.text('Change your course?'), findsOneWidget);
    expect(find.textContaining('Kuwait Prometric Exam', findRichText: true),
        findsWidgets);

    // Keeping the current course saves nothing.
    await tester.tap(find.text('Keep current course'));
    await tester.pumpAndSettle();
    expect(selection.savedType, isNull);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change course'));
    await tester.pump();

    expect(selection.savedType, 37);
    // Saving: the button stays green, with a white spinner on it.
    await tester.pump(const Duration(milliseconds: 500)); // dialog gone
    final button = tester.widget<ElevatedButton>(find.ancestor(
        of: find.byType(CircularProgressIndicator),
        matching: find.byType(ElevatedButton)));
    expect(button.onPressed, isNull);
    expect(button.style!.backgroundColor!.resolve({WidgetState.disabled}),
        AppColor.buttoncolor);
    final spinner = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator));
    expect(spinner.color, Colors.white);
  });
}
