import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/const/api_constant.dart';
import '../core/const/local_storegae.dart';
import '../models/quiz_model.dart';

/// Result wrapper, same shape as UploadResult / ChapterResult.
class QuizResult {
  final bool isSuccess;
  final Quiz? quiz;
  final String? errorMessage;

  QuizResult._({required this.isSuccess, this.quiz, this.errorMessage});

  factory QuizResult.success(Quiz? quiz) => QuizResult._(isSuccess: true, quiz: quiz);

  factory QuizResult.failure(String message) =>
      QuizResult._(isSuccess: false, errorMessage: message);
}

class QuizListResult {
  final bool isSuccess;
  final List<Quiz>? quizzes;
  final String? errorMessage;

  QuizListResult._({required this.isSuccess, this.quizzes, this.errorMessage});

  factory QuizListResult.success(List<Quiz> quizzes) =>
      QuizListResult._(isSuccess: true, quizzes: quizzes);

  factory QuizListResult.failure(String message) =>
      QuizListResult._(isSuccess: false, errorMessage: message);
}

/// Named quizzes assembled from the Question Bank:
///
/// LIST   -> GET  /api/quizzes?subjectId=&topicId=&examTag=&status=active
/// READ   -> GET  /api/quizzes/:id
/// CREATE -> POST /api/quizzes
///
/// Errors are read from the nested { "error": { "message": "..." } } shape
/// every other service in this app already uses.
class QuizPreviewResult {
  final bool isSuccess;
  final QuizPreview? preview;
  final String? errorMessage;

  QuizPreviewResult._({required this.isSuccess, this.preview, this.errorMessage});

  factory QuizPreviewResult.success(QuizPreview preview) =>
      QuizPreviewResult._(isSuccess: true, preview: preview);

  factory QuizPreviewResult.failure(String message) =>
      QuizPreviewResult._(isSuccess: false, errorMessage: message);
}

class QuizService {
  final String baseUrl;

  QuizService({this.baseUrl = ApiConstant.baseUrl});

  static const Duration _timeout = Duration(seconds: 15);

  Future<String?> _getToken() async {
    final String? adminToken = await AdminLocalStorage.getToken();
    return (adminToken == null || adminToken.isEmpty) ? null : adminToken;
  }

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  /// Long JSON bodies get truncated by the console, so they are printed in
  /// chunks - same helper ChapterService uses.
  void _log(String message) {
    const int chunk = 800;
    for (int i = 0; i < message.length; i += chunk) {
      print(message.substring(i, i + chunk > message.length ? message.length : i + chunk));
    }
  }

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

  /// Quizzes matching the picker's filters. Only active quizzes by default -
  /// attaching an inactive quiz to a lesson would give students nothing.
  Future<QuizListResult> list({
    int? subjectId,
    int? topicId,
    String? examTag,
    String? status = 'active',
  }) async {
    final adminToken = await _getToken();
    if (adminToken == null) {
      return QuizListResult.failure('Session expired. Please log in again.');
    }

    final query = <String, String>{
      if (subjectId != null) 'subjectId': '$subjectId',
      if (topicId != null) 'topicId': '$topicId',
      if (examTag != null && examTag.trim().isNotEmpty) 'examTag': examTag.trim(),
      if (status != null && status.isNotEmpty) 'status': status,
    };

    final uri = Uri.parse('$baseUrl/quizzes')
        .replace(queryParameters: query.isEmpty ? null : query);

    _log('----------------------------------');
    _log('[QUIZZES] GET $uri');

    try {
      final response = await http.get(uri, headers: _headers(adminToken)).timeout(_timeout);
      final decoded = _tryDecode(response.body);

      _log('[QUIZZES] status: ${response.statusCode}');
      _log('[QUIZZES] body:');
      _log(response.body.isEmpty ? '(empty body)' : response.body);

      if (response.statusCode == 200) {
        final quizzes = parseQuizzes(decoded);
        // An empty list here is data, not a fault: it means no quiz has been
        // created for these filters yet. Saying so stops it reading as a bug.
        _log(quizzes.isEmpty
            ? '[QUIZZES] 0 quizzes match - none created for this subject/topic yet'
            : '[QUIZZES] parsed ${quizzes.length} quiz(zes)');
        for (final q in quizzes) {
          _log('   - [${q.id}] "${q.title}" subject=${q.subjectId} topic=${q.topicId} '
              'tag=${q.examTag ?? '-'} status=${q.status} '
              'linkedTo=${q.linkedLessonTitle ?? '-'}');
        }
        _log('----------------------------------');
        return QuizListResult.success(quizzes);
      }
      _log('[QUIZZES] failed with status ${response.statusCode}');
      _log('----------------------------------');
      return QuizListResult.failure(
        _messageFrom(decoded, response.statusCode, 'load quizzes'),
      );
    } on http.ClientException {
      return QuizListResult.failure('Network error. Please check your connection.');
    } on FormatException {
      return QuizListResult.failure('Unexpected response from server.');
    } catch (e) {
      return QuizListResult.failure('Something went wrong: $e');
    }
  }

