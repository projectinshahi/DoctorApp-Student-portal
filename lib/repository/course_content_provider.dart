import 'package:flutter/foundation.dart';
import '../services/course_service.dart';
import 'course_content.dart';

class CourseContentProvider extends ChangeNotifier {
  final CourseService service;
  CourseContentProvider(this.service);

  SelectedContent? content;
  bool loading = false;
  String? error;

  List<Chapter> get chapters => content?.chapters ?? const [];
  bool get hasSelection => content?.hasSelection ?? false;

  /// Call on app start and after changing the selection.
  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      content = await service.getSelectedContent();
    } on ApiException catch (e) {
      error = e.message;
    } catch (e) {
      error = 'Could not reach the server';
    }
    loading = false;
    notifyListeners();
  }

  /// Save the pick, then reload the chapters/lessons for it.
  Future<bool> selectType({required int courseId, required int courseTypeId}) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await service.selectCourseType(courseId: courseId, courseTypeId: courseTypeId);
      content = await service.getSelectedContent();
      loading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      error = e.message;
      loading = false;
      notifyListeners();
      return false;
    }
  }
}
