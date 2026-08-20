import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/const/local_storegae.dart';
import '../core/const/api_constant.dart';

// TODO: adjust this import path to wherever AdminLocalStorage actually

/// Result wrapper so the provider never has to parse raw http.Response.
/// Shared by both create and update calls.
class CourseTypeResult {
  final bool isSuccess;
  final Map<String, dynamic>? data;
  final String? errorMessage;

  CourseTypeResult._({required this.isSuccess, this.data, this.errorMessage});

  factory CourseTypeResult.success(Map<String, dynamic> data) =>
      CourseTypeResult._(isSuccess: true, data: data);

  factory CourseTypeResult.failure(String message) =>
      CourseTypeResult._(isSuccess: false, errorMessage: message);
}

/// Handles the network calls for course types (a.k.a. exam types) under a course:
///
/// CREATE  -> POST /api/courses/:courseId/course-types
/// UPDATE  -> PUT  /api/courses/:courseId/course-types/:courseTypeId
///
/// Body sent (both calls):
/// {
///   "title": "...",            // required
///   "status": "...",           // required (draft | published | archived)
///   "description": "...",      // optional - only included if not null
///   "accessType": "..."        // optional - only included if not null (free | premium)
/// }
class CourseTypeService {
  final String baseUrl;

  CourseTypeService({this.baseUrl = ApiConstant.root});

  Future<String?> _getToken() async {
    final String? adminToken = await AdminLocalStorage.getToken();
    return (adminToken == null || adminToken.isEmpty) ? null : adminToken;
  }

  Map<String, dynamic> _buildBody({
    required String title,
    required String status,
    String? description,
    String? accessType,
  }) {
    final Map<String, dynamic> body = {
      'title': title,
      'status': status,
    };
    if (description != null) body['description'] = description;
    if (accessType != null) body['accessType'] = accessType;
    return body;
  }

  CourseTypeResult _parseResponse(http.Response response, String failureVerb) {
    final dynamic decoded =
    response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};

    if (response.statusCode == 200 || response.statusCode == 201) {
      return CourseTypeResult.success(
        decoded is Map<String, dynamic> ? decoded : <String, dynamic>{},
      );
    }

    final message = (decoded is Map && decoded['message'] != null)
        ? decoded['message'].toString()
        : 'Failed to $failureVerb exam type (status ${response.statusCode})';
    return CourseTypeResult.failure(message);
  }

  /// Creates a new exam type (course type) under [courseId].
  Future<CourseTypeResult> createCourseType({
    required int courseId,
    required String title,
    required String status,
    String? description,
    String? accessType,
  }) async {
    final adminToken = await _getToken();
    if (adminToken == null) {
      return CourseTypeResult.failure('Session expired. Please log in again.');
    }

    final uri = Uri.parse('$baseUrl/api/courses/$courseId/course-types');
    final body = _buildBody(
      title: title,
      status: status,
      description: description,
      accessType: accessType,
    );

    try {
      final response = await http
          .post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $adminToken',
        },
        body: jsonEncode(body),
      )
          .timeout(const Duration(seconds: 15));

      return _parseResponse(response, 'create');
    } on http.ClientException {
      return CourseTypeResult.failure('Network error. Please check your connection.');
    } on FormatException {
      return CourseTypeResult.failure('Unexpected response from server.');
    } catch (e) {
      return CourseTypeResult.failure('Something went wrong: $e');
    }
  }

  /// Updates an existing exam type (course type).
  Future<CourseTypeResult> updateCourseType({
    required int courseId,
    required int courseTypeId,
    required String title,
    required String status,
    String? description,
    String? accessType,
  }) async {
    final adminToken = await _getToken();
    if (adminToken == null) {
      return CourseTypeResult.failure('Session expired. Please log in again.');
    }

    final uri = Uri.parse('$baseUrl/api/courses/$courseId/course-types/$courseTypeId');
    final body = _buildBody(
      title: title,
      status: status,
      description: description,
      accessType: accessType,
    );

    try {
      final response = await http
          .put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $adminToken',
        },
        body: jsonEncode(body),
      )
          .timeout(const Duration(seconds: 15));

      return _parseResponse(response, 'update');
    } on http.ClientException {
      return CourseTypeResult.failure('Network error. Please check your connection.');
    } on FormatException {
      return CourseTypeResult.failure('Unexpected response from server.');
    } catch (e) {
      return CourseTypeResult.failure('Something went wrong: $e');
    }
  }

  /// Deletes an existing exam type (course type).
  Future<CourseTypeResult> deleteCourseType({
    required int courseId,
    required int courseTypeId,
  }) async {
    final adminToken = await _getToken();
    if (adminToken == null) {
      return CourseTypeResult.failure('Session expired. Please log in again.');
    }

    final uri = Uri.parse('$baseUrl/api/courses/$courseId/course-types/$courseTypeId');

    try {
      final response = await http
          .delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $adminToken',
        },
      )
          .timeout(const Duration(seconds: 15));

      return _parseResponse(response, 'delete');
    } on http.ClientException {
      return CourseTypeResult.failure('Network error. Please check your connection.');
    } on FormatException {
      return CourseTypeResult.failure('Unexpected response from server.');
    } catch (e) {
      return CourseTypeResult.failure('Something went wrong: $e');
    }
  }
}