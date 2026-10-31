import 'dart:convert';

import 'package:dr_app/core/constant/local_storage.dart';
import 'package:dr_app/core/constant/api_constant.dart';

import '../View_model/Course_get_model.dart';
import 'refresh_api_services.dart';

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

    final uri = Uri.parse('${ApiConstant.baseUrl}/courses')
        .replace(queryParameters: queryParams);

    final response = await ApiClient.get(uri.toString());

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