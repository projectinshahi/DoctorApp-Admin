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

  /// Creates a new lesson under [chapterId].
  /// [videoUrl]/[videoPublicId] and [noteUrl]/[notePublicId]/[noteFileType] are
  /// all optional and independent - pass either, both, or neither.
  /// [content] is only meaningful for quiz lessons (a quiz bank reference id).
  Future<LessonResult> createLesson({
    required int chapterId,
    required String title,
    required LessonType type,
    String? videoUrl,
    String? videoPublicId,
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

    final uri = Uri.parse('$baseUrl/api/chapters/$chapterId/lessons');
    final body = <String, dynamic>{
      'title': title,
      'type': type.apiValue,
    };
    if (videoUrl != null) body['videoUrl'] = videoUrl;
    if (videoPublicId != null) body['videoPublicId'] = videoPublicId;
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

  /// Updates a lesson. All fields optional - only send what changed.
  ///
  /// [removeVideo] / [removeNote] explicitly clear the video or note fields
  /// on the backend (sets them to null there). This is separate from simply
  /// leaving [videoUrl] etc. as null, because null just means "not provided,
  /// don't touch it" — the backend only clears a field when it receives an
  /// *explicit* null in the JSON body. Passing removeVideo/removeNote makes
  /// sure that explicit null actually gets sent.
  Future<LessonResult> updateLesson({
    required int chapterId,
    required int lessonId,
    String? title,
    LessonType? type,
    String? videoUrl,
    String? videoPublicId,
    bool removeVideo = false,
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

    final uri = Uri.parse('$baseUrl/api/chapters/$chapterId/lessons/$lessonId');
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (type != null) body['type'] = type.apiValue;

    // ── Video ──
    if (removeVideo) {
      body['videoUrl'] = null;
      body['videoPublicId'] = null;
    } else {
      if (videoUrl != null) body['videoUrl'] = videoUrl;
      if (videoPublicId != null) body['videoPublicId'] = videoPublicId;
    }

    // ── Note ──
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
    required int chapterId,
    required int lessonId,
  }) async {
    final adminToken = await _getToken();
    if (adminToken == null) {
      return LessonResult.failure('Session expired. Please log in again.');
    }

    final uri = Uri.parse('$baseUrl/api/chapters/$chapterId/lessons/$lessonId');

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