// lib/services/comment_service.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/constant/api_constant.dart';
import '../models/comment_model.dart';
import 'refresh_api_services.dart'; // ApiClient + SessionExpiredException

enum CommentErrorKind {
  /// 401. There is no anonymous read, so this ends the section entirely.
  signedOut,

  /// 403 on someone else's comment.
  notYours,

  /// 403 because the lesson itself is premium and unpaid.
  locked,

  /// 404. Also what a moderator-hidden comment returns — deliberately not
  /// 403, because "you may not edit that" would confirm it still exists.
  gone,

  /// 409. Commenting switched off for this lesson.
  commentsOff,

  /// 400. Empty, over 2000 characters, or reporting your own comment.
  invalid,

  network,
}

class CommentException implements Exception {
  final CommentErrorKind kind;
  final String message;

  const CommentException(this.kind, this.message);

  @override
  String toString() => message;
}

/// The five comment endpoints.
class CommentService {
  static String get _base => '${ApiConstant.baseUrl}/users/me';

  /// Threads for a lesson, newest-first, each with its replies inline.
  Future<CommentPage> fetchComments(
    int lessonId, {
    int page = 1,
    int limit = 20,
  }) async =>
      CommentPage.fromJson(await _send(
        'GET',
        '$_base/lessons/$lessonId/comments?page=$page&limit=$limit',
      ));

  /// Posts a comment or a reply.
  ///
  /// [parentId] may be any comment the student tapped Reply on — including a
  /// reply. The server flattens it to one level and reports where it landed.
  Future<PostedComment> postComment(
    int lessonId, {
    required String body,
    int? parentId,
  }) async =>
      PostedComment.fromJson(await _send(
        'POST',
        '$_base/lessons/$lessonId/comments',
        body: {'body': body, if (parentId != null) 'parentId': parentId},
      ));

  Future<CommentModel> editComment(int commentId, {required String body}) async {
    final json = await _send('PATCH', '$_base/comments/$commentId',
        body: {'body': body});
    return CommentModel.fromJson(json['comment'] is Map
        ? Map<String, dynamic>.from(json['comment'] as Map)
        : json);
  }

  /// Returns how many replies went with it — 0 for a reply or a childless
  /// thread.
  Future<int> deleteComment(int commentId) async {
    final json = await _send('DELETE', '$_base/comments/$commentId');
    final deleted = json['deletedReplies'];
    return deleted is int ? deleted : int.tryParse('${deleted ?? 0}') ?? 0;
  }

  /// Sends the comment to a moderator. It does **not** remove it — see
  /// [CommentProvider.report].
  Future<void> reportComment(int commentId, {String? reason}) => _send(
        'POST',
        '$_base/comments/$commentId/report',
        body: {if (reason != null && reason.isNotEmpty) 'reason': reason},
      );

  // ── transport ────────────────────────────────────────────────
  Future<Map<String, dynamic>> _send(
    String method,
    String url, {
    Map<String, dynamic>? body,
  }) async {
    dynamic decoded;
    int status;

    try {
      final response = switch (method) {
        'POST' => await ApiClient.post(url, body: body ?? const {}),
        'PATCH' => await ApiClient.patch(url, body: body ?? const {}),
        'DELETE' => await ApiClient.delete(url),
        _ => await ApiClient.get(url),
      };

      status = response.statusCode;
      _dump(method, url, status, response.body);
      decoded =
          response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
    } on SessionExpiredException catch (e) {
      throw CommentException(CommentErrorKind.signedOut, e.message);
    } catch (_) {
      throw const CommentException(
        CommentErrorKind.network,
        'Could not reach the server. Check your connection and try again.',
      );
    }

    if ((status == 200 || status == 201) && decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }

    throw mapError(status, decoded);
  }

  @visibleForTesting
  static CommentException mapError(int status, dynamic body) {
    final message = (body is Map && body['error'] is Map)
        ? (body['error']['message']?.toString() ?? '')
        : (body is Map ? body['message']?.toString() ?? '' : '');
    final lower = message.toLowerCase();

    if (status == 401) {
      return CommentException(CommentErrorKind.signedOut,
          message.isEmpty ? 'Sign in to see and post comments.' : message);
    }
    if (status == 403) {
      // Two different 403s: a locked lesson, and someone else's comment.
      // They need different words, so the message decides.
      final locked = lower.contains('lock') ||
          lower.contains('subscri') ||
          lower.contains('premium') ||
          lower.contains('plan');
      return CommentException(
        locked ? CommentErrorKind.locked : CommentErrorKind.notYours,
        message.isEmpty ? 'You can only change your own comments.' : message,
      );
    }
    if (status == 404) {
      return CommentException(CommentErrorKind.gone,
          message.isEmpty ? 'This comment is no longer available.' : message);
    }
    if (status == 409) {
      return CommentException(CommentErrorKind.commentsOff,
          message.isEmpty ? 'Commenting is turned off for this lesson.' : message);
    }
    if (status == 400) {
      return CommentException(CommentErrorKind.invalid,
          message.isEmpty ? 'That comment could not be posted.' : message);
    }

    return CommentException(CommentErrorKind.network,
        message.isEmpty ? 'Something went wrong. Please try again.' : message);
  }

  static void _dump(String method, String url, int status, String body) {
    if (!kDebugMode) return;
    debugPrint('┌── COMMENT API  $method [$status]  $url');
    debugPrint('│  ${body.length > 300 ? '${body.substring(0, 300)}…' : body}');
    debugPrint('└── ${body.length} chars');
  }
}
