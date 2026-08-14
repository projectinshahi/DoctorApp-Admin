import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/const/local_storegae.dart';

/// Result wrapper, same pattern as CourseTypeResult.
class ChapterResult {
  final bool isSuccess;
  final Map<String, dynamic>? data;
  final String? errorMessage;

  ChapterResult._({required this.isSuccess, this.data, this.errorMessage});

  factory ChapterResult.success(Map<String, dynamic> data) =>
      ChapterResult._(isSuccess: true, data: data);

  factory ChapterResult.failure(String message) =>
      ChapterResult._(isSuccess: false, errorMessage: message);
}

/// Chapters ("Syllabus") live under a course type (exam type):
///
/// CREATE -> POST   /api/course-types/:courseTypeId/chapters
/// UPDATE -> PUT    /api/course-types/:courseTypeId/chapters/:chapterId
/// DELETE -> DELETE /api/course-types/:courseTypeId/chapters/:chapterId
///
/// NOTE: unlike CourseTypeService, the backend for chapters returns
/// errors nested as { "error": { "message": "..." } }, not flat
/// { "message": "..." } - the parser below matches that exact shape.
class ChapterService {
  final String baseUrl;

  ChapterService({this.baseUrl = 'http://localhost:3000'});

  Future<String?> _getToken() async {
    final String? adminToken = await AdminLocalStorage.getToken();
    return (adminToken == null || adminToken.isEmpty) ? null : adminToken;
  }

  ChapterResult _parseResponse(http.Response response, String failureVerb) {
    final dynamic decoded =
    response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};

    if (response.statusCode == 200 || response.statusCode == 201) {
      return ChapterResult.success(
        decoded is Map<String, dynamic> ? decoded : <String, dynamic>{},
      );
    }

    String message = 'Failed to $failureVerb chapter (status ${response.statusCode})';
    if (decoded is Map && decoded['error'] is Map && decoded['error']['message'] != null) {
      message = decoded['error']['message'].toString();
    }
    return ChapterResult.failure(message);
  }

  /// Creates a new chapter (syllabus item) under [courseTypeId].
  /// If [displayOrder] is omitted, pass the current chapter count from
  /// the UI so the new chapter lands at the end of the list.
  Future<ChapterResult> createChapter({
    required int courseTypeId,
    required String title,
    int? displayOrder,
  }) async {
    final adminToken = await _getToken();
    if (adminToken == null) {
      return ChapterResult.failure('Session expired. Please log in again.');
    }

    final uri = Uri.parse('$baseUrl/api/course-types/$courseTypeId/chapters');
    final body = <String, dynamic>{'title': title};
    if (displayOrder != null) body['displayOrder'] = displayOrder;

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
      return ChapterResult.failure('Network error. Please check your connection.');
    } on FormatException {
      return ChapterResult.failure('Unexpected response from server.');
    } catch (e) {
      return ChapterResult.failure('Something went wrong: $e');
    }
  }

  /// Renames a chapter (or updates its displayOrder).
  Future<ChapterResult> updateChapter({
    required int courseTypeId,
    required int chapterId,
    String? title,
    int? displayOrder,
  }) async {
    final adminToken = await _getToken();
    if (adminToken == null) {
      return ChapterResult.failure('Session expired. Please log in again.');
    }

    final uri = Uri.parse('$baseUrl/api/course-types/$courseTypeId/chapters/$chapterId');
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (displayOrder != null) body['displayOrder'] = displayOrder;

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
      return ChapterResult.failure('Network error. Please check your connection.');
    } on FormatException {
      return ChapterResult.failure('Unexpected response from server.');
    } catch (e) {
      return ChapterResult.failure('Something went wrong: $e');
    }
  }

  /// Deletes a chapter. Backend cascades this to delete its lessons too.
  Future<ChapterResult> deleteChapter({
    required int courseTypeId,
    required int chapterId,
  }) async {
    final adminToken = await _getToken();
    if (adminToken == null) {
      return ChapterResult.failure('Session expired. Please log in again.');
    }

    final uri = Uri.parse('$baseUrl/api/course-types/$courseTypeId/chapters/$chapterId');

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
      return ChapterResult.failure('Network error. Please check your connection.');
    } on FormatException {
      return ChapterResult.failure('Unexpected response from server.');
    } catch (e) {
      return ChapterResult.failure('Something went wrong: $e');
    }
  }
}