// lib/provider/plan_provider.dart
import 'package:flutter/material.dart';
import '../View_model/plan_model.dart';
import '../services/plan_service.dart';

class PlanProvider extends ChangeNotifier {
  final PlanService _service = PlanService();

  bool isLoadingPlans = false;
  String? plansErrorMessage;
  List<PlanModel> plans = [];

  /// The course the loaded plans belong to. A different course means the
  /// cached list is the wrong list, so that one does show the spinner.
  int? _loadedCourseId;

  Future<void> loadPlans(int courseId) async {
    isLoadingPlans = plans.isEmpty || _loadedCourseId != courseId;
    plansErrorMessage = null;
    notifyListeners();

    try {
      plans = await _service.getPlansForCourse(courseId);
      _loadedCourseId = courseId;
    } catch (e) {
      plansErrorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoadingPlans = false;
      notifyListeners();
    }
  }
}