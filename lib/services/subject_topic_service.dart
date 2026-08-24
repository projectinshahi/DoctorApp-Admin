import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/const/api_constant.dart';
import '../core/const/local_storegae.dart';
import '../models/question_bank_model.dart';

/// Result wrapper, same shape as ChapterResult.
class SubjectResult {
  final bool isSuccess;
  final Subject? subject;
  final String? errorMessage;

  SubjectResult._({required this.isSuccess, this.subject, this.errorMessage});

  factory SubjectResult.success(Subject? subject) =>
      SubjectResult._(isSuccess: true, subject: subject);

  factory SubjectResult.failure(String message) =>
      SubjectResult._(isSuccess: false, errorMessage: message);
}

class SubjectListResult {
  final bool isSuccess;
  final List<Subject>? subjects;
  final String? errorMessage;

  SubjectListResult._({required this.isSuccess, this.subjects, this.errorMessage});

  factory SubjectListResult.success(List<Subject> subjects) =>
      SubjectListResult._(isSuccess: true, subjects: subjects);

  factory SubjectListResult.failure(String message) =>
      SubjectListResult._(isSuccess: false, errorMessage: message);
}

class TopicResult {
  final bool isSuccess;
  final Topic? topic;
  final String? errorMessage;

  TopicResult._({required this.isSuccess, this.topic, this.errorMessage});

  factory TopicResult.success(Topic? topic) =>
      TopicResult._(isSuccess: true, topic: topic);

  factory TopicResult.failure(String message) =>
      TopicResult._(isSuccess: false, errorMessage: message);
}

class TopicListResult {
  final bool isSuccess;
  final List<Topic>? topics;
  final String? errorMessage;

  TopicListResult._({required this.isSuccess, this.topics, this.errorMessage});

  factory TopicListResult.success(List<Topic> topics) =>
      TopicListResult._(isSuccess: true, topics: topics);

  factory TopicListResult.failure(String message) =>
      TopicListResult._(isSuccess: false, errorMessage: message);
}

/// The question bank's taxonomy. Topics list and create under their subject
/// but update by their own id - that's how the API is routed.
///
/// SUBJECTS -> GET   /api/subjects?isActive=true
///             POST  /api/subjects
///             PATCH /api/subjects/:id
/// TOPICS   -> GET   /api/subjects/:subjectId/topics?isActive=true
///             POST  /api/subjects/:subjectId/topics
///             PATCH /api/topics/:id
class SubjectTopicService {
  final String baseUrl;

  SubjectTopicService({this.baseUrl = ApiConstant.baseUrl});

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

  // ── Subjects ──────────────────────────────────────────────────────

  /// Pass isActive: null from the manager screen - that's where an admin goes
  /// to reactivate something, so it has to see the inactive rows too.
  Future<SubjectListResult> getSubjects({bool? isActive = true}) async {
    final adminToken = await _getToken();
    if (adminToken == null) {
      return SubjectListResult.failure('Session expired. Please log in again.');
    }

    final uri = Uri.parse('$baseUrl/subjects').replace(
      queryParameters: isActive == null ? null : {'isActive': '$isActive'},
    );

    try {
      final response = await http.get(uri, headers: _headers(adminToken)).timeout(_timeout);
      final decoded = _tryDecode(response.body);

      if (response.statusCode == 200) {
        return SubjectListResult.success(parseSubjects(decoded));
      }
      return SubjectListResult.failure(
        _messageFrom(decoded, response.statusCode, 'load subjects'),
      );
    } on http.ClientException {
      return SubjectListResult.failure('Network error. Please check your connection.');
    } on FormatException {
      return SubjectListResult.failure('Unexpected response from server.');
    } catch (e) {
      return SubjectListResult.failure('Something went wrong: $e');
    }
  }

  Future<SubjectResult> createSubject({required String name, bool isActive = true}) =>
      _writeSubject('POST', '/subjects', {'name': name, 'isActive': isActive},
          'create subject');

  /// PATCH, so only the fields passed are touched.
  Future<SubjectResult> updateSubject({
    required int subjectId,
    String? name,
    bool? isActive,
  }) =>
      _writeSubject(
        'PATCH',
        '/subjects/$subjectId',
        {
          if (name != null) 'name': name,
          if (isActive != null) 'isActive': isActive,
        },
        'update subject',
      );

