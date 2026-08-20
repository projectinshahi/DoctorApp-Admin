// lib/services/admin_plan_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/const/local_storegae.dart';
import '../models/panal_model.dart';
import '../core/const/api_constant.dart';


class AdminPlanService {
  static const String _baseUrl = ApiConstant.baseUrl;

  Future<List<AdminPlanModel>> getPlansForCourse(int courseId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/courses/$courseId/plans'),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      final list = data['plans'] as List<dynamic>;
      return list.map((p) => AdminPlanModel.fromJson(p)).toList();
    } else {
      throw Exception(data['error']?['message'] ?? 'Failed to load plans');
    }
  }

  Future<AdminPlanModel> createPlan({
    required int courseId,
    required String title,
    String? description,
    required double price,
    required int durationDays,
  }) async {
    final token = await AdminLocalStorage.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not logged in. Please log in again.');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/courses/$courseId/plans'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'title': title,
        'description': description,
        'price': price,
        'durationDays': durationDays,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 201) {
      return AdminPlanModel.fromJson(data['plan']);
    } else {
      throw Exception(data['error']?['message'] ?? 'Failed to create plan');
    }
  }

  Future<AdminPlanModel> updatePlan({
    required int planId,
    String? title,
    String? description,
    double? price,
    int? durationDays,
    bool? isActive,
  }) async {
    final token = await AdminLocalStorage.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not logged in. Please log in again.');
    }

    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (description != null) body['description'] = description;
    if (price != null) body['price'] = price;
    if (durationDays != null) body['durationDays'] = durationDays;
    if (isActive != null) body['isActive'] = isActive;

    final response = await http.put(
      Uri.parse('$_baseUrl/plans/$planId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return AdminPlanModel.fromJson(data['plan']);
    } else {
      throw Exception(data['error']?['message'] ?? 'Failed to update plan');
    }
  }

  Future<void> deletePlan(int planId) async {
    final token = await AdminLocalStorage.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not logged in. Please log in again.');
    }

    final response = await http.delete(
      Uri.parse('$_baseUrl/plans/$planId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['error']?['message'] ?? 'Failed to delete plan');
    }
  }
}