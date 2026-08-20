import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/const/local_storegae.dart';
import '../models/course_details_model.dart';
import '../models/course_types_model.dart';
import '../core/const/api_constant.dart';

class CourseDetailsService {
  static const String _baseUrl = ApiConstant.baseUrl;

  /// Long JSON bodies get truncated by the console, so they're printed in
  /// chunks - a 500's payload is useless if it's cut off before the message.
  void _log(String message) {
    const int chunk = 800;
    for (int i = 0; i < message.length; i += chunk) {
      print(message.substring(i, i + chunk > message.length ? message.length : i + chunk));
    }
  }

  /// Pulls the message out of the backend's nested error envelope:
  /// { "error": { "message": "..." } }. Falls back to a flat "message",
  /// then to the bare status code.
  String _errorMessageFrom(dynamic decoded, int statusCode) {
    if (decoded is Map) {
      if (decoded['error'] is Map && decoded['error']['message'] != null) {
        return decoded['error']['message'].toString();
      }
      if (decoded['message'] != null) return decoded['message'].toString();
    }
    return 'Failed to load course details (status $statusCode)';
  }

  /// GET /api/courses/:id/course-types
  ///
  /// The narrow, public read used when the full tree above fails. It never
  /// touches lessons, so it survives the schema drift that breaks
  /// /api/courses/:id on the deployed backend.
  Future<CourseTypesResponse> fetchCourseTypes(int courseId) async {
    final String? token = await AdminLocalStorage.getToken();
    final Uri url = Uri.parse('$_baseUrl/courses/$courseId/course-types');

    _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _log('📗 GET COURSE TYPES API (fallback)');
    _log('➡️ URL: $url');
    _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    try {
      // The route is public, but the token is still sent when present so
      // this keeps working if it is ever put behind auth.
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 20));

      _log('📥 RESPONSE');
      _log('➡️ Status Code: ${response.statusCode}');
      _log('➡️ Response Body:');
      _log(response.body.isEmpty ? '(empty body)' : response.body);
      _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      final dynamic decoded =
          response.body.isNotEmpty ? json.decode(response.body) : <String, dynamic>{};

      if (response.statusCode != 200) {
        final message = _errorMessageFrom(decoded, response.statusCode);
        _log('❌ FALLBACK ERROR: $message');
        throw Exception(message);
      }

      final parsed = CourseTypesResponse.fromJson(decoded as Map<String, dynamic>);
      _log('✅ Fallback loaded "${parsed.courseTitle}" '
          'with ${parsed.courseTypes.length} published exam type(s)');
      for (final ct in parsed.courseTypes) {
        _log('   • [${ct.id}] "${ct.title}" access=${ct.accessType} '
            'displayOrder=${ct.displayOrder} chapters=${ct.chapterCount}');
      }
      _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      return parsed;
    } on FormatException catch (e) {
      _log('❌ JSON PARSE ERROR: $e');
      throw Exception('Server returned a non-JSON response.');
    } catch (e) {
      _log('❌ FALLBACK REQUEST FAILED: $e');
      rethrow;
    }
  }

  Future<CourseDetails?> fetchCourseDetails(int courseId) async {
    final String? token = await AdminLocalStorage.getToken();
    final Uri url = Uri.parse('$_baseUrl/courses/$courseId');

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 20));

      final dynamic decoded =
          response.body.isNotEmpty ? json.decode(response.body) : <String, dynamic>{};

      if (response.statusCode != 200) {
        throw Exception(_errorMessageFrom(decoded, response.statusCode));
      }

      final courseResponse =
          CourseDetailsResponse.fromJson(decoded as Map<String, dynamic>);
      return courseResponse.course;
    } on FormatException {
      // A 500 from a proxy often returns an HTML error page rather than JSON.
      throw Exception('Server returned a non-JSON response.');
    }
  }
}
