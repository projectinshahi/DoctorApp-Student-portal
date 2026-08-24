import 'package:flutter/material.dart';

import '../View_model/selection_model.dart';
import '../services/selection_service.dart';

class SelectionProvider extends ChangeNotifier {
  final SelectionService _service = SelectionService();

  bool isSaving = false;
  String? errorMessage;
  SelectionResult? currentSelection;

  Future<bool> selectCourse({int? courseId, int? courseTypeId}) async {
    isSaving = true;
    errorMessage = null;
    notifyListeners();

    try {
      currentSelection = await _service.selectCourse(
        courseId: courseId,
        courseTypeId: courseTypeId,
      );
      isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      isSaving = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> loadCurrentSelection() async {
    try {
      currentSelection = await _service.getSelectedCourse();
      notifyListeners();
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }
}