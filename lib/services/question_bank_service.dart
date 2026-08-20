import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/const/api_constant.dart';
import '../core/const/local_storegae.dart';
import '../models/question_bank_model.dart';

/// Result wrapper, same shape as ChapterResult / LessonResult.
class QuestionResult {
  final bool isSuccess;
  final Question? question;
  final String? errorMessage;

  QuestionResult._({required this.isSuccess, this.question, this.errorMessage});

  factory QuestionResult.success(Question? question) =>
      QuestionResult._(isSuccess: true, question: question);

  factory QuestionResult.failure(String message) =>
      QuestionResult._(isSuccess: false, errorMessage: message);
}

class QuestionListResult {
  final bool isSuccess;
  final QuestionPage? page;
  final String? errorMessage;

  QuestionListResult._({required this.isSuccess, this.page, this.errorMessage});

  factory QuestionListResult.success(QuestionPage page) =>
      QuestionListResult._(isSuccess: true, page: page);

  factory QuestionListResult.failure(String message) =>
      QuestionListResult._(isSuccess: false, errorMessage: message);
}

/// Question bank CRUD:
///
/// CREATE    -> POST   /api/questions
/// LIST      -> GET    /api/questions?subjectId=&topicId=&difficulty=&status=
///                                   &tag=&search=&sort=&page=&limit=
/// READ      -> GET    /api/questions/:id
/// UPDATE    -> PUT    /api/questions/:id
/// DELETE    -> DELETE /api/questions/:id
/// STATUS    -> PATCH  /api/questions/:id/status
/// BULK      -> PATCH  /api/questions/bulk-status
/// DUPLICATE -> POST   /api/questions/:id/duplicate
///
/// Errors arrive nested as { "error": { "message": "..." } }, same as
/// chapters and lessons - so the delete endpoint's 409 comes through as a
/// plain message the UI prints verbatim.
class QuestionBankService {
  final String baseUrl;

  QuestionBankService({this.baseUrl = ApiConstant.baseUrl});

  static const Duration _timeout = Duration(seconds: 15);

  Future<String?> _getToken() async {
    final String? adminToken = await AdminLocalStorage.getToken();
    return (adminToken == null || adminToken.isEmpty) ? null : adminToken;
  }

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  String _messageFrom(dynamic decoded, int statusCode, String failureVerb) {
    if (decoded is Map && decoded['error'] is Map && decoded['error']['message'] != null) {
      return decoded['error']['message'].toString();
    }
    return 'Failed to $failureVerb (status $statusCode)';
  }

  QuestionResult _parseResponse(http.Response response, String failureVerb) {
    final dynamic decoded =
        response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};

    if (response.statusCode == 200 || response.statusCode == 201) {
      final raw = decoded is Map ? decoded['question'] : null;
      return QuestionResult.success(
        raw is Map<String, dynamic> ? Question.fromJson(raw) : null,
      );
    }
    return QuestionResult.failure(_messageFrom(decoded, response.statusCode, failureVerb));
  }

  Future<QuestionResult> createQuestion(Question question) =>
      _send('POST', '/questions', question.toPayload(), 'create question');

  Future<QuestionResult> updateQuestion(int questionId, Question question) =>
      _send('PUT', '/questions/$questionId', question.toPayload(), 'update question');

  Future<QuestionResult> getQuestion(int questionId) =>
      _send('GET', '/questions/$questionId', null, 'load question');

  /// The backend answers 409 while the quiz module is unshipped, so a failure
  /// here is expected rather than a bug - the caller shows the message as-is.
  Future<QuestionResult> deleteQuestion(int questionId) =>
      _send('DELETE', '/questions/$questionId', null, 'delete question');

  Future<QuestionResult> updateStatus(int questionId, QuestionStatus status) => _send(
        'PATCH',
        '/questions/$questionId/status',
        {'status': status.apiValue},
        'update status',
      );

  Future<QuestionResult> bulkUpdateStatus(List<int> questionIds, QuestionStatus status) =>
      _send(
        'PATCH',
        '/questions/bulk-status',
        {'questionIds': questionIds, 'status': status.apiValue},
        'update questions',
      );

  /// Returns the copy: status 'inactive', text suffixed "(Copy)".
  Future<QuestionResult> duplicateQuestion(int questionId) =>
      _send('POST', '/questions/$questionId/duplicate', null, 'duplicate question');

  Future<QuestionResult> _send(
    String method,
    String path,
    Map<String, dynamic>? body,
    String failureVerb,
  ) async {
    final adminToken = await _getToken();
    if (adminToken == null) {
      return QuestionResult.failure('Session expired. Please log in again.');
    }

    final uri = Uri.parse('$baseUrl$path');
    final headers = _headers(adminToken);
    final encoded = body == null ? null : jsonEncode(body);

    try {
      final http.Response response;
      switch (method) {
        case 'POST':
          response = await http.post(uri, headers: headers, body: encoded).timeout(_timeout);
        case 'PUT':
          response = await http.put(uri, headers: headers, body: encoded).timeout(_timeout);
        case 'PATCH':
          response = await http.patch(uri, headers: headers, body: encoded).timeout(_timeout);
        case 'DELETE':
          response = await http.delete(uri, headers: headers).timeout(_timeout);
        default:
          response = await http.get(uri, headers: headers).timeout(_timeout);
      }
      return _parseResponse(response, failureVerb);
    } on http.ClientException {
      return QuestionResult.failure('Network error. Please check your connection.');
    } on FormatException {
      return QuestionResult.failure('Unexpected response from server.');
    } catch (e) {
      return QuestionResult.failure('Something went wrong: $e');
    }
  }

  Future<QuestionListResult> getQuestions({
    int? subjectId,
    int? topicId,
    Difficulty? difficulty,
    QuestionStatus? status,
    String? tag,
    String? search,
    String? sort,
    int page = 1,
    int limit = 20,
  }) async {
    final adminToken = await _getToken();
    if (adminToken == null) {
      return QuestionListResult.failure('Session expired. Please log in again.');
    }

    // Only non-empty filters go on the query string - the backend combines
    // whatever it receives, so an empty `search=` is still a filter it has
    // to honour.
    final query = <String, String>{
      'page': '$page',
      'limit': '$limit',
      if (subjectId != null) 'subjectId': '$subjectId',
      if (topicId != null) 'topicId': '$topicId',
      if (difficulty != null) 'difficulty': difficulty.apiValue,
      if (status != null) 'status': status.apiValue,
      if (tag != null && tag.trim().isNotEmpty) 'tag': tag.trim(),
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (sort != null && sort.isNotEmpty) 'sort': sort,
    };

    final uri = Uri.parse('$baseUrl/questions').replace(queryParameters: query);

    try {
      final response = await http.get(uri, headers: _headers(adminToken)).timeout(_timeout);
      final decoded =
          response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};

      if (response.statusCode == 200) {
        return QuestionListResult.success(
          QuestionPage.fromJson(decoded, fallbackLimit: limit),
        );
      }
      return QuestionListResult.failure(
        _messageFrom(decoded, response.statusCode, 'load questions'),
      );
    } on http.ClientException {
      return QuestionListResult.failure('Network error. Please check your connection.');
    } on FormatException {
      return QuestionListResult.failure('Unexpected response from server.');
    } catch (e) {
      return QuestionListResult.failure('Something went wrong: $e');
    }
  }
}
