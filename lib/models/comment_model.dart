// lib/models/comment_model.dart
//
// Lesson comments. One level of nesting, enforced by the server.

int _toInt(dynamic value) =>
    value is int ? value : int.tryParse('${value ?? ''}') ?? 0;

int? _toIntOrNull(dynamic value) =>
    value == null ? null : (value is int ? value : int.tryParse('$value'));

DateTime? _toDate(dynamic value) =>
    value == null ? null : DateTime.tryParse(value.toString());

class CommentAuthor {
  final int id;

  /// Both nullable on the wire. The email is never sent, so there is nothing
  /// to fall back to but a placeholder.
  final String? name;
  final String? avatarUrl;

  const CommentAuthor({required this.id, this.name, this.avatarUrl});

  factory CommentAuthor.fromJson(Map<String, dynamic> json) => CommentAuthor(
        id: _toInt(json['id']),
        name: json['name']?.toString(),
        avatarUrl: json['avatarUrl']?.toString(),
      );

  String get displayName =>
      (name == null || name!.trim().isEmpty) ? 'Student' : name!.trim();

  /// For the avatar circle when there is no image.
  String get initial => displayName[0].toUpperCase();
}

class CommentModel {
  final int id;

  /// Null on a thread root. On a reply this is the root it hangs from —
  /// never another reply, because the server re-parents.
  final int? parentId;

  final String body;
  final DateTime? createdAt;
  final DateTime? editedAt;

  /// Read from the server's own flag, never derived by comparing timestamps:
  /// a moderator hiding and restoring a comment moves `updatedAt`, and that
  /// must not make it read as edited by its author.
  final bool edited;

  final CommentAuthor author;

  /// The server has already decided whose comment this is and whether this
  /// student reported it. Comparing ids in the app would be a second,
  /// disagreeing source of truth.
  final bool isMine;
  final bool reportedByMe;

  /// Oldest-first, so a conversation reads forwards. Always empty on a reply.
  final List<CommentModel> replies;

  const CommentModel({
    required this.id,
    this.parentId,
    required this.body,
    this.createdAt,
    this.editedAt,
    required this.edited,
    required this.author,
    required this.isMine,
    required this.reportedByMe,
    this.replies = const [],
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) => CommentModel(
        id: _toInt(json['id']),
        parentId: _toIntOrNull(json['parentId']),
        body: json['body']?.toString() ?? '',
        createdAt: _toDate(json['createdAt']),
        editedAt: _toDate(json['editedAt']),
        edited: json['edited'] == true,
        author: json['author'] is Map
            ? CommentAuthor.fromJson(
                Map<String, dynamic>.from(json['author'] as Map))
            : const CommentAuthor(id: 0),
        isMine: json['isMine'] == true,
        reportedByMe: json['reportedByMe'] == true,
        replies: [
          for (final reply in (json['replies'] as List?) ?? const [])
            if (reply is Map)
              CommentModel.fromJson(Map<String, dynamic>.from(reply)),
        ],
      );

  CommentModel copyWith({
    String? body,
    bool? edited,
    bool? reportedByMe,
    List<CommentModel>? replies,
  }) =>
      CommentModel(
        id: id,
        parentId: parentId,
        body: body ?? this.body,
        createdAt: createdAt,
        editedAt: editedAt,
        edited: edited ?? this.edited,
        author: author,
        isMine: isMine,
        reportedByMe: reportedByMe ?? this.reportedByMe,
        replies: replies ?? this.replies,
      );

  /// Every comment this row would take with it if deleted — the warning the
  /// student needs before removing a thread other people replied to.
  int get replyCount => replies.length;
}

class CommentPage {
  /// A per-lesson switch a moderator controls. False means read-only: the
  /// thread still renders, only the input box goes.
  final bool commentsEnabled;

  /// Threads *and* replies — this is the "12 comments" label.
  final int totalComments;

  /// Threads only. Pagination counts top-level comments; replies are never
  /// paginated and arrive with their parent.
  final int page;
  final int limit;
  final int totalThreads;
  final int totalPages;

  /// Newest-first.
  final List<CommentModel> comments;

  const CommentPage({
    required this.commentsEnabled,
    required this.totalComments,
    required this.page,
    required this.limit,
    required this.totalThreads,
    required this.totalPages,
    required this.comments,
  });

  factory CommentPage.fromJson(Map<String, dynamic> json) {
    final pagination = json['pagination'] is Map
        ? Map<String, dynamic>.from(json['pagination'] as Map)
        : const <String, dynamic>{};

    return CommentPage(
      // Absent means enabled: a lesson that has never been switched off does
      // not send the flag, and defaulting to false would silently close
      // commenting everywhere.
      commentsEnabled: json['commentsEnabled'] != false,
      totalComments: _toInt(json['totalComments']),
      page: _toInt(pagination['page']),
      limit: _toInt(pagination['limit']),
      totalThreads: _toInt(pagination['total']),
      totalPages: _toInt(pagination['totalPages']),
      comments: [
        for (final comment in (json['comments'] as List?) ?? const [])
          if (comment is Map)
            CommentModel.fromJson(Map<String, dynamic>.from(comment)),
      ],
    );
  }

  bool get hasMore => page < totalPages;
}

/// What a POST answers with. The `parentId` here is authoritative — see
/// [CommentProvider.post].
class PostedComment {
  final CommentModel comment;

  /// Where the server actually attached it, which is not necessarily where
  /// the app asked.
  final int? parentId;

  const PostedComment({required this.comment, this.parentId});

  factory PostedComment.fromJson(Map<String, dynamic> json) => PostedComment(
        comment: CommentModel.fromJson(json['comment'] is Map
            ? Map<String, dynamic>.from(json['comment'] as Map)
            : json),
        parentId: _toIntOrNull(json['parentId']),
      );
}
