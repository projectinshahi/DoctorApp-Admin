import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;

import '../core/const/local_storegae.dart';
import '../models/admin_student_model.dart';
import '../models/student_progress_model.dart';
import '../core/const/api_constant.dart';

class AdminStudentService {
  static const String baseUrl = ApiConstant.root;

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

  /// GET /admin/students/:id
  ///
  /// Root-mounted, like the list above - NOT /api/admin/students/:id, which is
  /// where the course and test endpoints live. Getting this wrong returns a
  /// 404 that looks like a missing student.
  Future<StudentDetail> getStudentDetail(int studentId) async {
    final String? adminToken = await AdminLocalStorage.getToken();

    if (adminToken == null || adminToken.isEmpty) {
      throw Exception('Admin token not found');
    }

    final uri = Uri.parse('$baseUrl/admin/students/$studentId');
    debugPrint('STUDENT DETAIL API URL: $uri');

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $adminToken',
      },
    ).timeout(const Duration(seconds: 30));

    debugPrint('STUDENT DETAIL STATUS: ${response.statusCode}');
    // Logged in full: the progress payload's nested arrays are not documented
    // field by field, and the key names are what a missing row comes down to.
    debugPrint('STUDENT DETAIL RESPONSE: ${response.body}');

    if (response.statusCode == 200) {
      return StudentDetail.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    if (response.statusCode == 401) {
      throw Exception('Unauthorized. Please login again.');
    }

    throw Exception(
      'Failed to load student progress: ${response.statusCode}',
    );
  }
}
