import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;

import '../core/const/local_storegae.dart';
import '../models/admin_student_model.dart';

class AdminStudentService {
  static const String baseUrl = 'http://localhost:3000';

  Future<AdminStudentResponse> getStudents({
    int page = 1,
    int limit = 10,
  }) async {
    final String? adminToken =
    await AdminLocalStorage.getToken();

    if (adminToken == null || adminToken.isEmpty) {
      throw Exception('Admin token not found');
    }

    final uri = Uri.parse(
      '$baseUrl/admin/students?page=$page&limit=$limit',
    );

    debugPrint('STUDENT API URL: $uri');
    debugPrint('ADMIN TOKEN EXISTS: ${adminToken.isNotEmpty}');

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $adminToken',
      },
    );

    debugPrint(
      'STUDENT API STATUS: ${response.statusCode}',
    );

    debugPrint(
      'STUDENT API RESPONSE: ${response.body}',
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> json =
      jsonDecode(response.body);

      return AdminStudentResponse.fromJson(json);
    }

    if (response.statusCode == 401) {
      throw Exception(
        'Unauthorized. Please login again.',
      );
    }

    throw Exception(
      'Failed to load students: '
          '${response.statusCode} ${response.body}',
    );
  }
}