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

  /// True once a fetch has come back. What separates "nothing here yet" from
  /// "here is what we have, and a newer copy is on the way".
  bool _loadedOnce = false;

  /// Throws the cached tree away, so the next load spins instead of showing
  /// what it has.
  ///
  /// For changes the cache cannot survive rather than merely lag behind:
  /// subscribing unlocks every lesson, and switching course replaces the tree
  /// with a different one. Showing the old answer there is wrong, not stale.
  void invalidate() {
    content = null;
    _loadedOnce = false;
    notifyListeners();
  }

  /// Refetches the whole tree. Safe to fire on every screen entry.
  ///
  /// The spinner shows only on the very first load. After that the fetch runs
  /// underneath whatever is already on screen and swaps the content in when
  /// it lands, so returning to a tab shows the tab, not a loading state.
  Future<void> loadContent() async {
    isLoading = !_loadedOnce;
    errorMessage = null;
    sessionExpired = false;
    notifyListeners();

    final result = await _service.fetchSelectionContent();

    isLoading = false;
    if (result.isSuccess) {
      content = result.content;
      _loadedOnce = true;
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