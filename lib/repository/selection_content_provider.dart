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
  /// [silent] keeps the current tree on screen while it refetches — used for
  /// background top-ups. The default shows the loading state, which is what a
  /// screen becoming visible wants: the student is looking straight at it and
  /// stale numbers are worse than a moment of shimmer.
  Future<void> loadContent({bool silent = false}) async {
    isLoading = silent ? content == null : true;
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