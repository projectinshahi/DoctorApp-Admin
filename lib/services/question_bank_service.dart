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

  /// How many quiz pools shrank as a result of a delete. Null when the
  /// response didn't report it (every endpoint other than delete).
  final int? affectedQuizzes;

  QuestionResult._({
    required this.isSuccess,
    this.question,
    this.errorMessage,
    this.affectedQuizzes,
  });

  factory QuestionResult.success(Question? question, {int? affectedQuizzes}) =>
      QuestionResult._(
        isSuccess: true,
        question: question,
        affectedQuizzes: affectedQuizzes,
      );

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

  /// Decodes a body that is *supposed* to be JSON. Returns null when it is
  /// not - an HTML error page from a server missing the route, typically -
  /// so the status code can still be reported instead of a parse failure.
  dynamic _tryDecode(String body) {
    if (body.isEmpty) return <String, dynamic>{};
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  String _messageFrom(dynamic decoded, int statusCode, String failureVerb) {
    if (statusCode == 401) return 'Session expired. Please log in again.';

    // A 404 here is not missing data - it is a server that does not have this
    // route at all, which is what an out-of-date deployment looks like. The
    // body is an HTML error page, so there is no message to read out of it.
    if (statusCode == 404) {
      return 'The server has no endpoint to $failureVerb - '
          'it is likely running an older build than this app expects.';
    }

    if (decoded is Map && decoded['error'] is Map && decoded['error']['message'] != null) {
      return decoded['error']['message'].toString();
    }
    return 'Failed to $failureVerb (status $statusCode)';
  }

  QuestionResult _parseResponse(http.Response response, String failureVerb) {
    final dynamic decoded =
        _tryDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final raw = decoded is Map ? decoded['question'] : null;
      return QuestionResult.success(
        raw is Map<String, dynamic> ? Question.fromJson(raw) : null,
        // Delete reports how many quiz pools lost a question. A quiz is a
        // filter, so deleting one question can quietly shrink several.
        affectedQuizzes:
            decoded is Map ? (decoded['affectedQuizzes'] as num?)?.toInt() : null,
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

  /// Succeeds now that the quiz module has shipped, reporting how many quiz
  /// pools shrank. Still 409s when something genuinely blocks the delete, and
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

  /// Long JSON bodies get truncated by the console, so they are printed in
  /// chunks - same helper ChapterService and QuizService use.
  void _log(String message) {
    const int chunk = 800;
    for (int i = 0; i < message.length; i += chunk) {
      print(message.substring(i, i + chunk > message.length ? message.length : i + chunk));
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

    _log('----------------------------------');
    _log('[QUESTIONS] GET $uri');

    try {
      final response = await http.get(uri, headers: _headers(adminToken)).timeout(_timeout);
      final decoded = _tryDecode(response.body);

      _log('[QUESTIONS] status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final page = QuestionPage.fromJson(decoded, fallbackLimit: limit);
        final activeCount =
            page.questions.where((q) => q.status == QuestionStatus.active).length;

        // Active vs inactive is the number that matters: only active questions
        // are ever served, so a topic can look full and still serve nothing.
        _log('[QUESTIONS] ${page.total} total, ${page.questions.length} on this page '
            '- $activeCount active, ${page.questions.length - activeCount} inactive');
        for (final q in page.questions) {
          final correct = q.options.where((o) => o.isCorrect).map((o) => o.optionText);
          _log('   ${q.status == QuestionStatus.active ? '[on ]' : '[OFF]'} '
              '[${q.id}] ${q.questionText}');
          _log('         answer: ${correct.isEmpty ? '(none marked)' : correct.join(', ')}');
        }
        _log('----------------------------------');
        return QuestionListResult.success(page);
      }

      final message = _messageFrom(decoded, response.statusCode, 'load questions');
      _log('[QUESTIONS] failed: $message');
      _log('----------------------------------');
      return QuestionListResult.failure(message);
    } on http.ClientException {
      return QuestionListResult.failure('Network error. Please check your connection.');
    } on FormatException {
      return QuestionListResult.failure('Unexpected response from server.');
    } catch (e) {
      return QuestionListResult.failure('Something went wrong: $e');
    }
  }
}
