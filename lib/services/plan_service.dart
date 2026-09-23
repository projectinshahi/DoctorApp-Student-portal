// lib/services/plan_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../View_model/plan_model.dart';
import '../core/constant/api_constant.dart';


class PlanService {
  static const String _baseUrl = ApiConstant.baseUrl;

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
}