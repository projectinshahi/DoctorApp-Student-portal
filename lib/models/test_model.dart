// lib/models/test_model.dart
//
// Grand tests: a timed paper with negative marking, a leaderboard, and
// unlimited retakes.
//
//   GET    /users/me/courses/:id/tests
//   POST   /users/me/tests/:id/attempts            201 fresh · 200 resumed
//   PATCH  /users/me/test-attempts/:id/answers/:q  { selectedOption }
//   DELETE /users/me/test-attempts/:id/answers/:q  back to skipped
//   POST   /users/me/test-attempts/:id/submit
//   GET    /users/me/test-attempts/:id/result
//   GET    /users/me/tests/:id/leaderboard?limit=50

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}') ?? 0;
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}') ?? 0;
}

DateTime? _toDate(dynamic value) =>
    value == null ? null : DateTime.tryParse(value.toString());

/// What the student did on this test last time. Decides the card's button
/// with no second call.
class TestLastAttempt {
  final int attemptId;
  final DateTime? startedAt;
  final DateTime? submittedAt;

  /// Null until submitted.
  final double? score;

  final bool inProgress;

  TestLastAttempt({
    required this.attemptId,
    this.startedAt,
    this.submittedAt,
    this.score,
    required this.inProgress,
  });

  factory TestLastAttempt.fromJson(Map<String, dynamic> json) => TestLastAttempt(
        attemptId: _toInt(json['attemptId']),
        startedAt: _toDate(json['startedAt']),
        submittedAt: _toDate(json['submittedAt']),
        score: json['score'] == null ? null : _toDouble(json['score']),
        inProgress: json['inProgress'] == true,
      );
}

/// One published test. Drafts never reach the app.
class TestSummary {
  final int id;
  final String name;
  final String type;
  final int totalQuestions;
  final int durationMinutes;
  final double marksCorrect;

  /// Genuinely negative — -0.25 here. Shown on the card before the student
  /// starts, because negative marking changes how they play the paper.
  final double marksIncorrect;

  /// Retakes are unlimited, so this only ever grows.
  final int attemptCount;

  final TestLastAttempt? lastAttempt;

  TestSummary({
    required this.id,
    required this.name,
    required this.type,
    required this.totalQuestions,
    required this.durationMinutes,
    required this.marksCorrect,
    required this.marksIncorrect,
    required this.attemptCount,
    this.lastAttempt,
  });

  factory TestSummary.fromJson(Map<String, dynamic> json) => TestSummary(
        id: _toInt(json['id']),
        name: json['name']?.toString() ?? 'Test',
        type: json['type']?.toString() ?? '',
        totalQuestions: _toInt(json['totalQuestions']),
        durationMinutes: _toInt(json['durationMinutes']),
        marksCorrect: _toDouble(json['marksCorrect']),
        marksIncorrect: _toDouble(json['marksIncorrect']),
        attemptCount: _toInt(json['attemptCount']),
        lastAttempt: json['lastAttempt'] is Map
            ? TestLastAttempt.fromJson(
                Map<String, dynamic>.from(json['lastAttempt'] as Map))
            : null,
      );

  static List<TestSummary> listFromJson(Map<String, dynamic> json) {
    final raw = (json['tests'] as List?) ?? const [];
    return [
      for (final test in raw.whereType<Map>())
        TestSummary.fromJson(Map<String, dynamic>.from(test)),
    ];
  }

  bool get isInProgress => lastAttempt?.inProgress == true;
  bool get isSubmitted => lastAttempt?.submittedAt != null;

  /// Started, never submitted, and the clock has run out.
  ///
  /// The server auto-submits an expired paper, but the list can be read
  /// before that lands — and a paper whose time is gone has no work left in
  /// it either way. Without this it sat on the "to sit" tab forever reading
  /// "Time is up", which is the one thing a student cannot act on.
  bool get isTimedOut => isInProgress && secondsLeftOnAttempt == 0;

  /// Nothing left to do: submitted, or out of time.
  bool get isFinished => isSubmitted || isTimedOut;
  bool get hasNegativeMarking => marksIncorrect < 0;

  /// What a perfect paper scores. The list endpoint sends the two factors but
  /// not the product, and a score means nothing without it — "0.75" reads
  /// very differently out of 2 than out of 200.
  double get totalMarks => totalQuestions * marksCorrect;

  /// Seconds left on a running attempt, or null when nothing is running.
  ///
  /// Derived, because the list endpoint does not send it — but it is the same
  /// arithmetic the server does (startedAt + durationMinutes), so the card
  /// can show a live countdown without a second call. The paper itself still
  /// reads the server's own secondsRemaining; this is only for the card.
  int? get secondsLeftOnAttempt {
    final startedAt = lastAttempt?.startedAt;
    if (!isInProgress || startedAt == null) return null;
    final left = startedAt
        .add(Duration(minutes: durationMinutes))
        .difference(DateTime.now())
        .inSeconds;
    return left > 0 ? left : 0;
  }
}

