import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/const/local_storegae.dart';

class LessonResult {
  final bool isSuccess;
  final Map<String, dynamic>? data;
  final String? errorMessage;

  LessonResult._({required this.isSuccess, this.data, this.errorMessage});

  factory LessonResult.success(Map<String, dynamic> data) =>
      LessonResult._(isSuccess: true, data: data);

  factory LessonResult.failure(String message) =>
      LessonResult._(isSuccess: false, errorMessage: message);
}

/// Result wrapper for endpoints that return a list (e.g. lessons by chapter).
class LessonListResult {
  final bool isSuccess;
  final List<Map<String, dynamic>>? data;
  final String? errorMessage;

  LessonListResult._({required this.isSuccess, this.data, this.errorMessage});

  factory LessonListResult.success(List<Map<String, dynamic>> data) =>
      LessonListResult._(isSuccess: true, data: data);

  factory LessonListResult.failure(String message) =>
      LessonListResult._(isSuccess: false, errorMessage: message);
}

/// Lesson type must be one of these three - matches backend VALID_LESSON_TYPES.
enum LessonType { video, text, quiz }

extension LessonTypeX on LessonType {
  String get apiValue => name; // 'video' | 'text' | 'quiz'

  static LessonType fromApiValue(String value) {
    return LessonType.values.firstWhere(
          (t) => t.apiValue == value,
      orElse: () => LessonType.text,
    );
  }
}

/// Access type must be one of these two - matches backend's AccessType enum.
enum LessonAccessType { free, premium }

extension LessonAccessTypeX on LessonAccessType {
  String get apiValue => name; // 'free' | 'premium'

  static LessonAccessType fromApiValue(String? value) {
    return LessonAccessType.values.firstWhere(
          (t) => t.apiValue == value,
      orElse: () => LessonAccessType.free,
    );
  }
}

class LessonService {
  final String baseUrl;

  LessonService({this.baseUrl = 'http://localhost:3000'});

  Future<String?> _getToken() async {
    final String? adminToken = await AdminLocalStorage.getToken();
    return (adminToken == null || adminToken.isEmpty) ? null : adminToken;
  }

  LessonResult _parseResponse(http.Response response, String failureVerb) {
    final dynamic decoded =
    response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};

    if (response.statusCode == 200 || response.statusCode == 201) {
      return LessonResult.success(
        decoded is Map<String, dynamic> ? decoded : <String, dynamic>{},
      );
    }

