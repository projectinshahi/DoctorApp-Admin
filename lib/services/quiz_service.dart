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

  String _messageFrom(dynamic decoded, int statusCode, String failureVerb) {
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

    try {
      final response = await http.get(uri, headers: _headers(adminToken)).timeout(_timeout);
      final decoded =
          response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};

      if (response.statusCode == 200) {
        return QuizListResult.success(parseQuizzes(decoded));
      }
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
        response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};

    if (response.statusCode == 200 || response.statusCode == 201) {
      final raw = decoded is Map ? decoded['quiz'] : null;
      return QuizResult.success(raw is Map<String, dynamic> ? Quiz.fromJson(raw) : null);
    }
    return QuizResult.failure(_messageFrom(decoded, response.statusCode, failureVerb));
  }
}
