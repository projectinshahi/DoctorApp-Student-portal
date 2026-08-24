// lib/provider/selection_content_provider.dart
import 'package:flutter/foundation.dart';
import '../models/selection_content_model.dart';
import '../services/selection_content_service.dart';

class SelectionContentProvider extends ChangeNotifier {
  final SelectionContentService _service = SelectionContentService();

  bool isLoading = false;
  String? errorMessage;
  bool sessionExpired = false;
  SelectionContentModel? content;

  Future<void> loadContent() async {
    isLoading = true;
    errorMessage = null;
    sessionExpired = false;
    notifyListeners();

    final result = await _service.fetchSelectionContent();

    isLoading = false;
    if (result.isSuccess) {
      content = result.content;
    } else {
      errorMessage = result.errorMessage;
      sessionExpired = result.sessionExpired;
    }
    notifyListeners();
  }
}