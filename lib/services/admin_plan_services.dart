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

  /// POST /api/courses/:courseId/plans
  ///
  /// Takes the whole plan, [AdminPlanModel.toJson] deciding what goes on the
  /// wire - the same body the `plans` array on course creation uses, so the
  /// two cannot describe a plan differently.
  Future<AdminPlanModel> createPlan({
    required int courseId,
    required AdminPlanModel plan,
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
      body: jsonEncode(plan.toJson()),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 201 || response.statusCode == 200) {
      return AdminPlanModel.fromJson(data['plan']);
    }
    throw Exception(data['error']?['message'] ?? 'Failed to create plan');
  }

  /// PUT /api/plans/:id - partial, so only what changed is sent.
  ///
  /// [isActive] is how a price is retired. Never delete a plan that has been
  /// sold: a deleted plan orphans every subscription that referenced it.
  Future<AdminPlanModel> updatePlan({
    required int planId,
    String? title,
    String? description,
    double? price,
    int? durationDays,
    bool? isActive,
    String? currency,
    String? accentColor,
    List<String>? features,
    List<PlanEntitlement>? entitlements,
  }) {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (description != null) body['description'] = description;
    if (price != null) body['price'] = price;
    if (durationDays != null) body['durationDays'] = durationDays;
    if (isActive != null) body['isActive'] = isActive;
    if (currency != null) body['currency'] = currency;
    if (accentColor != null) body['accentColor'] = accentColor;
    if (features != null) body['features'] = features;
    if (entitlements != null) {
      body['entitlements'] = [for (final e in entitlements) e.code];
    }
    return updatePlanBody(planId, body);
  }

  /// The PUT itself, for a body already reduced to the changed fields - the
  /// Plans screen builds one with `planChanges`.
  Future<AdminPlanModel> updatePlanBody(
    int planId,
    Map<String, dynamic> body,
  ) async {
    final token = await AdminLocalStorage.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not logged in. Please log in again.');
    }

    final response = await http.put(
      Uri.parse('$_baseUrl/plans/$planId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    final data = _tryDecode(response.body);
    if (response.statusCode == 200 &&
        data is Map &&
        data['plan'] is Map<String, dynamic>) {
      return AdminPlanModel.fromJson(data['plan'] as Map<String, dynamic>);
    }
    throw Exception(_errorOf(
        data, 'Failed to update plan (status ${response.statusCode})'));
  }

  /// A cold start on the host answers with an HTML page, which jsonDecode
  /// would throw on - hiding the status code that says what went wrong.
  static dynamic _tryDecode(String body) {
    if (body.trim().isEmpty) return null;
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  static String _errorOf(dynamic data, String fallback) {
    if (data is Map) {
      final error = data['error'];
      if (error is Map && error['message'] != null) return '${error['message']}';
      if (data['message'] != null) return '${data['message']}';
    }
    return fallback;
  }

  /// Retiring a plan, which is [updatePlan] with one field - named separately
  /// so the call site reads as the decision it is.
  Future<AdminPlanModel> retirePlan(int planId) =>
      updatePlan(planId: planId, isActive: false);

  /// Permanent. Prefer [retirePlan] for anything that has ever been sold.
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