/// One question on the paper. Text and every option are nullable: a question
/// can be an ECG image alone, and the options can be four slides.
class TestQuestion {
  final int id;
  final int questionOrder;
  final String? questionText;
  final String? questionImageUrl;

  final String? optionA;
  final String? optionAImageUrl;
  final String? optionB;
  final String? optionBImageUrl;
  final String? optionC;
  final String? optionCImageUrl;
  final String? optionD;
  final String? optionDImageUrl;

  TestQuestion({
    required this.id,
    required this.questionOrder,
    this.questionText,
    this.questionImageUrl,
    this.optionA,
    this.optionAImageUrl,
    this.optionB,
    this.optionBImageUrl,
    this.optionC,
    this.optionCImageUrl,
    this.optionD,
    this.optionDImageUrl,
  });

  factory TestQuestion.fromJson(Map<String, dynamic> json) => TestQuestion(
        id: _toInt(json['id']),
        questionOrder: _toInt(json['questionOrder']),
        questionText: json['questionText']?.toString(),
        questionImageUrl: json['questionImageUrl']?.toString(),
        optionA: json['optionA']?.toString(),
        optionAImageUrl: json['optionAImageUrl']?.toString(),
        optionB: json['optionB']?.toString(),
        optionBImageUrl: json['optionBImageUrl']?.toString(),
        optionC: json['optionC']?.toString(),
        optionCImageUrl: json['optionCImageUrl']?.toString(),
        optionD: json['optionD']?.toString(),
        optionDImageUrl: json['optionDImageUrl']?.toString(),
      );

  /// The letters this question actually offers. A paper is not always A–D:
  /// an option with neither text nor image is not an option.
  List<String> get letters => [
        if (optionA != null || optionAImageUrl != null) 'A',
        if (optionB != null || optionBImageUrl != null) 'B',
        if (optionC != null || optionCImageUrl != null) 'C',
        if (optionD != null || optionDImageUrl != null) 'D',
      ];

  String? textFor(String letter) => switch (letter) {
        'A' => optionA,
        'B' => optionB,
        'C' => optionC,
        _ => optionD,
      };

  String? imageFor(String letter) => switch (letter) {
        'A' => optionAImageUrl,
        'B' => optionBImageUrl,
        'C' => optionCImageUrl,
        _ => optionDImageUrl,
      };
}

/// The whole paper, delivered in one call. There are no further question
/// fetches — paging happens locally.
class TestAttempt {
  final int attemptId;

  /// True when the server handed back an attempt that was already running.
  final bool resumed;

  final int testId;
  final String testName;
  final int totalQuestions;
  final int durationMinutes;
  final double marksCorrect;
  final double marksIncorrect;

  /// **The countdown reads this, never durationMinutes.** A resumed attempt
  /// has less time left; starting the clock from the duration would hand the
  /// student a fresh 30 minutes on every reopen.
  final int secondsRemaining;

  /// questionId -> selected letter, for restoring a resumed attempt.
  final Map<int, String> answered;

  final List<TestQuestion> questions;

  TestAttempt({
    required this.attemptId,
    required this.resumed,
    required this.testId,
    required this.testName,
    required this.totalQuestions,
    required this.durationMinutes,
    required this.marksCorrect,
    required this.marksIncorrect,
    required this.secondsRemaining,
    required this.answered,
    required this.questions,
  });

  factory TestAttempt.fromJson(Map<String, dynamic> json) {
    final test = json['test'] is Map
        ? Map<String, dynamic>.from(json['test'] as Map)
        : const <String, dynamic>{};

    final answered = <int, String>{};
    for (final entry in (json['answered'] as List?) ?? const []) {
      if (entry is Map) {
        final questionId = _toInt(entry['testQuestionId'] ?? entry['questionId']);
        final option = entry['selectedOption']?.toString();
        if (questionId != 0 && option != null) answered[questionId] = option;
      }
    }

    return TestAttempt(
      attemptId: _toInt(json['attemptId']),
      resumed: json['resumed'] == true,
      testId: _toInt(test['id']),
      testName: test['name']?.toString() ?? 'Test',
      totalQuestions: _toInt(test['totalQuestions']),
      durationMinutes: _toInt(test['durationMinutes']),
      marksCorrect: _toDouble(test['marksCorrect']),
      marksIncorrect: _toDouble(test['marksIncorrect']),
      secondsRemaining: _toInt(json['secondsRemaining']),
      answered: answered,
      questions: [
        for (final question in (json['questions'] as List?) ?? const [])
          if (question is Map)
            TestQuestion.fromJson(Map<String, dynamic>.from(question)),
      ],
    );
  }
}

/// What an answer (or its deletion) returns. No `isCorrect` — this is an
/// exam, and nothing is revealed until submit.
class TestAnswerResponse {
  final int answeredCount;
  final int remainingCount;

  /// The server's clock, re-read on every answer — the only one that matters
  /// when the paper is graded.
  ///
  /// Nullable, and it has to stay that way: the DELETE that clears an answer
  /// replies without this field. Defaulting a missing value to 0 reads as
  /// "no time left", which stops the countdown and locks the student out of
  /// their own paper. Absent means "unchanged", not "expired".
  final int? secondsRemaining;