  /// One quiz, for the summary chip's live question count.
  Future<QuizResult> get(int quizId) async {
    final adminToken = await _getToken();
    if (adminToken == null) {
      return QuizResult.failure('Session expired. Please log in again.');
    }

    final uri = Uri.parse('$baseUrl/quizzes/$quizId');

    try {
      final response = await http.get(uri, headers: _headers(adminToken)).timeout(_timeout);
      return _parse(response, 'load quiz');
    } on http.ClientException {
      return QuizResult.failure('Network error. Please check your connection.');
    } on FormatException {
      return QuizResult.failure('Unexpected response from server.');
    } catch (e) {
      return QuizResult.failure('Something went wrong: $e');
    }
  }

  Future<QuizResult> create(Quiz quiz) async {
    final adminToken = await _getToken();
    if (adminToken == null) {
      return QuizResult.failure('Session expired. Please log in again.');
    }

    final uri = Uri.parse('$baseUrl/quizzes');

    try {
      final response = await http
          .post(uri, headers: _headers(adminToken), body: jsonEncode(quiz.toPayload()))
          .timeout(_timeout);
      return _parse(response, 'create quiz');
    } on http.ClientException {
      return QuizResult.failure('Network error. Please check your connection.');
    } on FormatException {
      return QuizResult.failure('Unexpected response from server.');
    } catch (e) {
      return QuizResult.failure('Something went wrong: $e');
    }
  }

  QuizResult _parse(http.Response response, String failureVerb) {
    final dynamic decoded =
        _tryDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final raw = decoded is Map ? decoded['quiz'] : null;
      return QuizResult.success(raw is Map<String, dynamic> ? Quiz.fromJson(raw) : null);
    }
    return QuizResult.failure(_messageFrom(decoded, response.statusCode, failureVerb));
  }

  /// The admin preview: the exact questions a student would be served, but
  /// WITH `isCorrect` and `explanation`. Admin-only - never call this from a
  /// student context, it is the answer key.
  ///
  /// GET /api/quizzes/:id/preview
  Future<QuizPreviewResult> previewQuiz(int quizId) async {
    final adminToken = await _getToken();
    if (adminToken == null) {
      return QuizPreviewResult.failure('Session expired. Please log in again.');
    }

    final uri = Uri.parse('$baseUrl/quizzes/$quizId/preview');

    try {
      // Longer than the other calls: this one assembles every question.
      final response = await http
          .get(uri, headers: _headers(adminToken))
          .timeout(const Duration(seconds: 20));

      final decoded = _tryDecode(response.body);

      if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
        return QuizPreviewResult.success(QuizPreview.fromJson(decoded));
      }
      return QuizPreviewResult.failure(
        _messageFrom(decoded, response.statusCode, 'load the quiz preview'),
      );
    } on http.ClientException {
      return QuizPreviewResult.failure('Network error. Please check your connection.');
    } on FormatException {
      return QuizPreviewResult.failure('Unexpected response from server.');
    } catch (e) {
      return QuizPreviewResult.failure('Something went wrong: $e');
    }
  }
}
