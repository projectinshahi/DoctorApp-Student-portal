import 'dart:convert';
import 'package:http/http.dart' as http;

import '../repository/course_content.dart';

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);

  bool get isAuthError => statusCode == 401;

  @override
  String toString() => message;
}

class CourseService {
  final String baseUrl;
  String? token; // set this after login

  CourseService({required this.baseUrl, this.token});

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  dynamic _decode(http.Response res) {
    final body = res.body.isEmpty ? {} : jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw ApiException(
      body is Map && body['error']?['message'] != null
          ? body['error']['message']
          : 'Request failed (${res.statusCode})',
      res.statusCode,
    );
  }

  /// GET /api/courses/:courseId/course-types  — public
  Future<List<CourseTypeBrief>> getCourseTypes(int courseId) async {
    final res = await http.get(
      Uri.parse('https://doctorapp-backend-30gd.onrender.com/api/courses/$courseId/course-types'),
      headers: _headers,
    );
    final body = _decode(res);
    return (body['courseTypes'] as List).map((e) => CourseTypeBrief.fromJson(e)).toList();
  }

  /// PUT /api/users/me/selection  — saves the student's pick
  Future<void> selectCourseType({required int courseId, required int courseTypeId}) async {
    final res = await http.put(
      Uri.parse('$baseUrl/api/users/me/selection'),
      headers: _headers,
      body: jsonEncode({'courseId': courseId, 'courseTypeId': courseTypeId}),
    );
    _decode(res);
  }

  /// GET /api/users/me/selection/content  — chapters + lessons of the selected type
  Future<SelectedContent> getSelectedContent() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/users/me/selection/content'),
      headers: _headers,
    );
    return SelectedContent.fromJson(_decode(res));
  }
}
