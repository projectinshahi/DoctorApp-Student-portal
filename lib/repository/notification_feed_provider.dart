// lib/repository/notification_feed_provider.dart
import 'package:flutter/foundation.dart';

import '../models/notification_model.dart';
import '../models/quiz_model.dart' show QuizException;
import '../services/notification_feed_service.dart';

/// The student's notification list, and the number on the bell.
///
/// The server is the source of truth: it decides what this student can see,
/// and that changes with the course they have selected. Nothing is cached to
/// disk for that reason.
class NotificationFeedProvider extends ChangeNotifier {
  final NotificationFeedService _service;

  NotificationFeedProvider({NotificationFeedService? service})
      : _service = service ?? NotificationFeedService();

  List<NotificationItem> items = const [];
  int unreadCount = 0;

  bool isLoading = false;
  bool isLoadingMore = false;
  String? errorMessage;

  /// The timestamp the next page starts before. Null when there are no more.
  String? _nextBefore;
  bool get hasMore => _nextBefore != null;

  bool _fetched = false;

  /// A fetch has come back. Before that there is nothing to say — an empty
  /// list and a list nobody has asked for look the same, and showing
  /// "nothing yet" for the one that is still loading is a lie.
  bool get hasLoaded => _fetched;

  Future<void>? _inFlight;

  /// The first page, sharing one request between callers — the screen and
  /// the badge both ask for it.
  Future<void> load() =>
      _inFlight ??= _fetch().whenComplete(() => _inFlight = null);

  Future<void> _fetch() async {
    // The list stays up while it refreshes: only a cold load spins.
    isLoading = !_fetched;
    errorMessage = null;
    notifyListeners();

    try {
      final feed = await _service.fetch();
      items = feed.items;
      unreadCount = feed.unreadCount;
      _nextBefore = feed.nextBefore;
      _fetched = true;
    } on QuizException catch (e) {
      errorMessage = e.message;
    }

    isLoading = false;
    notifyListeners();
  }

  /// The next page, appended. Does nothing on the last one.
  Future<void> loadMore() async {
    final before = _nextBefore;
    if (before == null || isLoadingMore || isLoading) return;

    isLoadingMore = true;
    notifyListeners();

    try {
      final feed = await _service.fetch(before: before);
      items = [...items, ...feed.items];
      _nextBefore = feed.nextBefore;
    } on QuizException catch (e) {
      errorMessage = e.message;
    }

    isLoadingMore = false;
    notifyListeners();
  }

  /// Clears the badge. One timestamp per student — there is no marking a
  /// single row, and the rows keep their unread mark for this visit so the
  /// student can still see what was new.
  Future<void> markRead() async {
    if (unreadCount == 0) return;
    final previous = unreadCount;
    unreadCount = 0;
    notifyListeners();

    try {
      unreadCount = await _service.markRead();
    } on QuizException {
      // The badge comes back rather than lying about a call that failed.
      unreadCount = previous;
    }
    notifyListeners();
  }

  /// A push arrived while the app was open. The row is already stored, so
  /// only the badge needs to move; the list catches up on its next load.
  void bumpUnread() {
    unreadCount++;
    notifyListeners();
  }

  /// Sign-out: this list belongs to the account that was signed in.
  void clear() {
    items = const [];
    unreadCount = 0;
    errorMessage = null;
    isLoading = false;
    isLoadingMore = false;
    _nextBefore = null;
    _fetched = false;
    notifyListeners();
  }
}
