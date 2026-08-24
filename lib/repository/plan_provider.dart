// lib/provider/plan_provider.dart
import 'package:flutter/material.dart';
import '../View_model/plan_model.dart';
import '../services/plan_service.dart';

class PlanProvider extends ChangeNotifier {
  final PlanService _service = PlanService();

  bool isLoadingPlans = false;
  String? plansErrorMessage;
  List<PlanModel> plans = [];

  bool isSubscribing = false;
  String? subscribeErrorMessage;

  Future<void> loadPlans(int courseId) async {
    isLoadingPlans = true;
    plansErrorMessage = null;
    notifyListeners();

    try {
      plans = await _service.getPlansForCourse(courseId);
    } catch (e) {
      plansErrorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoadingPlans = false;
      notifyListeners();
    }
  }

  Future<bool> subscribe(int planId) async {
    isSubscribing = true;
    subscribeErrorMessage = null;
    notifyListeners();

    try {
      await _service.subscribeToPlan(planId);
      isSubscribing = false;
      notifyListeners();
      return true;
    } catch (e) {
      subscribeErrorMessage = e.toString().replaceFirst('Exception: ', '');
      isSubscribing = false;
      notifyListeners();
      return false;
    }
  }
}