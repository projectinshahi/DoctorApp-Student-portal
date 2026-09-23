// lib/services/student_plans_service.dart
import 'dart:convert';

import '../core/constant/api_constant.dart';
import '../models/quiz_model.dart' show QuizException, QuizErrorKind;
import '../models/student_plans_model.dart';
import 'quiz_service.dart' show QuizService;
import 'refresh_api_services.dart';

class StudentPlansService {
  static String get _url => '${ApiConstant.baseUrl}/users/me/plans';

  /// The plans for the student's selected course. No course id: the server
  /// reads the one they have chosen.
  Future<StudentPlans> fetch() async {
    dynamic decoded;
    int status;

    try {
      final response = await ApiClient.get(_url);
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
      return StudentPlans.fromJson(Map<String, dynamic>.from(decoded));
    }
    throw QuizService.mapError(status, decoded);
  }
}
