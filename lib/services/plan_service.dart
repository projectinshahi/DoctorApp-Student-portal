// lib/services/plan_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../View_model/plan_model.dart';
import '../core/constant/local_storage.dart';


class PlanService {
  static const String _baseUrl = 'https://doctorapp-backend-30gd.onrender.com/api';

  Future<List<PlanModel>> getPlansForCourse(int courseId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/courses/$courseId/plans'),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      final list = data['plans'] as List<dynamic>;
      return list.map((p) => PlanModel.fromJson(p)).toList();
    } else {
      throw Exception(data['error']?['message'] ?? 'Failed to load plans');
    }
  }

  Future<void> subscribeToPlan(int planId) async {
    final token = await LocalStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not logged in. Please log in again.');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/users/me/subscribe'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'planId': planId}),
    );

    if (response.statusCode != 201) {
      final data = jsonDecode(response.body);
      throw Exception(data['error']?['message'] ?? 'Failed to subscribe');
    }
  }
}