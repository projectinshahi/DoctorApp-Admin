import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/const/local_storegae.dart';
import '../models/chapter_summary_model.dart';
import '../core/const/api_constant.dart';

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

class ChapterListResult {
  final bool isSuccess;
  final List<ChapterSummary>? chapters;
  final String? errorMessage;

  ChapterListResult._({required this.isSuccess, this.chapters, this.errorMessage});

  factory ChapterListResult.success(List<ChapterSummary> chapters) =>
      ChapterListResult._(isSuccess: true, chapters: chapters);

  factory ChapterListResult.failure(String message) =>
      ChapterListResult._(isSuccess: false, errorMessage: message);
}


class ChapterService {
  final String baseUrl;

  ChapterService({this.baseUrl = ApiConstant.root});

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

  /// Long JSON bodies get truncated by the console, so they are printed in
  /// chunks - same helper CourseDetailsService uses.
  void _log(String message) {
    const int chunk = 800;
    for (int i = 0; i < message.length; i += chunk) {
      print(message.substring(i, i + chunk > message.length ? message.length : i + chunk));
    }
  }

  /// Lists the chapters under a course type.
  ///
  /// GET /api/course-types/:courseTypeId/chapters
  ///
  /// Lets the app rebuild the syllabus one level at a time when the full
  /// course tree (/api/courses/:id) is unavailable. Every call prints its
  /// URL, status and raw body to the terminal - this is the route that has
  /// to be checked per course type, so it is never worth guessing at.
  Future<ChapterListResult> getChapters({required int courseTypeId}) async {
    final url = '$baseUrl/api/course-types/$courseTypeId/chapters';

    _log('----------------------------------');
    _log('[CHAPTERS] GET $url');
    _log('[CHAPTERS] courseTypeId: $courseTypeId');

    final adminToken = await _getToken();
    if (adminToken == null) {
      _log('[CHAPTERS] no admin token - request not sent');
      _log('----------------------------------');
      return ChapterListResult.failure('Session expired. Please log in again.');
    }

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $adminToken',
        },
      ).timeout(const Duration(seconds: 15));

      _log('[CHAPTERS] status: ${response.statusCode}');
      _log('[CHAPTERS] body:');
      _log(response.body.isEmpty ? '(empty body)' : response.body);

      final dynamic decoded =
          response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};

      if (response.statusCode == 200) {
        final chapters = parseChapterSummaries(decoded);
        _log('[CHAPTERS] parsed ${chapters.length} chapter(s) '
            'for courseTypeId $courseTypeId');
        for (final c in chapters) {
          _log('   - [${c.id}] "${c.title}" order=${c.displayOrder} '
              'lessons=${c.lessonCount}');
        }
        _log('----------------------------------');
        return ChapterListResult.success(chapters);
      }

      String message = 'Failed to load chapters (status ${response.statusCode})';
      if (decoded is Map && decoded['error'] is Map && decoded['error']['message'] != null) {
        message = decoded['error']['message'].toString();
      }
      _log('[CHAPTERS] failed: $message');
      _log('----------------------------------');
      return ChapterListResult.failure(message);
    } on http.ClientException catch (e) {
      // On web this is also what a blocked CORS pre-flight looks like.
      _log('[CHAPTERS] network/CORS error: $e');
      _log('----------------------------------');
      return ChapterListResult.failure('Network error. Please check your connection.');
    } on FormatException catch (e) {
      _log('[CHAPTERS] JSON parse error: $e');
      _log('----------------------------------');
      return ChapterListResult.failure('Unexpected response from server.');
    } catch (e) {
      _log('[CHAPTERS] request failed: $e');
      _log('----------------------------------');
      return ChapterListResult.failure('Something went wrong: $e');
    }
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