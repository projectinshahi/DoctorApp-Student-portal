// lib/services/notification_feed_service.dart
import 'dart:convert';

import '../core/constant/api_constant.dart';
import '../models/notification_model.dart';
import '../models/quiz_model.dart' show QuizException, QuizErrorKind;
import 'quiz_service.dart' show QuizService;
import 'refresh_api_services.dart';

class NotificationFeedService {
  static String get _url => '${ApiConstant.baseUrl}/users/me/notifications';

  /// One page, newest first. [before] is the previous page's `nextBefore`.
  ///
  /// The list is scoped to the course the student has selected *now*, not the
  /// one they had when it was sent — the same rule push targeting follows.
  Future<NotificationFeed> fetch({int limit = 30, String? before}) async {
    final query = {
      'limit': '$limit',
      if (before != null) 'before': before,
    };
    final url = Uri.parse(_url).replace(queryParameters: query).toString();
    return NotificationFeed.fromJson(await _send('GET', url));
  }

  /// Marks everything up to now as read and returns the count that is left,
  /// so the badge clears without a second fetch.
  Future<int> markRead() async {
    final json = await _send('POST', '$_url/read');
    final left = json['unreadCount'];
    return left is num ? left.toInt() : int.tryParse('$left') ?? 0;
  }

  Future<Map<String, dynamic>> _send(String method, String url) async {
    dynamic decoded;
    int status;

    try {
      final response = method == 'POST'
          ? await ApiClient.post(url)
          : await ApiClient.get(url);
      status = response.statusCode;
      decoded = response.body.isNotEmpty
          ? jsonDecode(response.body)
          : <String, dynamic>{};
    } on SessionExpiredException catch (e) {
      throw QuizException(QuizErrorKind.sessionExpired, e.message);
    } catch (_) {
      throw QuizException(
        QuizErrorKind.network,
        'Could not reach the server. Check your connection and try again.',
      );
    }

    if (status >= 200 && status < 300 && decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    throw QuizService.mapError(status, decoded);
  }
}
