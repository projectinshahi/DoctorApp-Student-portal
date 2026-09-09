// lib/repository/quiz_prefetch.dart
//
// Warms QBank quizzes so opening one shows questions instead of a spinner.
//
// The limit worth knowing: the only endpoint that hands back questions for a
// quiz nobody has attempted is `POST /attempts`, which *creates* the attempt.
// Prefetching with that would mark quizzes as started that the student never
// opened — filling Continue MCQs, flipping rows from Start to Continue, and
// inflating the attemptCount the one-attempt rule is built on. So this warms
// only quizzes that already have an attempt, where `GET /attempts/{id}` is
// read-only and changes nothing.
//
// A never-attempted quiz therefore still costs one call on open. Removing
// that needs a read-only questions endpoint from the backend.
import 'package:flutter/foundation.dart';

import '../models/quiz_model.dart';
import '../models/selection_content_model.dart';
import '../services/quiz_service.dart';

class QuizPrefetch extends ChangeNotifier {
  final QuizService _service;

  QuizPrefetch({QuizService? service}) : _service = service ?? QuizService();

  final Map<int, QuizAttempt> _byLesson = {};
  final Set<int> _inFlight = {};

  /// How many quizzes are sitting ready. Debug and tests only.
  @visibleForTesting
  int get warmCount => _byLesson.length;

  bool isWarm(int lessonId) => _byLesson.containsKey(lessonId);

  /// Hands over a warmed attempt and drops it.
  ///
  /// One shot on purpose. The moment a quiz opens the student starts changing
  /// it, and a second read of this copy would be answers-ago stale.
  QuizAttempt? take(int lessonId) => _byLesson.remove(lessonId);

  /// Warms every quiz in [lessons] that already has an attempt.
  ///
  /// Bounded by the caller — one chapter's worth, fetched while the student
  /// reads the list they are about to tap. Warming the whole course at app
  /// start would be dozens of requests for quizzes most students never open.
  Future<void> warm(Iterable<StudentLessonModel> lessons) async {
    final wanted = <StudentLessonModel>[];
    for (final lesson in lessons) {
      if (!lesson.isQuiz || lesson.locked) continue;
      final info = lesson.attempt;
      // Null means never attempted, and only a POST could fetch that.
      if (info == null) continue;
      if (_byLesson.containsKey(lesson.id) || _inFlight.contains(lesson.id)) {
        continue;
      }
      wanted.add(lesson);
    }
    if (wanted.isEmpty) return;

    // A handful, not the whole course. Enough to cover what anyone drills
    // into next without turning a browse into dozens of requests.
    const maxToWarm = 6;
    if (wanted.length > maxToWarm) wanted.removeRange(maxToWarm, wanted.length);

    _inFlight.addAll(wanted.map((l) => l.id));

    // One at a time, deliberately. These were fired in parallel and it made
    // things worse, not better: the backend is a single instance, and on
    // device the warm reads degraded 852ms, 879ms, 2561ms as they piled up
    // — while the student sat waiting on the quiz they had actually tapped,
    // queued behind work nobody asked for. Background work must never
    // out-compete the foreground.
    for (final lesson in wanted) {
      try {
        final attempt = await _service.fetchAttempt(lesson.attempt!.attemptId);
        _byLesson[lesson.id] = attempt;
        notifyListeners();
      } catch (_) {
        // A warm cache is an optimisation. A failure here means the quiz
        // opens the ordinary way, which is exactly what used to happen.
      } finally {
        _inFlight.remove(lesson.id);
      }
    }
  }

  /// Drops everything. The attempts belong to the account that was signed in,
  /// and a stale one would open the wrong student's answers.
  void clear() {
    _byLesson.clear();
    _inFlight.clear();
    notifyListeners();
  }
}
