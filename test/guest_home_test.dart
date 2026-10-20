import 'package:dr_app/models/public_course_model.dart';
import 'package:dr_app/services/public_catalog_service.dart';
import 'package:dr_app/view/guest/guest_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

/// The shape the live endpoint returns — checked against
/// GET /api/courses on the running backend.
Map<String, dynamic> _course(int id, String title,
        {String access = 'free', List<String> exams = const []}) =>
    {
      'id': id,
      'title': title,
      'description': 'DoH',
      'accessType': access,
      'courseTypes': [
        for (var i = 0; i < exams.length; i++)
          {'id': 100 + i, 'title': exams[i]},
      ],
    };

class _FakeCatalog extends PublicCatalogService {
  final List<PublicCourse> courses;
  final bool fails;

  _FakeCatalog(this.courses, {this.fails = false});

  @override
  Future<List<PublicCourse>> fetchCourses() async {
    if (fails) throw Exception('offline');
    return courses;
  }
}

Future<void> _pump(WidgetTester tester, PublicCatalogService service) async {
  tester.view.physicalSize = const Size(440, 956);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(440, 956),
      minTextAdapt: true,
      builder: (context, _) =>
          MaterialApp(home: GuestHomeScreen(service: service)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('a course keeps its exams, which is what a student is choosing', () {
    final course = PublicCourse.fromJson(_course(19, 'Specialist Gulf',
        exams: ['DHA Exam', 'Kuwait Prometric Exam']));

    expect(course.title, 'Specialist Gulf');
    expect(course.types.map((t) => t.title),
        ['DHA Exam', 'Kuwait Prometric Exam']);
  });

  testWidgets('a visitor sees what is inside before being asked to sign in',
      (tester) async {
    await _pump(
      tester,
      _FakeCatalog([
        PublicCourse.fromJson(
            _course(19, 'Specialist Gulf Licensing Exam', exams: ['DHA Exam'])),
        PublicCourse.fromJson(_course(22, 'GP GULF LICENSING EXAM',
            access: 'premium', exams: ['Kuwait Prometric Exam'])),
      ]),
    );

    expect(find.text('Specialist Gulf Licensing Exam'), findsOneWidget);
    expect(find.text('GP GULF LICENSING EXAM'), findsOneWidget);
    expect(find.text('DHA Exam'), findsOneWidget);
    expect(find.text('Kuwait Prometric Exam'), findsOneWidget);
    // The way in is on screen the whole time, not behind a tap.
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('a failed catalogue says so instead of showing an empty shelf',
      (tester) async {
    // "No courses" would read as a product with nothing in it.
    await _pump(tester, _FakeCatalog(const [], fails: true));

    expect(find.textContaining('Could not load the courses'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
