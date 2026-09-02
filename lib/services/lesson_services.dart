import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/const/local_storegae.dart';
import '../core/const/api_constant.dart';

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

enum LessonType { video, text, quiz }

extension LessonTypeX on LessonType {
  String get apiValue => name;

  static LessonType fromApiValue(String value) {
    return LessonType.values.firstWhere(
      (t) => t.apiValue == value,
      orElse: () => LessonType.text,
    );
  }
}

enum LessonAccessType { free, premium }

extension LessonAccessTypeX on LessonAccessType {
  String get apiValue => name;

  static LessonAccessType fromApiValue(String? value) {
    return LessonAccessType.values.firstWhere(
      (t) => t.apiValue == value,
      orElse: () => LessonAccessType.free,
    );
  }
}

enum LessonStatus { draft, published, archived }

extension LessonStatusX on LessonStatus {
  String get apiValue => name;

  static LessonStatus fromApiValue(String? value) {
    return LessonStatus.values.firstWhere(
      (s) => s.apiValue == value,
      orElse: () => LessonStatus.draft,
    );
  }
}

class LessonService {
  final String baseUrl;

  LessonService({this.baseUrl = ApiConstant.root});

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

  /// Writes the plan selection onto a create/update body.
  ///
  /// `planIds` is the real selection; `planId` is also sent, set to the first
  /// id, so a backend still on the single-plan column keeps working. A backend
  /// that reads `planIds` gets the whole set. An empty selection means "any
  /// active subscription" and is sent explicitly - otherwise a previously
  /// attached plan would silently survive the save.
  void _writePlans(Map<String, dynamic> body, {int? planId, List<int>? planIds}) {
    final ids = planIds != null
        ? planIds.toSet().toList()
        : <int>[if (planId != null) planId];
    body['planIds'] = ids;
    body['planId'] = ids.isEmpty ? null : ids.first;
  }

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
    LessonStatus? status,
    int? planId,
    List<int>? planIds,
    int? quizId,
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
    if (status != null) body['status'] = status.apiValue;
    if (quizId != null) body['quizId'] = quizId;
    // Plans are only meaningful for premium — sending them with 'free' is a
    // 400. Premium with an empty selection means "any active subscription".
    if (accessType == LessonAccessType.premium) {
      _writePlans(body, planId: planId, planIds: planIds);
    }

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

  Future<LessonResult> updateLesson({
    required int chapterId,
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
    LessonStatus? status,
    int? planId,
    List<int>? planIds,
    int? quizId,
    bool removeQuiz = false,
  }) async {
    final adminToken = await _getToken();
    if (adminToken == null) {
      return LessonResult.failure('Session expired. Please log in again.');
    }

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
    if (status != null) body['status'] = status.apiValue;

    // Same omit/null convention as the media fields: key absent leaves the
    // link alone, explicit null unlinks a lesson that is no longer a quiz.
    if (removeQuiz) {
      body['quizId'] = null;
    } else if (quizId != null) {
      body['quizId'] = quizId;
    }

    // Same rule as create: only send plans alongside premium.
    if (accessType == LessonAccessType.premium) {
      _writePlans(body, planId: planId, planIds: planIds);
    }

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

  Future<LessonResult> deleteLesson({
    required int chapterId,
    required int lessonId,
  }) async {
    final adminToken = await _getToken();
    if (adminToken == null) {
      return LessonResult.failure('Session expired. Please log in again.');
    }

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

  Future<LessonResult> getLesson({required int lessonId}) async {
    final adminToken = await _getToken();
    if (adminToken == null) {
      return LessonResult.failure('Session expired. Please log in again.');
    }

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

  Future<LessonListResult> getLessonsByChapter({required int chapterId}) async {
    final adminToken = await _getToken();
    if (adminToken == null) {
      return LessonListResult.failure('Session expired. Please log in again.');
    }

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

  /// Rewrites a chapter's lesson order.
  ///
  /// PATCH /api/chapters/:chapterId/lessons/reorder  { lessonIds }
  ///
  /// The array IS the order - positions come from the index, so the caller
  /// sends the list as it looks after the drop rather than computing a target
  /// position. Every update runs in one transaction server-side, so a
  /// half-applied reorder cannot happen.
  ///
  /// It must carry EVERY lesson in the chapter, not a filtered subset: a
  /// videos-only list would renumber the notes and quizzes around it.
  Future<LessonListResult> reorderLessons({
    required int chapterId,
    required List<int> lessonIds,
  }) async {
    final adminToken = await _getToken();
    if (adminToken == null) {
      return LessonListResult.failure('Session expired. Please log in again.');
    }
    if (lessonIds.isEmpty) {
      return LessonListResult.failure('Nothing to reorder.');
    }

    final uri = Uri.parse('$baseUrl/api/chapters/$chapterId/lessons/reorder');

    try {
      final response = await http
          .patch(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $adminToken',
            },
            body: jsonEncode({'lessonIds': lessonIds}),
          )
          .timeout(const Duration(seconds: 20));

      // The response carries the chapter in its new order, so the caller can
      // replace its list from it instead of re-fetching.
      return _parseListResponse(response, 'reorder the lessons');
    } on http.ClientException {
      return LessonListResult.failure('Network error. Please check your connection.');
    } on FormatException {
      return LessonListResult.failure('Unexpected response from server.');
    } catch (e) {
      return LessonListResult.failure('Something went wrong: $e');
    }
  }
}
