import 'dart:async';
import 'dart:convert';
// lib/provider/selection_content_provider.dart
import '../core/utils/load_timer.dart';
import 'package:flutter/foundation.dart';
import '../core/constant/local_storage.dart';
import '../models/selection_content_model.dart';
import '../services/lesson_progress_service.dart' show LessonProgress;
import '../services/selection_content_service.dart';

class SelectionContentProvider extends ChangeNotifier {
  final SelectionContentService _service;

  SelectionContentProvider({SelectionContentService? service})
      : _service = service ?? SelectionContentService() {
    _restore();
  }

  /// Paints the last known course before the network is even asked.
  ///
  /// This is the difference between opening on chapters and opening on a
  /// spinner. A SharedPreferences read is a few milliseconds against a tree
  /// fetch measured on device at 1.7-6.5s, so the stored copy is on screen
  /// long before the fresh one lands, and the fresh one swaps in underneath.
  ///
  /// Stale by one refresh, which for chapter titles and lesson lists is
  /// invisible. Scores and attempt state arrive with the refetch.
  Future<void> _restore() async {
    if (content != null) return;
    try {
      final stored = await LocalStorage.getCourseTree();
      if (stored == null || stored.isEmpty) return;
      // A network answer that arrived first always wins.
      if (content != null) return;

      content = SelectionContentModel.fromJson(jsonDecode(stored));
      isLoading = false;
      notifyListeners();
    } catch (_) {
      // A tree written by an older build, or storage that is unavailable.
      // Either way there is nothing to restore and the fetch already under
      // way covers it — restoring is an optimisation and must never be able
      // to take the app down.
      try {
        await LocalStorage.clearCourseTree();
      } catch (_) {
        // Storage itself is the thing that failed. Nothing more to do.
      }
    }
  }

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
    // The stored copy is just as wrong — a different course, or a different
    // account — so it must go too, or the next launch restores it.
    unawaited(LocalStorage.clearCourseTree());
    notifyListeners();
  }

  /// Refetches the whole tree. Safe to fire on every screen entry.
  ///
  /// The spinner shows only on the very first load. After that the fetch runs
  /// underneath whatever is already on screen and swaps the content in when
  /// it lands, so returning to a tab shows the tab, not a loading state.
  /// The request currently in flight, if any.
  Future<void>? _inFlight;

  /// Refetches the whole tree, sharing one request between callers.
  ///
  /// Seven screens fire this on entry, and navigating touches several within
  /// a second — Home, QBank, a subject, a lesson. Measured on device, that
  /// queued eight overlapping fetches of the same three chapters and the
  /// waits stacked: 1.7s, 2.4s, 4.2s, 6.5s. They were not slow requests, they
  /// were the same request eight times over.
  ///
  /// A second caller now awaits the first instead of starting another.
  Future<void> loadContent() => _inFlight ??=
      _fetch().whenComplete(() => _inFlight = null);

  Future<void> _fetch() async {
    isLoading = !_loadedOnce;
    errorMessage = null;
    sessionExpired = false;
    notifyListeners();

    final result = await timedLoad(
      'course tree',
      _service.fetchSelectionContent,
      detail: (r) => r.isSuccess
          ? '${r.content?.chapters.length ?? 0} chapters'
          : 'error',
    );

    isLoading = false;
    if (result.isSuccess) {
      content = result.content;
      _loadedOnce = true;
      final raw = result.rawJson;
      // Not awaited: the screen has its data, and the write is for the *next*
      // launch. Making the student wait on a disk write would be backwards.
      if (raw != null) unawaited(LocalStorage.saveCourseTree(raw));
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