  TestAnswerResponse({
    required this.answeredCount,
    required this.remainingCount,
    this.secondsRemaining,
  });

  factory TestAnswerResponse.fromJson(Map<String, dynamic> json) =>
      TestAnswerResponse(
        answeredCount: _toInt(json['answeredCount']),
        remainingCount: _toInt(json['remainingCount']),
        secondsRemaining:
            json['secondsRemaining'] == null ? null : _toInt(json['secondsRemaining']),
      );
}

/// One question's outcome, available only after submit.
class TestQuestionResult {
  final int questionId;
  final String? questionText;
  final String? questionImageUrl;
  final String? selectedOption;
  final String? correctOption;
  final bool isCorrect;

  /// False means skipped. Skipped scores 0; wrong scores the negative mark.
  /// They are not the same outcome and must not be drawn the same.
  final bool answered;

  final double marksAwarded;
  final String? explanation;
  final String? subject;

  TestQuestionResult({
    required this.questionId,
    this.questionText,
    this.questionImageUrl,
    this.selectedOption,
    this.correctOption,
    required this.isCorrect,
    required this.answered,
    required this.marksAwarded,
    this.explanation,
    this.subject,
  });

  factory TestQuestionResult.fromJson(Map<String, dynamic> json) =>
      TestQuestionResult(
        questionId: _toInt(json['testQuestionId'] ?? json['questionId'] ?? json['id']),
        questionText: json['questionText']?.toString(),
        questionImageUrl: json['questionImageUrl']?.toString(),
        selectedOption: json['selectedOption']?.toString(),
        correctOption: json['correctOption']?.toString(),
        isCorrect: json['isCorrect'] == true,
        answered: json['answered'] == true,
        marksAwarded: _toDouble(json['marksAwarded']),
        explanation: json['explanation']?.toString(),
        subject: json['subject']?.toString(),
      );
}

/// The marked paper. Returned by submit and by the result endpoint alike.
class TestResult {
  final double score;
  final double totalMarks;
  final int timeTakenSeconds;
  final int correctCount;
  final int wrongCount;
  final int skippedCount;
  final List<TestQuestionResult> results;

  /// Every question ends in exactly one of the three, so they sum to the
  /// paper. Taken from the counts rather than results.length: the counts are
  /// what the server scored, and they stay right even if the list is trimmed.
  int get totalQuestions => correctCount + wrongCount + skippedCount;

  TestResult({
    required this.score,
    required this.totalMarks,
    required this.timeTakenSeconds,
    required this.correctCount,
    required this.wrongCount,
    required this.skippedCount,
    required this.results,
  });

  factory TestResult.fromJson(Map<String, dynamic> json) => TestResult(
        score: _toDouble(json['score']),
        totalMarks: _toDouble(json['totalMarks']),
        timeTakenSeconds: _toInt(json['timeTakenSeconds']),
        correctCount: _toInt(json['correctCount']),
        wrongCount: _toInt(json['wrongCount']),
        skippedCount: _toInt(json['skippedCount']),
        results: [
          for (final result in (json['results'] as List?) ?? const [])
            if (result is Map)
              TestQuestionResult.fromJson(Map<String, dynamic>.from(result)),
        ],
      );
}

/// One row on the leaderboard.
class LeaderboardEntry {
  /// The server's rank. Ties share a rank and the next one skips, so this is
  /// rendered as sent — a row index would quietly renumber a tie.
  final int rank;

  final String name;
  final double score;
  final int correctCount;
  final int timeTakenSeconds;

  LeaderboardEntry({
    required this.rank,
    required this.name,
    required this.score,
    required this.correctCount,
    required this.timeTakenSeconds,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) => LeaderboardEntry(
        rank: _toInt(json['rank']),
        name: json['name']?.toString() ?? '—',
        score: _toDouble(json['score']),
        correctCount: _toInt(json['correctCount']),
        timeTakenSeconds: _toInt(json['timeTakenSeconds']),
      );
}

class Leaderboard {
  final int totalParticipants;

  /// This student's own row, sent separately from [entries] and pinned to the
  /// bottom of the list. Ranked 87th, they would never find themselves in a
  /// top 50.
  final LeaderboardEntry? me;

  final List<LeaderboardEntry> entries;

  Leaderboard({
    required this.totalParticipants,
    this.me,
    required this.entries,
  });

  factory Leaderboard.fromJson(Map<String, dynamic> json) => Leaderboard(
        totalParticipants: _toInt(json['totalParticipants']),
        me: json['me'] is Map
            ? LeaderboardEntry.fromJson(Map<String, dynamic>.from(json['me'] as Map))
            : null,
        entries: [
          for (final entry in (json['entries'] as List?) ?? const [])
            if (entry is Map)
              LeaderboardEntry.fromJson(Map<String, dynamic>.from(entry)),
        ],
      );

  /// True when `me` is already in [entries] — no need to pin a duplicate.
  bool get meIsListed =>
      me != null && entries.any((entry) => entry.rank == me!.rank);
}
