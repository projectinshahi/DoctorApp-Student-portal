// lib/repository/rapid_recall_provider.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/constant/local_storage.dart';
import '../core/utils/load_timer.dart';
import '../models/quiz_model.dart' show QuizException;
import '../models/rapid_recall_model.dart';
import '../services/rapid_recall_service.dart';

/// Rapid Recall, app-wide.
///
/// One list serves all four screens — topics, lessons, decks, cards — so the
/// student pays for the network once and every tap after that is instant.
/// Registered globally rather than per screen for the same reason the
/// bookmarks are: four copies of this would each fetch their own.
class RapidRecallProvider extends ChangeNotifier {
  final RapidRecallService _service;

  RapidRecallProvider({RapidRecallService? service})
      : _service = service ?? RapidRecallService() {
    _restore();
    _restoreIds(LocalStorage.recallBookmarksKey, _bookmarks);
    _restoreIds(LocalStorage.recallOpenedKey, _opened);
  }

  static const String _general = 'General';

  List<RapidRecallDeck> decks = const [];

  /// The server's own sentence for an empty list — "No course selected yet."
  /// Shown instead of the empty state, which would be the wrong answer.
  String? reason;

  bool isLoading = false;
  String? errorMessage;

  /// A fetch has come back. Distinct from a started one: the spinner waits on
  /// the answer, and an account with no decks at all has to stop spinning too.
  bool _fetched = false;

  Future<void>? _inFlight;

  /// Decks already opened, by id. Reopening one paints its cards immediately
  /// and refetches underneath.
  final Map<int, RapidRecallDeck> _detail = {};

  /// Detail fetches in flight, so leaving and re-entering a deck does not
  /// stack two requests for it.
  final Map<int, Future<void>> _detailInFlight = {};

  /// Why a deck's cards could not be fetched, by deck. Per deck rather than
  /// the shared [errorMessage]: thumbnails load decks in the background, and
  /// one of those failing must not put its error on a different deck's
  /// screen.
  final Map<int, String> _deckErrors = {};

  /// Bookmarked deck ids. Device-local: there is no saved-recall endpoint, so
  /// these do not follow the student to another phone.
  final Set<int> _bookmarks = {};

  /// Decks opened at least once on this phone. A deck not in here is new to
  /// the student, and its row says so.
  final Set<int> _opened = {};

  /// Paints the last known decks before the network is asked.
  Future<void> _restore() async {
    if (_fetched) return;
    try {
      final stored = await LocalStorage.getCached(LocalStorage.rapidRecallKey);
      if (stored == null || stored.isEmpty || _fetched) return;

      final list = RapidRecallService.parseList(jsonDecode(stored));
      decks = list.decks;
      reason = list.reason;
      // Not _fetched: that means the server answered, and this did not.
      notifyListeners();
    } catch (_) {
      // Restoring is an optimisation and must never break the screen.
    }
  }

  /// Bookmarks and opened decks are both a stored list of ids.
  Future<void> _restoreIds(String key, Set<int> into) async {
    try {
      final stored = await LocalStorage.getCached(key);
      if (stored == null || stored.isEmpty) return;

      final ids = jsonDecode(stored);
      if (ids is! List) return;
      into.addAll(ids.map((id) => int.tryParse('$id')).whereType<int>());
      notifyListeners();
    } catch (_) {
      // A marker that fails to restore is not worth a broken screen.
    }
  }

  /// Fetches the list, sharing one request between callers.
  ///
  /// Sharing, not caching: a call made after the first finishes is its own
  /// request, so a deck published while the student is in the app shows up.
  Future<void> load() =>
      _inFlight ??= _fetch().whenComplete(() => _inFlight = null);

  Future<void> _fetch() async {
    // The list stays up while the refetch runs. The spinner is for a cold
    // load only — anything else is the flicker the client complained about.
    isLoading = !_fetched;
    errorMessage = null;
    notifyListeners();

    try {
      final list = await timedLoad('rapid recall', _service.fetchAll,
          detail: (l) => '${l.decks.length} decks');
      decks = list.decks;
      reason = list.reason;
      _fetched = true;
    } on QuizException catch (e) {
      errorMessage = e.message;
    }

    isLoading = false;
    notifyListeners();
  }

  // ── Grouping ─────────────────────────────────────────────────
  //
  // All three list screens read from the one fetched list. A deck is filed
  // under a lesson, and the lesson under a chapter; a deck with neither
  // belongs to the whole course and lands in "General", last.

  /// Topics — the chapters the decks' lessons sit in.
  List<RecallGroup> get topics => _group(
        decks,
        id: (deck) => deck.lesson?.chapter?.id,
        title: (deck) => deck.lesson?.chapter?.title,
      );

  /// The lessons inside one topic.
  ///
  /// Lesson titles are not unique — two live lessons are both called
  /// "Obstetrics" — but they are reached through their chapter, which is this
  /// screen's title, so the pair never appears side by side.
  List<RecallGroup> lessonsIn(int? chapterId) => _group(
        decks.where((deck) => deck.lesson?.chapter?.id == chapterId),
        id: (deck) => deck.lesson?.id,
        title: (deck) => deck.lesson?.title,
      );

