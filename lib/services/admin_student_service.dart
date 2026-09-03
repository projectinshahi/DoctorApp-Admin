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

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<String> _requireToken() async {
    final token = await AdminLocalStorage.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Admin token not found');
    }
    return token;
  }

  /// The server's own sentence when it refuses, rather than a status code.
  String _errorFrom(http.Response response, String verb) {
    if (response.statusCode == 401) {
      return 'Unauthorized. Please login again.';
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map && error['message'] != null) return '${error['message']}';
        if (decoded['message'] != null) return '${decoded['message']}';
      }
    } on FormatException {
      // An HTML error page, not JSON. Fall through to the generic sentence.
    }
    return 'Could not $verb (status ${response.statusCode})';
  }

  /// PATCH /admin/students/:id/status
  ///
  /// Blocking also revokes every session, so this one call both blocks the
  /// student and signs them out everywhere. [sessionsRevoked] is how many
  /// devices that actually hit - reported, never assumed. Zero is normal: the
  /// student simply was not signed in.
  ///
  /// [status] is an enum because the API takes exactly verified / unverified /
  /// blocked and 400s on anything else.
  Future<({AdminStudentModel student, int sessionsRevoked})> setStatus({
    required int studentId,
    required StudentStatus status,
  }) async {
    final token = await _requireToken();

    final response = await http
        .patch(
          Uri.parse('$baseUrl/admin/students/$studentId/status'),
          headers: _headers(token),
          body: jsonEncode({'status': status.wire}),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final student = decoded['student'];
      if (student is! Map<String, dynamic>) {
        throw Exception('The server did not return the updated student.');
      }
      return (
        // Read back from the response, never toggled locally: the server is
        // the only thing that knows whether the change took.
        student: AdminStudentModel.fromJson(student),
        sessionsRevoked: (decoded['sessionsRevoked'] as num?)?.toInt() ?? 0,
      );
    }

    throw Exception(_errorFrom(response, 'change the account status'));
  }

  /// POST /admin/students/:id/sessions/revoke
  ///
  /// Signs the student out without blocking them. This is the fix for someone
  /// locked out by the single-device rule after losing a phone - they can sign
  /// straight back in. Blocking is not that fix.
  Future<({int revoked, String message})> revokeSessions(int studentId) async {
    final token = await _requireToken();

    final response = await http
        .post(
          Uri.parse('$baseUrl/admin/students/$studentId/sessions/revoke'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return (
        revoked: (decoded['revoked'] as num?)?.toInt() ?? 0,
        message: (decoded['message'] as String?) ?? 'Signed out.',
      );
    }

    throw Exception(_errorFrom(response, 'sign the student out'));
  }
}
