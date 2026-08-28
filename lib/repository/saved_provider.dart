// lib/repository/saved_provider.dart
import 'package:flutter/foundation.dart';

import '../models/quiz_model.dart' show QuizException;
import '../models/saved_model.dart';
import '../services/saved_service.dart';

/// Bookmarks, app-wide. Registered globally rather than per screen because
/// the badge on the QBank card, the toggle inside a quiz and the saved list
/// all have to agree — three copies of this state would drift the moment one
/// of them saved something.
class SavedProvider extends ChangeNotifier {
  final SavedService _service = SavedService();

  int questionCount = 0;
  int lessonCount = 0;

  List<SavedQuestion> questions = const [];
  List<SavedLesson> lessons = const [];

  bool isLoadingQuestions = false;
  bool isLoadingLessons = false;
  String? errorMessage;

  /// Ids only — what the toggles read. Kept separate from [questions] so a
  /// bookmark icon is correct before the full list has ever been fetched.
  final Set<int> _savedQuestionIds = {};
  final Set<int> _savedLessonIds = {};

  /// Toggles already in flight, so a double tap can't fire two writes.
  final Set<int> _busyQuestions = {};
  final Set<int> _busyLessons = {};

  bool _loadedOnce = false;

  /// Fetches both lists the first time something needs them. Called once the
  /// student is authenticated — not from main(), where these calls would go
  /// out before there is a token and come back 401.
  Future<void> ensureLoaded() async {
    if (_loadedOnce) return;
    _loadedOnce = true;
    await Future.wait([loadQuestions(), loadLessons()]);
  }

  bool isQuestionSaved(int questionId) => _savedQuestionIds.contains(questionId);
  bool isLessonSaved(int lessonId) => _savedLessonIds.contains(lessonId);

  // ── Questions ────────────────────────────────────────────────
  Future<void> loadQuestions() async {
    isLoadingQuestions = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await _service.fetchQuestions();
      questions = response.questions;
      questionCount = response.count;
      _savedQuestionIds
        ..clear()
        ..addAll(response.questions.map((q) => q.questionId));
    } on QuizException catch (e) {
      errorMessage = e.message;
    }

    isLoadingQuestions = false;
    notifyListeners();
  }

  /// Optimistic: the icon flips immediately and rolls back if the write
  /// fails. POST is an upsert and DELETE on something already gone answers
  /// 200, so replaying a toggle is safe — only a real network failure rolls
  /// back.
  Future<void> toggleQuestion(int questionId) async {
    if (_busyQuestions.contains(questionId)) return;

    final saving = !isQuestionSaved(questionId);
    _busyQuestions.add(questionId);
    saving ? _savedQuestionIds.add(questionId) : _savedQuestionIds.remove(questionId);
    questionCount += saving ? 1 : -1;
    notifyListeners();

    try {
      final count = saving
          ? await _service.saveQuestion(questionId)
          : await _service.unsaveQuestion(questionId);

      // -1 means the server sent no count; keep the optimistic one rather
      // than displaying a wrong number.
      if (count >= 0) questionCount = count;

      // The cached list is now stale either way — drop the row on unsave, and
      // let the next open refetch for a save.
      if (!saving) {
        questions = questions.where((q) => q.questionId != questionId).toList();
      }
    } on QuizException catch (e) {
      saving ? _savedQuestionIds.remove(questionId) : _savedQuestionIds.add(questionId);
      questionCount += saving ? -1 : 1;
      errorMessage = e.message;
    }

    _busyQuestions.remove(questionId);
    notifyListeners();
  }

  // ── Lessons ──────────────────────────────────────────────────
  Future<void> loadLessons() async {
    isLoadingLessons = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await _service.fetchLessons();
      lessons = response.lessons;
      lessonCount = response.count;
      _savedLessonIds
        ..clear()
        ..addAll(response.lessons.map((l) => l.lessonId));
    } on QuizException catch (e) {
      errorMessage = e.message;
    }

    isLoadingLessons = false;
    notifyListeners();
  }

  Future<void> toggleLesson(int lessonId) async {
    if (_busyLessons.contains(lessonId)) return;

    final saving = !isLessonSaved(lessonId);
    _busyLessons.add(lessonId);
    saving ? _savedLessonIds.add(lessonId) : _savedLessonIds.remove(lessonId);
    lessonCount += saving ? 1 : -1;
    notifyListeners();

    try {
      final count = saving
          ? await _service.saveLesson(lessonId)
          : await _service.unsaveLesson(lessonId);
      if (count >= 0) lessonCount = count;

      if (!saving) {
        lessons = lessons.where((l) => l.lessonId != lessonId).toList();
      }
    } on QuizException catch (e) {
      saving ? _savedLessonIds.remove(lessonId) : _savedLessonIds.add(lessonId);
      lessonCount += saving ? -1 : 1;
      errorMessage = e.message;
    }

    _busyLessons.remove(lessonId);
    notifyListeners();
  }

  /// Sign-out: bookmarks belong to the account that was signed in.
  void clear() {
    _loadedOnce = false;
    questionCount = 0;
    lessonCount = 0;
    questions = const [];
    lessons = const [];
    _savedQuestionIds.clear();
    _savedLessonIds.clear();
    notifyListeners();
  }
}
