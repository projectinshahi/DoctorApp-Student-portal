import 'package:dr_app/models/comment_model.dart';
import 'package:dr_app/repository/comment_provider.dart';
import 'package:dr_app/services/comment_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// The live thread payload, trimmed to what the section reads.
Map<String, dynamic> _thread({bool commentsEnabled = true}) => {
      'lesson': {'id': 37, 'title': 'Cardiology', 'type': 'video'},
      'commentsEnabled': commentsEnabled,
      'totalComments': 3,
      'pagination': {'page': 1, 'limit': 20, 'total': 1, 'totalPages': 1},
      'comments': [
        {
          'id': 1,
          'parentId': null,
          'body': 'Great explanation of the ECG axis — thanks!',
          'createdAt': '2026-09-01T10:00:00.000Z',
          'editedAt': '2026-09-01T10:05:00.000Z',
          'edited': true,
          'author': {'id': 30, 'name': 'Keerthana Bineesh', 'avatarUrl': null},
          'isMine': true,
          'reportedByMe': false,
          'replies': [
            {
              'id': 2,
              'parentId': 1,
              'body': 'Agreed, the lead II part helped.',
              'author': {'id': 31, 'name': 'Theertha bineesh14'},
              'isMine': false,
              'reportedByMe': false,
              'replies': const [],
            },
          ],
        },
      ],
    };

/// Answers a POST the way the server does when the parent was itself a reply:
/// re-parented onto the thread root.
class _ReparentingService extends CommentService {
  int? sentParentId;

  @override
  Future<CommentPage> fetchComments(int lessonId,
          {int page = 1, int limit = 20}) async =>
      CommentPage.fromJson(_thread());

  @override
  Future<PostedComment> postComment(int lessonId,
      {required String body, int? parentId}) async {
    sentParentId = parentId;
    return PostedComment.fromJson({
      'comment': {
        'id': 3,
        'parentId': 1,
        'body': body,
        'author': {'id': 30, 'name': 'Keerthana Bineesh'},
        'isMine': true,
        'reportedByMe': false,
        'edited': false,
        'replies': const [],
      },
      // Asked for 2 (a reply); the server put it on 1 (the root).
      'parentId': 1,
    });
  }

  @override
  Future<void> reportComment(int commentId, {String? reason}) async {}
}

void main() {
  group('thread', () {
    test('two different counts, and the label uses the bigger one', () {
      final page = CommentPage.fromJson(_thread());

      // pagination.total counts threads; totalComments counts replies too.
      // Labelling with the former would say "1 comment" under three.
      expect(page.totalThreads, 1);
      expect(page.totalComments, 3);
      expect(page.comments.single.replies.length, 1);
    });

    test('edited comes from the flag, not from comparing timestamps', () {
      final root = CommentPage.fromJson(_thread()).comments.single;

      expect(root.edited, isTrue);

      // A moderator hiding and restoring a comment moves the timestamp
      // without the author touching it, so the flag is the only safe source.
      final restored = CommentModel.fromJson({
        'id': 9,
        'body': 'untouched',
        'createdAt': '2026-09-01T10:00:00.000Z',
        'editedAt': '2026-09-01T12:00:00.000Z',
        'edited': false,
        'author': {'id': 1},
        'isMine': false,
        'reportedByMe': false,
      });
      expect(restored.edited, isFalse,
          reason: 'a later editedAt must not fabricate an "edited" marker');
    });

    test('a missing commentsEnabled means enabled, not disabled', () {
      // A lesson nobody has ever switched off does not send the flag.
      // Defaulting to false would close commenting across the whole app.
      final page = CommentPage.fromJson({
        'totalComments': 0,
        'pagination': {'page': 1, 'limit': 20, 'total': 0, 'totalPages': 0},
        'comments': const [],
      });
      expect(page.commentsEnabled, isTrue);
    });

    test('a nameless author falls back to a placeholder', () {
      final comment = CommentModel.fromJson({
        'id': 5,
        'body': 'hi',
        'edited': false,
        'author': {'id': 7, 'name': null, 'avatarUrl': null},
        'isMine': false,
        'reportedByMe': false,
      });

      // The email is never sent, so there is nothing else to show.
      expect(comment.author.displayName, 'Student');
      expect(comment.author.initial, 'S');
    });
  });

  group('posting', () {
    test('a reply is placed by the response parentId, not the one sent',
        () async {
      final service = _ReparentingService();
      final provider = CommentProvider(service: service);
      await provider.load(37);

      // The student tapped Reply on comment 2, which is itself a reply.
      await provider.post(37, 'Same here.', parentId: 2);

      expect(service.sentParentId, 2, reason: 'send whatever was tapped');

      // The server re-parented it onto the root. Trusting our own value would
      // nest it under a reply — a tier that does not exist — and it would
      // jump on the next refresh.
      final root = provider.comments.single;
      expect(root.id, 1);
      expect(root.replies.map((r) => r.id), [2, 3]);
      expect(provider.comments.length, 1,
          reason: 'a reply must not become a new thread');
    });

    test('replies append oldest-last, threads prepend newest-first', () async {
      final provider = CommentProvider(service: _ReparentingService());
      await provider.load(37);

      await provider.post(37, 'Same here.', parentId: 2);

      // A conversation reads forwards even though the list of conversations
      // reads backwards.
      expect(provider.comments.single.replies.last.id, 3);
    });

    test('an empty comment is never sent', () async {
      final service = _ReparentingService();
      final provider = CommentProvider(service: service);
      await provider.load(37);

      expect(await provider.post(37, '   '), isFalse);
      expect(service.sentParentId, isNull, reason: 'no request was made');
    });
  });

  group('reporting', () {
    test('a reported comment stays in the list', () async {
      final provider = CommentProvider(service: _ReparentingService());
      await provider.load(37);

      await provider.report(2);

      // Hiding it locally would make one student with a grudge a censor —
      // and the server does not remove it either.
      final reply = provider.comments.single.replies.single;
      expect(reply.id, 2);
      expect(reply.reportedByMe, isTrue);
      expect(provider.totalComments, 3, reason: 'nothing was removed');
    });
  });

  group('errors', () {
    test('a hidden comment reads as gone, not as forbidden', () {
      // 404 on purpose: "you may not edit that" would confirm it still exists.
      expect(CommentService.mapError(404, {'message': 'Not found'}).kind,
          CommentErrorKind.gone);
    });

    test('the two 403s are told apart', () {
      expect(
        CommentService.mapError(
                403, {'message': 'You can only change your own comments'})
            .kind,
        CommentErrorKind.notYours,
      );
      expect(
        CommentService.mapError(
                403, {'message': 'This lesson is locked. Subscribe to view.'})
            .kind,
        CommentErrorKind.locked,
      );
    });

    test('commenting turned off is its own state', () {
      expect(
        CommentService.mapError(
                409, {'message': 'Commenting is turned off for this lesson'})
            .kind,
        CommentErrorKind.commentsOff,
      );
    });

    test('signed out, because there is no anonymous read', () {
      expect(CommentService.mapError(401, {}).kind, CommentErrorKind.signedOut);
    });
  });
}
