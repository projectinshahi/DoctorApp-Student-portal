import 'dart:convert';
import 'package:dr_app/core/constant/local_storage.dart';
import 'package:http/http.dart' as http;

import '../View_model/selection_model.dart';

class SelectionService {
  static const String _baseUrl = 'https://doctorapp-backend-30gd.onrender.com/api/users/me/selection';

  Future<SelectionResult> selectCourse({
    int? courseId,
    int? courseTypeId,
  }) async {
    final token = await LocalStorage.getAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception('Not logged in. Please log in again.');
    }

    final body = <String, dynamic>{};
    if (courseId != null) body['courseId'] = courseId;
    if (courseTypeId != null) body['courseTypeId'] = courseTypeId;

    final response = await http.put(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return SelectionResult.fromJson(data);
    } else {
      throw Exception(data['error']?['message'] ?? 'Failed to select course');
    }
  }
}