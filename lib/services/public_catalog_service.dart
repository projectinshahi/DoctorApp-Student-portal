// lib/services/public_catalog_service.dart
//
// The catalogue for a visitor who has not signed in.
//
// Plain http, not ApiClient: there is no session to attach, and nothing here
// should ever trigger a token refresh or a sign-out. A 401 from this call
// would mean the endpoint stopped being public, not that the visitor's
// session ended.
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constant/api_constant.dart';
import '../models/public_course_model.dart';

class PublicCatalogService {
  static String get _url => '${ApiConstant.baseUrl}/courses?limit=50';

  /// Every published course and its exams. Throws on anything but a 200 —
  /// the screen shows the failure rather than an empty shelf, which would
  /// read as "this app has no courses".
  Future<List<PublicCourse>> fetchCourses() async {
    final response = await http
        .get(Uri.parse(_url))
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception('Could not load the courses. Please try again.');
    }

    final decoded = jsonDecode(response.body);
    final raw = decoded is Map ? decoded['courses'] : decoded;
    if (raw is! List) return const [];

    return raw
        .whereType<Map>()
        .map((c) => PublicCourse.fromJson(Map<String, dynamic>.from(c)))
        .toList();
  }
}
