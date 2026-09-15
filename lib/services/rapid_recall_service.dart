// lib/services/rapid_recall_service.dart
import 'dart:async';
import 'dart:convert';

import '../core/constant/api_constant.dart';
import '../core/constant/local_storage.dart';
import '../models/quiz_model.dart' show QuizException, QuizErrorKind;
import '../models/rapid_recall_model.dart';
import 'quiz_service.dart' show QuizService;
import 'refresh_api_services.dart';

/// The list response. [reason] is set only when the server sends one — the
/// student has no course selected yet — and is the sentence to show instead
/// of an empty list, because "nothing here" would be the wrong answer.
class RapidRecallList {
  final List<RapidRecallDeck> decks;
  final String? reason;

  const RapidRecallList({required this.decks, this.reason});
}

class RapidRecallService {
  static String get _url => '${ApiConstant.baseUrl}/users/me/rapid-recalls';

  /// Every deck this student can see: published, their course, their exam.
  ///
  /// One call for the whole feature — the topic, lesson and deck screens all
  /// group this same list on the device, so moving between them never waits
  /// on the network.
  Future<RapidRecallList> fetchAll() async {
    final json = await _send(_url);
    unawaited(
      LocalStorage.saveCached(LocalStorage.rapidRecallKey, jsonEncode(json)),
    );
    return parseList(json);
  }

  /// One deck with its cards.
  Future<RapidRecallDeck> fetchDeck(int id) async {
    final json = await _send('$_url/$id');
    final deck = json['rapidRecall'];
    if (deck is! Map) {
      // A 200 in the wrong shape is the server failing, not the deck
      // missing — a missing deck is a 404 and maps to lessonNotFound above.
      throw QuizException(
        QuizErrorKind.serverError,
        'This deck could not be opened.',
      );
    }
    return RapidRecallDeck.fromJson(Map<String, dynamic>.from(deck));
  }

  /// Shared with the provider's disk restore, so what comes off the cache is
  /// read exactly the way the live response is.
  static RapidRecallList parseList(Map<String, dynamic> json) {
    final raw = json['rapidRecalls'];
    return RapidRecallList(
      decks: raw is List
          ? raw
              .whereType<Map>()
              .map((d) => RapidRecallDeck.fromJson(Map<String, dynamic>.from(d)))
              .toList()
          : const [],
      reason: (json['reason'] as String?)?.trim().isNotEmpty == true
          ? json['reason'] as String
          : null,
    );
  }

  Future<Map<String, dynamic>> _send(String url) async {
    dynamic decoded;
    int status;

    try {
      final response = await ApiClient.get(url);
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

    // Same gates as every other student call — a 403 here is the same locked
    // content and the same subscribe prompt, so it reuses that mapping rather
    // than inventing a second vocabulary for it.
    throw QuizService.mapError(status, decoded);
  }
}
