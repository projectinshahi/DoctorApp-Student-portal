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

  /// Refetches the whole tree. Callers can fire this on every screen entry:
  /// the shimmer only shows on a cold load, so a refresh over content that is
  /// already on screen swaps it silently instead of flashing.
  Future<void> loadContent() async {
    isLoading = content == null;
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