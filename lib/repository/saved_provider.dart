import 'dart:convert';
// lib/repository/saved_provider.dart
import '../core/utils/load_timer.dart';
import 'package:flutter/foundation.dart';

import '../core/constant/local_storage.dart';
import '../models/quiz_model.dart' show QuizException;
import '../models/saved_model.dart';
import '../services/saved_service.dart';

/// Bookmarks, app-wide. Registered globally rather than per screen because
/// the badge on the QBank card, the toggle inside a quiz and the saved list
/// all have to agree — three copies of this state would drift the moment one
/// of them saved something.
class SavedProvider extends ChangeNotifier {
  final SavedService _service;

  SavedProvider({SavedService? service}) : _service = service ?? SavedService() {
    _restore();
  }

  /// Paints the last known bookmarks before the network is asked. /saved
  /// measured 5010ms cold on device.
  Future<void> _restore() async {
    if (_fetched) return;
    try {
      final stored = await LocalStorage.getCached(LocalStorage.savedKey);
      if (stored == null || stored.isEmpty || _fetched) return;

      final bundle = SavedBundle.fromJson(jsonDecode(stored));
      counts = bundle.counts;
      questions = bundle.questions;
      lessons = bundle.lessons;
      questionCount = bundle.counts['question'] ?? bundle.questions.length;
      lessonCount = bundle.counts['lesson'] ?? bundle.lessons.length;
      _savedQuestionIds
        ..clear()
        ..addAll(bundle.questions.map((q) => q.questionId));
      _savedLessonIds
        ..clear()
        ..addAll(bundle.lessons.map((l) => l.lessonId));

      // Not _fetched: that means the server answered, and this did not. The
      // next loadAll still shows nothing stale as authoritative.
      isLoadingQuestions = false;
      isLoadingLessons = false;
      notifyListeners();
    } catch (_) {
      // Restoring is an optimisation and must never break the screen.
    }
  }

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

  /// A fetch has come back. Distinct from [_loadedOnce], which only means one
  /// was started — the spinner has to wait for the answer, not the request.
  /// Kept separate from `questions.isEmpty` so an account with no bookmarks
  /// at all stops spinning too.
  bool _fetched = false;

  /// A save happened and the cached lists no longer match the server.
  ///
  /// Unsaving drops the row locally, so the list stays right. Saving cannot:
  /// a toggle knows only an id, not the question text or the lesson title, so
  /// there is no row to insert. Rather than show a list that is missing what
  /// the student just saved, this marks the cache wrong and the next load
  /// spins — the one case where the spinner is still the honest answer.
  bool _staleLists = false;

  /// The full counts map from the server: all, question, video, text, quiz,
  /// lesson. The Bookmarks chips bind to this rather than to list lengths,
  /// so filtering to videos does not make the MCQ chip read zero.
  Map<String, int> counts = const {};

  /// Fetches everything the first time something needs it. Called once the
  /// student is authenticated — not from main(), where these calls would go
  /// out before there is a token and come back 401.
  Future<void> ensureLoaded() async {
    if (_loadedOnce) return;
    _loadedOnce = true;
    await loadAll();
  }

  /// One call for both lists and every count, replacing the two-request
  /// version. Cheaper, and the counts come back consistent with each other
  /// instead of from two responses taken a moment apart.
  /// The request currently in flight, if any.
  Future<void>? _inFlight;

  /// Fetches both lists, sharing one request between callers.
  ///
  /// Five places call this — the home screen, the QBank tab, the bookmarks
  /// screen twice, and the sign-in warm-up — and one navigation touches
  /// several within a second. On device that showed as the same 113-byte
  /// response fetched twice back to back, 2489ms and 2526ms, neither of
  /// which the student needed to wait for twice.
  ///
  /// Sharing, not caching: a call made after the first finishes is its own
  /// request, so a bookmark added elsewhere still shows up.
  Future<void> loadAll() =>
      _inFlight ??= _fetchAll().whenComplete(() => _inFlight = null);

  Future<void> _fetchAll() async {
    // The lists stay up while the refetch runs. This screen is opened and
    // closed constantly, and a spinner between every visit is the flicker.
    isLoadingQuestions = !_fetched || _staleLists;
    isLoadingLessons = !_fetched || _staleLists;
    errorMessage = null;
    notifyListeners();

    try {
      final bundle = await timedLoad('bookmarks', _service.fetchAll,
          detail: (b) =>
              '${b.questions.length} MCQs, ${b.lessons.length} lessons');

      counts = bundle.counts;
      questions = bundle.questions;
      lessons = bundle.lessons;
      questionCount = bundle.counts['question'] ?? bundle.questions.length;
      lessonCount = bundle.counts['lesson'] ?? bundle.lessons.length;

      _savedQuestionIds
        ..clear()
        ..addAll(bundle.questions.map((q) => q.questionId));
      _savedLessonIds
        ..clear()
        ..addAll(bundle.lessons.map((l) => l.lessonId));
      _fetched = true;
      _staleLists = false;
    } on QuizException catch (e) {
      errorMessage = e.message;
    }

    isLoadingQuestions = false;
    isLoadingLessons = false;
    notifyListeners();
  }

  int countOf(String type) => counts[type] ?? 0;

  /// A fetch is in flight. `loadAll` sets both flags, so either one is enough
  /// — screens should not have to know which list they are waiting on.
  bool get isLoading => isLoadingQuestions || isLoadingLessons;

  /// Seeds from `isSaved` on lessons the app already has, so a bookmark icon
  /// is right on first paint instead of flickering once the saved list lands.
  /// Ids only — never overwrites a toggle already in flight.
  void seedLessons(Iterable<int> savedLessonIds) {
    final incoming = savedLessonIds.toSet();
    if (incoming.every(_savedLessonIds.contains)) return;
    _savedLessonIds.addAll(incoming.where((id) => !_busyLessons.contains(id)));
    notifyListeners();
  }

  bool isQuestionSaved(int questionId) => _savedQuestionIds.contains(questionId);
  bool isLessonSaved(int lessonId) => _savedLessonIds.contains(lessonId);

  // ── Questions ────────────────────────────────────────────────

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

      if (saving) {
        _staleLists = true;
      } else {
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

      if (saving) {
        _staleLists = true;
      } else {
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
    _fetched = false;
    _staleLists = false;
    questionCount = 0;
    lessonCount = 0;
    questions = const [];
    lessons = const [];
    _savedQuestionIds.clear();
    _savedLessonIds.clear();
    notifyListeners();
  }
}