  Future<SubjectResult> _writeSubject(
    String method,
    String path,
    Map<String, dynamic> body,
    String failureVerb,
  ) async {
    final adminToken = await _getToken();
    if (adminToken == null) {
      return SubjectResult.failure('Session expired. Please log in again.');
    }

    final uri = Uri.parse('$baseUrl$path');
    final headers = _headers(adminToken);
    final encoded = jsonEncode(body);

    try {
      final response = method == 'POST'
          ? await http.post(uri, headers: headers, body: encoded).timeout(_timeout)
          : await http.patch(uri, headers: headers, body: encoded).timeout(_timeout);

      final decoded = _tryDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final raw = decoded is Map ? decoded['subject'] : null;
        return SubjectResult.success(
          raw is Map<String, dynamic> ? Subject.fromJson(raw) : null,
        );
      }
      return SubjectResult.failure(_messageFrom(decoded, response.statusCode, failureVerb));
    } on http.ClientException {
      return SubjectResult.failure('Network error. Please check your connection.');
    } on FormatException {
      return SubjectResult.failure('Unexpected response from server.');
    } catch (e) {
      return SubjectResult.failure('Something went wrong: $e');
    }
  }

  // ── Topics ────────────────────────────────────────────────────────

  Future<TopicListResult> getTopics({
    required int subjectId,
    bool? isActive = true,
  }) async {
    final adminToken = await _getToken();
    if (adminToken == null) {
      return TopicListResult.failure('Session expired. Please log in again.');
    }

    final uri = Uri.parse('$baseUrl/subjects/$subjectId/topics').replace(
      queryParameters: isActive == null ? null : {'isActive': '$isActive'},
    );

    try {
      final response = await http.get(uri, headers: _headers(adminToken)).timeout(_timeout);
      final decoded = _tryDecode(response.body);

      if (response.statusCode == 200) {
        return TopicListResult.success(parseTopics(decoded));
      }
      return TopicListResult.failure(
        _messageFrom(decoded, response.statusCode, 'load topics'),
      );
    } on http.ClientException {
      return TopicListResult.failure('Network error. Please check your connection.');
    } on FormatException {
      return TopicListResult.failure('Unexpected response from server.');
    } catch (e) {
      return TopicListResult.failure('Something went wrong: $e');
    }
  }

  Future<TopicResult> createTopic({
    required int subjectId,
    required String name,
    bool isActive = true,
  }) =>
      _writeTopic('POST', '/subjects/$subjectId/topics',
          {'name': name, 'isActive': isActive}, 'create topic');

  /// Updates by topic id, not through the subject - that's the API's routing.
  Future<TopicResult> updateTopic({
    required int topicId,
    String? name,
    bool? isActive,
  }) =>
      _writeTopic(
        'PATCH',
        '/topics/$topicId',
        {
          if (name != null) 'name': name,
          if (isActive != null) 'isActive': isActive,
        },
        'update topic',
      );

  Future<TopicResult> _writeTopic(
    String method,
    String path,
    Map<String, dynamic> body,
    String failureVerb,
  ) async {
    final adminToken = await _getToken();
    if (adminToken == null) {
      return TopicResult.failure('Session expired. Please log in again.');
    }

    final uri = Uri.parse('$baseUrl$path');
    final headers = _headers(adminToken);
    final encoded = jsonEncode(body);

    try {
      final response = method == 'POST'
          ? await http.post(uri, headers: headers, body: encoded).timeout(_timeout)
          : await http.patch(uri, headers: headers, body: encoded).timeout(_timeout);

      final decoded = _tryDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final raw = decoded is Map ? decoded['topic'] : null;
        return TopicResult.success(
          raw is Map<String, dynamic> ? Topic.fromJson(raw) : null,
        );
      }
      return TopicResult.failure(_messageFrom(decoded, response.statusCode, failureVerb));
    } on http.ClientException {
      return TopicResult.failure('Network error. Please check your connection.');
    } on FormatException {
      return TopicResult.failure('Unexpected response from server.');
    } catch (e) {
      return TopicResult.failure('Something went wrong: $e');
    }
  }
}
