import 'dart:convert';

import 'package:dr_app/core/constant/local_storage.dart';
import 'package:http/http.dart' as http;

import '../View_model/Course_get_model.dart';

class CourseListGetService {
  Future<List<CourseListGetModel>> fetchCourses({
    String? status,
    String? accessType,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    final token = await LocalStorage.getAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception('Admin not logged in. Please log in again.');
    }

    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }

    if (accessType != null && accessType.isNotEmpty) {
      queryParams['accessType'] = accessType;
    }

    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }

    final uri = Uri.parse('https://doctorapp-backend-30gd.onrender.com/api/courses')
        .replace(queryParameters: queryParams);

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      final List<dynamic> list = data['courses'];

      return list
          .map((course) => CourseListGetModel.fromJson(course))
          .toList();
    } else {
      throw Exception(
        data['error']?['message'] ?? 'Failed to load courses',
      );
    }
  }
}