    String message = 'Failed to $failureVerb lesson (status ${response.statusCode})';
    if (decoded is Map && decoded['error'] is Map && decoded['error']['message'] != null) {
      message = decoded['error']['message'].toString();
    }
    return LessonResult.failure(message);
  }

  LessonListResult _parseListResponse(http.Response response, String failureVerb) {
    final dynamic decoded =
    response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};

    if (response.statusCode == 200) {
      final dynamic lessons = decoded is Map ? decoded['lessons'] : null;
      if (lessons is List) {
        return LessonListResult.success(
          lessons.whereType<Map<String, dynamic>>().toList(),
        );
      }
      return LessonListResult.success(const []);
    }

    String message = 'Failed to $failureVerb (status ${response.statusCode})';
    if (decoded is Map && decoded['error'] is Map && decoded['error']['message'] != null) {
      message = decoded['error']['message'].toString();
    }
    return LessonListResult.failure(message);
  }

  /// Creates a new lesson under [chapterId].
  /// [videoUrl]/[videoPublicId], [thumbnailUrl]/[thumbnailPublicId], and
  /// [noteUrl]/[notePublicId]/[noteFileType] are all optional and independent
  /// - pass any combination.
  /// [content] is only meaningful for quiz lessons (a quiz bank reference id).
  Future<LessonResult> createLesson({
    required int chapterId,
    required String title,
    String? description,
    required LessonType type,
    String? videoUrl,
    String? videoPublicId,
    String? thumbnailUrl,
    String? thumbnailPublicId,
    String? noteUrl,
    String? notePublicId,
    String? noteFileType,
    String? content,
    int? displayOrder,
    bool? isFreePreview,
    LessonAccessType? accessType,
  }) async {
    final adminToken = await _getToken();
    if (adminToken == null) {
      return LessonResult.failure('Session expired. Please log in again.');
    }

    // Matches backend: POST /api/chapters/:chapterId/lessons
    final uri = Uri.parse('$baseUrl/api/chapters/$chapterId/lessons');
    final body = <String, dynamic>{
      'title': title,
      'type': type.apiValue,
    };
    if (description != null) body['description'] = description;
    if (videoUrl != null) body['videoUrl'] = videoUrl;
    if (videoPublicId != null) body['videoPublicId'] = videoPublicId;
    if (thumbnailUrl != null) body['thumbnailUrl'] = thumbnailUrl;
    if (thumbnailPublicId != null) body['thumbnailPublicId'] = thumbnailPublicId;
    if (noteUrl != null) body['noteUrl'] = noteUrl;
    if (notePublicId != null) body['notePublicId'] = notePublicId;
    if (noteFileType != null) body['noteFileType'] = noteFileType;
    if (content != null) body['content'] = content;
    if (displayOrder != null) body['displayOrder'] = displayOrder;
    if (isFreePreview != null) body['isFreePreview'] = isFreePreview;
    if (accessType != null) body['accessType'] = accessType.apiValue;

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
      return LessonResult.failure('Network error. Please check your connection.');
    } on FormatException {
      return LessonResult.failure('Unexpected response from server.');
    } catch (e) {
      return LessonResult.failure('Something went wrong: $e');
    }
  }

  /// Fetches a single lesson by its id.
  Future<LessonResult> getLesson({required int lessonId}) async {
    final adminToken = await _getToken();
    if (adminToken == null) {
      return LessonResult.failure('Session expired. Please log in again.');
    }

    // Matches backend: GET /api/lessons/:id
    final uri = Uri.parse('$baseUrl/api/lessons/$lessonId');

    try {
      final response = await http
          .get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $adminToken',
        },
      )
          .timeout(const Duration(seconds: 15));

      return _parseResponse(response, 'fetch');
    } on http.ClientException {
      return LessonResult.failure('Network error. Please check your connection.');
    } on FormatException {
      return LessonResult.failure('Unexpected response from server.');
    } catch (e) {
      return LessonResult.failure('Something went wrong: $e');
    }
  }

  /// Fetches every lesson under [chapterId], ordered by displayOrder.
  Future<LessonListResult> getLessonsByChapter({required int chapterId}) async {
    final adminToken = await _getToken();
    if (adminToken == null) {
      return LessonListResult.failure('Session expired. Please log in again.');
    }

    // Matches backend: GET /api/chapters/:chapterId/lessons
    final uri = Uri.parse('$baseUrl/api/chapters/$chapterId/lessons');

    try {
      final response = await http
          .get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $adminToken',
        },
      )
          .timeout(const Duration(seconds: 15));

      return _parseListResponse(response, 'fetch lessons');
    } on http.ClientException {
      return LessonListResult.failure('Network error. Please check your connection.');
    } on FormatException {
      return LessonListResult.failure('Unexpected response from server.');
    } catch (e) {
      return LessonListResult.failure('Something went wrong: $e');
    }
  }


  /// sent.
  Future<LessonResult> updateLesson({
    required int chapterId, // kept for API-compat with callers; no longer used in the URL
    required int lessonId,
    String? title,
    String? description,
    bool removeDescription = false,
    LessonType? type,
    String? videoUrl,
    String? videoPublicId,
    bool removeVideo = false,
    String? thumbnailUrl,
    String? thumbnailPublicId,
    bool removeThumbnail = false,
    String? noteUrl,
    String? notePublicId,
    String? noteFileType,
    bool removeNote = false,
    String? content,
    int? displayOrder,
    bool? isFreePreview,
    LessonAccessType? accessType,
  }) async {
    final adminToken = await _getToken();
    if (adminToken == null) {
      return LessonResult.failure('Session expired. Please log in again.');
    }

    // Matches backend: PUT /api/lessons/:id
    final uri = Uri.parse('$baseUrl/api/lessons/$lessonId');
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (type != null) body['type'] = type.apiValue;

    if (removeDescription) {
      body['description'] = null;
    } else if (description != null) {
      body['description'] = description;
    }

    if (removeVideo) {
      body['videoUrl'] = null;
      body['videoPublicId'] = null;
    } else {
      if (videoUrl != null) body['videoUrl'] = videoUrl;
      if (videoPublicId != null) body['videoPublicId'] = videoPublicId;
    }

    if (removeThumbnail) {
      body['thumbnailUrl'] = null;
      body['thumbnailPublicId'] = null;
    } else {
      if (thumbnailUrl != null) body['thumbnailUrl'] = thumbnailUrl;
      if (thumbnailPublicId != null) body['thumbnailPublicId'] = thumbnailPublicId;
    }

    if (removeNote) {
      body['noteUrl'] = null;
      body['notePublicId'] = null;
      body['noteFileType'] = null;
    } else {
      if (noteUrl != null) body['noteUrl'] = noteUrl;
      if (notePublicId != null) body['notePublicId'] = notePublicId;
      if (noteFileType != null) body['noteFileType'] = noteFileType;
    }

    if (content != null) body['content'] = content;
    if (displayOrder != null) body['displayOrder'] = displayOrder;
    if (isFreePreview != null) body['isFreePreview'] = isFreePreview;
    if (accessType != null) body['accessType'] = accessType.apiValue;

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
      return LessonResult.failure('Network error. Please check your connection.');
    } on FormatException {
      return LessonResult.failure('Unexpected response from server.');
    } catch (e) {
      return LessonResult.failure('Something went wrong: $e');
    }
  }

  /// Deletes a lesson.
  Future<LessonResult> deleteLesson({
    required int chapterId, // kept for API-compat; unused in the URL
    required int lessonId,
  }) async {
    final adminToken = await _getToken();
    if (adminToken == null) {
      return LessonResult.failure('Session expired. Please log in again.');
    }

    // Matches backend: DELETE /api/lessons/:id
    final uri = Uri.parse('$baseUrl/api/lessons/$lessonId');

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
      return LessonResult.failure('Network error. Please check your connection.');
    } on FormatException {
      return LessonResult.failure('Unexpected response from server.');
    } catch (e) {
      return LessonResult.failure('Something went wrong: $e');
    }
  }
}