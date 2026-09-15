// lib/repository/comment_provider.dart
import 'package:flutter/foundation.dart';

import '../models/comment_model.dart';
import '../services/comment_service.dart';

/// One instance per open lesson, created by the comments section.
class CommentProvider extends ChangeNotifier {
  final CommentService _service;

  CommentProvider({CommentService? service})
      : _service = service ?? CommentService();

  bool isLoading = true;
  bool isPosting = false;
  bool isLoadingMore = false;

  CommentException? failure;
  String? actionError;

  bool commentsEnabled = true;

  /// Threads and replies together — the count shown in the heading.
  int totalComments = 0;

  int _page = 1;
  int _totalPages = 1;

  /// Newest-first threads, each carrying its own oldest-first replies.
  List<CommentModel> comments = const [];

  /// The thread the reply composer is open on, or null when composing a new
  /// top-level comment.
  int? replyingTo;

  bool _disposed = false;

  bool get hasMore => _page < _totalPages;
  bool get isEmpty => comments.isEmpty;

  // ── Loading ──────────────────────────────────────────────────
  /// The lesson the loaded comments belong to. Showing one lesson's thread
  /// under another lesson would be worse than a spinner.
  int? _loadedLessonId;

  Future<void> load(int lessonId) async {
    isLoading = comments.isEmpty || _loadedLessonId != lessonId;
    _loadedLessonId = lessonId;
    failure = null;
    notifyListeners();

    try {
      _apply(await _service.fetchComments(lessonId, page: 1), replace: true);
    } on CommentException catch (e) {
      failure = e;
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> loadMore(int lessonId) async {
    if (isLoadingMore || !hasMore) return;

    isLoadingMore = true;
    notifyListeners();

    try {
      _apply(await _service.fetchComments(lessonId, page: _page + 1));
    } on CommentException catch (e) {
      actionError = e.message;
    }

    isLoadingMore = false;
    notifyListeners();
  }

  void _apply(CommentPage page, {bool replace = false}) {
    commentsEnabled = page.commentsEnabled;
    totalComments = page.totalComments;
    _page = page.page;
    _totalPages = page.totalPages;
    comments = replace ? page.comments : [...comments, ...page.comments];
  }

  // ── Posting ──────────────────────────────────────────────────
  /// Posts a comment, or a reply when [parentId] is set.
  ///
  /// [parentId] can be any comment the student tapped Reply on, including a
  /// reply — the server flattens the tree to one level. **The response says
  /// where it actually landed, and that is what places it here.** Trusting
  /// the id we sent would put a reply under another reply, a tier that does
  /// not exist, and it would jump on the next refresh.
  Future<bool> post(int lessonId, String body, {int? parentId}) async {
    final text = body.trim();
    if (text.isEmpty || isPosting) return false;

    isPosting = true;
    actionError = null;
    notifyListeners();

    var ok = false;
    try {
      final posted =
          await _service.postComment(lessonId, body: text, parentId: parentId);
      _insert(posted.comment, posted.parentId);
      totalComments++;
      replyingTo = null;
      ok = true;
    } on CommentException catch (e) {
      actionError = e.message;
    }

    isPosting = false;
    notifyListeners();
    return ok;
  }

  void _insert(CommentModel comment, int? parentId) {
    if (parentId == null) {
      // Threads read newest-first.
      comments = [comment, ...comments];
      return;
    }

    comments = [
      for (final thread in comments)
        if (thread.id == parentId)
          // Replies read oldest-first, so a new one goes on the end.
          thread.copyWith(replies: [...thread.replies, comment])
        else
          thread,
    ];
  }

  // ── Editing ──────────────────────────────────────────────────
  Future<bool> edit(int commentId, String body) async {
    final text = body.trim();
    if (text.isEmpty) return false;

    actionError = null;
    notifyListeners();

    var ok = false;
    try {
      final updated = await _service.editComment(commentId, body: text);
      comments = _map(comments, commentId,
          (c) => c.copyWith(body: updated.body, edited: true));
      ok = true;
    } on CommentException catch (e) {
      actionError = e.message;
    }

    notifyListeners();
    return ok;
  }

  /// Deletes a comment. Returns the number of replies that went with it, or
  /// null if the delete failed.
  Future<int?> delete(int commentId) async {
    actionError = null;
    notifyListeners();

    int? deletedReplies;
    try {
      deletedReplies = await _service.deleteComment(commentId);
      final removed = _countRemoved(commentId);
      comments = _remove(comments, commentId);
      totalComments = (totalComments - removed).clamp(0, totalComments);
    } on CommentException catch (e) {
      actionError = e.message;
    }

    notifyListeners();
    return deletedReplies;
  }

  /// The comment plus everything under it, so the heading count drops by the
  /// right amount when a thread with replies goes.
  int _countRemoved(int commentId) {
    for (final thread in comments) {
      if (thread.id == commentId) return 1 + thread.replies.length;
      if (thread.replies.any((r) => r.id == commentId)) return 1;
    }
    return 1;
  }

  // ── Reporting ────────────────────────────────────────────────
  /// Sends a comment to a moderator.
  ///
  /// The comment stays exactly where it is. Hiding it locally would let one
  /// student with a grudge remove another's comment from their own view, and
  /// the server does not remove it either — it queues it for review.
  Future<bool> report(int commentId, {String? reason}) async {
    actionError = null;

    var ok = false;
    try {
      await _service.reportComment(commentId, reason: reason);
      comments = _map(comments, commentId, (c) => c.copyWith(reportedByMe: true));
      ok = true;
    } on CommentException catch (e) {
      actionError = e.message;
    }

    notifyListeners();
    return ok;
  }

  // ── Tree helpers ─────────────────────────────────────────────
  /// One level deep, because that is all the server will ever produce.
  List<CommentModel> _map(
    List<CommentModel> threads,
    int id,
    CommentModel Function(CommentModel) change,
  ) =>
      [
        for (final thread in threads)
          if (thread.id == id)
            change(thread)
          else
            thread.copyWith(replies: [
              for (final reply in thread.replies)
                if (reply.id == id) change(reply) else reply,
            ]),
      ];

  List<CommentModel> _remove(List<CommentModel> threads, int id) => [
        for (final thread in threads)
          if (thread.id != id)
            thread.copyWith(
              replies: thread.replies.where((r) => r.id != id).toList(),
            ),
      ];

  // ── Composer state ───────────────────────────────────────────
  void startReply(int commentId) {
    replyingTo = commentId;
    notifyListeners();
  }

  void cancelComposing() {
    replyingTo = null;
    actionError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Every notify above follows an await, and the student can close the
  /// lesson mid-request.
  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }
}