  /// The decks inside one lesson of one topic.
  List<RapidRecallDeck> decksIn({int? chapterId, int? lessonId}) => decks
      .where((deck) =>
          deck.lesson?.chapter?.id == chapterId && deck.lesson?.id == lessonId)
      .toList()
    ..sort(_byOrder);

  List<RecallGroup> _group(
    Iterable<RapidRecallDeck> source, {
    required int? Function(RapidRecallDeck) id,
    required String? Function(RapidRecallDeck) title,
  }) {
    final buckets = <int?, List<RapidRecallDeck>>{};
    for (final deck in source) {
      buckets.putIfAbsent(id(deck), () => []).add(deck);
    }

    final groups = buckets.entries.map((entry) {
      final first = entry.value.first;
      final name = title(first);
      return RecallGroup(
        id: entry.key,
        title: name == null || name.isEmpty ? _general : name,
        decks: entry.value..sort(_byOrder),
      );
    }).toList();

    // Alphabetical, with the catch-all last — it is where things land, not
    // something the student went looking for.
    groups.sort((a, b) {
      if ((a.id == null) != (b.id == null)) return a.id == null ? 1 : -1;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return groups;
  }

  /// The other decks in the same lesson as [deckId], in list order.
  ///
  /// What the deck screen offers next, so moving on to another deck does not
  /// mean going back to the list first. Matched on the deck's own lesson and
  /// chapter — the same test [decksIn] uses — so it is exactly the list the
  /// student came from, minus the deck they are on.
  List<RapidRecallDeck> siblingsOf(int deckId) {
    final current = deck(deckId);
    if (current == null) return const [];
    return decksIn(
      chapterId: current.lesson?.chapter?.id,
      lessonId: current.lesson?.id,
    ).where((other) => other.id != deckId).toList();
  }

  static int _byOrder(RapidRecallDeck a, RapidRecallDeck b) {
    final byOrder = a.displayOrder.compareTo(b.displayOrder);
    return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
  }

  // ── One deck ─────────────────────────────────────────────────

  /// The deck with its cards if it has been opened before, otherwise the row
  /// from the list — enough to draw the header while the cards load.
  RapidRecallDeck? deck(int id) {
    final opened = _detail[id];
    if (opened != null) return opened;
    for (final candidate in decks) {
      if (candidate.id == id) return candidate;
    }
    return null;
  }

  bool hasCards(int id) => _detail.containsKey(id);

  /// Fetches one deck's cards, sharing a request per deck.
  Future<void> loadDeck(int id) =>
      _detailInFlight[id] ??= _fetchDeck(id).whenComplete(() {
        _detailInFlight.remove(id);
      });

  Future<void> _fetchDeck(int id) async {
    // No spinner flag here. The cards screen waits on [hasCards], and a
    // shared isLoading set false by a deck fetch would cancel the list's own
    // cold load if the two overlapped.
    if (_deckErrors.remove(id) != null) notifyListeners();

    try {
      _detail[id] = await timedLoad(
        'recall deck',
        () => _service.fetchDeck(id),
        detail: (d) => '${d.cards.length} cards',
      );
    } on QuizException catch (e) {
      _deckErrors[id] = e.message;
    }

    notifyListeners();
  }

  String? deckError(int id) => _deckErrors[id];

  /// Fetches the cards for decks about to be shown in a list — their first
  /// image is the row's thumbnail, and the deck then opens instantly.
  ///
  /// One at a time, deliberately. Warming quizzes in parallel was measured
  /// making every read slower and starving whatever the student tapped; a
  /// list of four thumbnails filling in one by one costs nothing to wait for.
  /// A deck already fetched is skipped, and one the student opens mid-warm
  /// joins the request already running rather than starting a second.
  Future<void> warmDecks(Iterable<int> ids) async {
    for (final id in ids.toList()) {
      if (_detail.containsKey(id)) continue;
      await loadDeck(id);
    }
  }

  // ── Bookmarks ────────────────────────────────────────────────

  bool isBookmarked(int deckId) => _bookmarks.contains(deckId);

  /// Flips immediately and writes in the background — there is no request to
  /// fail, so there is nothing to roll back.
  void toggleBookmark(int deckId) {
    _bookmarks.contains(deckId)
        ? _bookmarks.remove(deckId)
        : _bookmarks.add(deckId);
    notifyListeners();
    unawaited(LocalStorage.saveCached(
      LocalStorage.recallBookmarksKey,
      jsonEncode(_bookmarks.toList()),
    ));
  }

  bool isOpened(int deckId) => _opened.contains(deckId);

  /// Called when a deck's cards are shown. Silent when already marked, so
  /// reopening a deck does not rebuild every list watching this provider.
  void markOpened(int deckId) {
    if (!_opened.add(deckId)) return;
    notifyListeners();
    unawaited(LocalStorage.saveCached(
      LocalStorage.recallOpenedKey,
      jsonEncode(_opened.toList()),
    ));
  }

  /// Sign-out: these decks belong to the account that was signed in, and its
  /// bookmarks go with them.
  void clear() {
    decks = const [];
    reason = null;
    errorMessage = null;
    isLoading = false;
    _fetched = false;
    _detail.clear();
    _deckErrors.clear();
    _bookmarks.clear();
    _opened.clear();
    notifyListeners();
  }
}
