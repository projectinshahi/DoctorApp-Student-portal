import 'package:dr_app/View_model/profile_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Whose course the picker calls "current".
///
/// The preview signs nobody in, but it does put a sample course in the
/// profile — and a new student was asked to confirm changing away from
/// "Sample exam" the first time they picked one.
bool isRealCourse(SelectedCourseInfo? course) =>
    course != null && course.id > 0;

ProfileModel _profile(Map<String, dynamic>? selectedCourse) =>
    ProfileModel.fromJson({
      'id': 43,
      'email': 'student@example.test',
      'name': 'Shareef',
      'role': 'student',
      'status': 'verified',
      if (selectedCourse != null) 'selectedCourse': selectedCourse,
    });

void main() {
  test('the sample course is not a current course', () {
    // DemoContent gives its course a negative id, which no real row has.
    final demo = _profile({'id': -1, 'title': 'Sample exam'});

    expect(isRealCourse(demo.selectedCourse), isFalse);
  });

  test('a real course is', () {
    final real = _profile({'id': 22, 'title': 'GP GULF LICENSING EXAM'});

    expect(isRealCourse(real.selectedCourse), isTrue);
  });

  test('a student who has never chosen one has nothing to change from', () {
    expect(isRealCourse(_profile(null).selectedCourse), isFalse);
  });
}
