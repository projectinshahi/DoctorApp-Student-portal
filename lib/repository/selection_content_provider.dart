// lib/provider/selection_content_provider.dart
import 'package:flutter/foundation.dart';
import '../models/selection_content_model.dart';
import '../services/lesson_progress_service.dart' show LessonProgress;
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

  /// Writes the server's answer to a progress call straight into the tree.
  ///
  /// The acceptance criterion is that the tick appears the moment a video
  /// crosses the threshold — and the crossing is reported on the progress
  /// call the player already makes. Waiting for the next /selection/content
  /// would leave the row stale for as long as the student keeps watching.
  void applyProgress(LessonProgress progress) {
    final current = content;
    if (current == null) return;

    var touched = false;

    final chapters = [
      for (final chapter in current.chapters)
        chapter.withLessons([
          for (final lesson in chapter.lessons)
            if (lesson.id == progress.lessonId)
              () {
                touched = true;
                return lesson.copyWith(
                  // Straight from the server. `copyWith` refuses to turn a
                  // tick back off, so a rewind cannot clear it.
                  completed: progress.completed,
                  lastPositionSeconds: progress.lastPositionSeconds,
                  watchedPercent: progress.watchedPercent,
                  durationSeconds: progress.durationSeconds,
                );
              }()
            else
              lesson,
        ]),
    ];

    // Nothing matched — a deep link into a lesson outside the loaded tree.
    // Rebuilding for that would be a wasted frame.
    if (!touched) return;

    content = current.withChapters(chapters);
    notifyListeners();
  }
}