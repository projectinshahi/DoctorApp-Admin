import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/const/local_storegae.dart';
import '../models/lesson_detail_model.dart';
import '../core/const/api_constant.dart';

class LessonResult {
  final bool isSuccess;
  final LessonDetail? lesson;
  final String? errorMessage;

  LessonResult._({required this.isSuccess, this.lesson, this.errorMessage});

  factory LessonResult.success(LessonDetail lesson) => LessonResult._(isSuccess: true, lesson: lesson);
  factory LessonResult.failure(String message) => LessonResult._(isSuccess: false, errorMessage: message);
}

/// Handles fetching a single lesson's full detail by its own id.
/// GET /api/lessons/:id  (?includeChapter=true optional)
class LessonDetailsService {
  final String baseUrl;

  LessonDetailsService({this.baseUrl = ApiConstant.root});

  Future<String?> _getToken() async {
    final adminToken = await AdminLocalStorage.getToken();
    return (adminToken == null || adminToken.isEmpty) ? null : adminToken;
  }

  Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  String? _errorMessageFrom(dynamic decoded, int statusCode, String failureVerb) {
    if (decoded is Map && decoded['error'] is Map && decoded['error']['message'] != null) {
      return decoded['error']['message'].toString();
    }
    return 'Failed to $failureVerb (status $statusCode)';
  }

  /// Fetches a single lesson by its own id.
  /// Pass [includeChapter] = true to also get the parent chapter's
  /// id/title/courseId/courseTypeId - useful for breadcrumbs.
  Future<LessonResult> getLesson({
    required int lessonId,
    bool includeChapter = false,
  }) async {
    final adminToken = await _getToken();

    if (adminToken == null) {
      print('❌ Token is null');
      return LessonResult.failure('Session expired. Please log in again.');
    }

    final uri = Uri.parse('$baseUrl/api/lessons/$lessonId').replace(
      queryParameters: includeChapter
          ? {'includeChapter': 'true'}
          : null,
    );

    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📚 GET LESSON API');
    print('➡️ URL: $uri');
    print('➡️ Lesson ID: $lessonId');
    print('➡️ Include Chapter: $includeChapter');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    try {
      final response = await http
          .get(
        uri,
        headers: _headers(adminToken),
      )
          .timeout(const Duration(seconds: 15));

      print('📥 RESPONSE');
      print('➡️ Status Code: ${response.statusCode}');
      print('➡️ Response Body:');
      print(response.body);
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      final decoded = response.body.isNotEmpty
          ? jsonDecode(response.body)
          : <String, dynamic>{};

      print('🔍 DECODED RESPONSE:');
      print(decoded);

      if (response.statusCode == 200 &&
          decoded is Map &&
          decoded['lesson'] != null) {

        print('✅ Lesson loaded successfully');
        print('📖 Lesson: ${decoded['lesson']}');

        return LessonResult.success(
          LessonDetail.fromJson(
            decoded['lesson'] as Map<String, dynamic>,
          ),
        );
      }

      print('❌ API Error');

      return LessonResult.failure(
        _errorMessageFrom(
          decoded,
          response.statusCode,
          'load lesson',
        )!,
      );

    } on http.ClientException catch (e) {
      print('❌ CLIENT EXCEPTION: $e');

      return LessonResult.failure(
        'Network error. Please check your connection.',
      );

    } on FormatException catch (e) {
      print('❌ JSON FORMAT ERROR: $e');

      return LessonResult.failure(
        'Unexpected response from server.',
      );

    } catch (e) {
      print('❌ UNKNOWN ERROR: $e');

      return LessonResult.failure(
        'Something went wrong: $e',
      );
    }
  }
}