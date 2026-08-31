import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/const/api_constant.dart';
import '../core/const/local_storegae.dart';
import '../models/admin_test_model.dart';

/// Result of a CSV upload.
///
/// A rejected import returns *every* problem at once, not just the first -
/// fixing a 200-row file one error per attempt is not a workable flow - so
/// [issues] carries the whole list either way. Warnings ride along even on
/// success, because they did not block the import.
class TestUploadResult {
  final bool isSuccess;

  /// Rows the server actually stored.
  final int imported;

  /// The server's own sentence, e.g. "Imported 1 question(s). The test is not
  /// published yet." Shown verbatim rather than reworded.
  final String? message;

  final List<TestUploadIssue> issues;
  final String? errorMessage;

  const TestUploadResult._({
    required this.isSuccess,
    this.imported = 0,
    this.message,
    this.issues = const [],
    this.errorMessage,
  });

  factory TestUploadResult.success({
    required int imported,
    String? message,
    List<TestUploadIssue> issues = const [],
  }) =>
      TestUploadResult._(
        isSuccess: true,
        imported: imported,
        message: message,
        issues: issues,
      );

  factory TestUploadResult.failure(
    String message,
    List<TestUploadIssue> issues,
  ) =>
      TestUploadResult._(
        isSuccess: false,
        errorMessage: message,
        issues: issues,
      );

  List<TestUploadIssue> get blocking =>
      issues.where((i) => !i.isWarning).toList();

  List<TestUploadIssue> get warnings =>
      issues.where((i) => i.isWarning).toList();

  bool get hasWarnings => warnings.isNotEmpty;
}

class TestDeleteResult {
  final bool isSuccess;
  final String message;

  /// Present on a 409: how many students have already sat the paper.
  final int? attemptCount;

  const TestDeleteResult._({
    required this.isSuccess,
    required this.message,
    this.attemptCount,
  });

  factory TestDeleteResult.success(String message) =>
      TestDeleteResult._(isSuccess: true, message: message);

  factory TestDeleteResult.failure(String message, {int? attemptCount}) =>
      TestDeleteResult._(
          isSuccess: false, message: message, attemptCount: attemptCount);
}

class TestResult {
  final bool isSuccess;
  final AdminTest? test;
  final String? errorMessage;

  const TestResult._({required this.isSuccess, this.test, this.errorMessage});

  factory TestResult.success(AdminTest? test) =>
      TestResult._(isSuccess: true, test: test);

  factory TestResult.failure(String message) =>
      TestResult._(isSuccess: false, errorMessage: message);
}

class TestListResult {
  final bool isSuccess;
  final List<AdminTest> tests;
  final String? errorMessage;

  const TestListResult._({
    required this.isSuccess,
    this.tests = const [],
    this.errorMessage,
  });

  factory TestListResult.success(List<AdminTest> tests) =>
      TestListResult._(isSuccess: true, tests: tests);

  factory TestListResult.failure(String message) =>
      TestListResult._(isSuccess: false, errorMessage: message);
}

/// The Test admin API.
///
/// LIST     GET    /api/admin/tests?courseId=&courseTypeId=
/// CREATE   POST   /api/admin/courses/:courseId/tests   (courseTypeId in body)
/// UPLOAD   POST   /api/admin/tests/:id/questions/upload   (multipart, field "file")
/// PREVIEW  GET    /api/admin/tests/:id/preview
/// PUBLISH  POST   /api/admin/tests/:id/publish
/// UNPUB    POST   /api/admin/tests/:id/unpublish
/// CLEAR    DELETE /api/admin/tests/:id/questions          (also unpublishes)
/// DELETE   DELETE /api/admin/tests/:id                   (409 once attempted)
class AdminTestService {
  static const String _baseUrl = ApiConstant.baseUrl;
  static const Duration _timeout = Duration(seconds: 30);

  /// Uploads carry a whole file, so they get longer than the rest.
  static const Duration _uploadTimeout = Duration(seconds: 90);

  Future<String?> _token() => AdminLocalStorage.getToken();

  Map<String, String> _headers(String token, {bool json = true}) => {
        'Authorization': 'Bearer $token',
        if (json) 'Content-Type': 'application/json',
      };

  /// Decodes only if there is something to decode - a server missing a route
  /// answers with an HTML page, and the status code is more useful than a
  /// parse failure.
  dynamic _tryDecode(String body) {
    if (body.trim().isEmpty) return null;
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  String _messageFrom(dynamic decoded, int status, String verb) {
    if (status == 401) return 'Session expired. Please log in again.';
    if (decoded is Map) {
      final error = decoded['error'];
      if (error is Map && error['message'] != null) return '${error['message']}';
      if (error is String) return error;
      if (decoded['message'] != null) return '${decoded['message']}';
    }
    if (status == 404) {
      return 'Failed to $verb - the server does not have this endpoint (404).';
    }
    return 'Failed to $verb (status $status)';
  }

  List<TestUploadIssue> _issuesFrom(dynamic decoded) {
    if (decoded is! Map) return const [];
    final raw = decoded['errors'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(TestUploadIssue.fromJson)
        .toList();
  }

  List<AdminTest> _testsFrom(dynamic decoded) {
    final raw = decoded is Map
        ? (decoded['tests'] ?? decoded['data'] ?? decoded['items'])
        : decoded;
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().map(AdminTest.fromJson).toList();
  }

  AdminTest? _testFrom(dynamic decoded) {
    if (decoded is! Map) return null;
    final raw = decoded['test'] ?? decoded['data'] ?? decoded;
    return raw is Map<String, dynamic> ? AdminTest.fromJson(raw) : null;
  }

  Future<TestListResult> listTests({int? courseId, int? courseTypeId}) async {
    final token = await _token();
    if (token == null) return TestListResult.failure('Session expired. Please log in again.');

    final uri = Uri.parse('$_baseUrl/admin/tests').replace(
      queryParameters: {
        if (courseId != null) 'courseId': '$courseId',
        if (courseTypeId != null) 'courseTypeId': '$courseTypeId',
      },
    );

    try {
      final response = await http.get(uri, headers: _headers(token)).timeout(_timeout);
      final decoded = _tryDecode(response.body);

      if (response.statusCode == 200) {
        return TestListResult.success(_testsFrom(decoded));
      }
      return TestListResult.failure(
        _messageFrom(decoded, response.statusCode, 'load tests'),
      );
    } catch (e) {
      return TestListResult.failure('Could not reach the server: $e');
    }
  }

  /// Step 1 of the wizard. Creates the shell only - no questions yet.
  Future<TestResult> createTest({
    required int courseId,
    required AdminTest draft,
  }) async {
    final token = await _token();
    if (token == null) return TestResult.failure('Session expired. Please log in again.');

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/admin/courses/$courseId/tests'),
            headers: _headers(token),
            body: jsonEncode(draft.toCreatePayload()),
          )
          .timeout(_timeout);

      final decoded = _tryDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return TestResult.success(_testFrom(decoded));
      }
      return TestResult.failure(
        _messageFrom(decoded, response.statusCode, 'create the test'),
      );
    } catch (e) {
      return TestResult.failure('Could not reach the server: $e');
    }
  }

  /// Step 2. Uploading never publishes - a bad import must not reach students
  /// before a human has looked at it.
  ///
  /// Sends bytes rather than a path: on web there is no file path to read.
  Future<TestUploadResult> uploadQuestions({
    required int testId,
    required Uint8List bytes,
    required String filename,
  }) async {
    final token = await _token();
    if (token == null) {
      return TestUploadResult.failure('Session expired. Please log in again.', const []);
    }

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/admin/tests/$testId/questions/upload'),
      )
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));

      final streamed = await request.send().timeout(_uploadTimeout);
      final response = await http.Response.fromStream(streamed);
      final decoded = _tryDecode(response.body);
      final issues = _issuesFrom(decoded);

      // Success is the status code and the presence of `message` rather than
      // `error` - NEVER errors.length. A 200 carrying warnings did import the
      // file; reading a populated errors array as failure rejects a good
      // upload and tells the admin nothing was saved when it was.
      final isOk = (response.statusCode == 200 || response.statusCode == 201) &&
          !(decoded is Map && decoded['error'] != null);

      if (isOk) {
        final imported = decoded is Map
            ? (decoded['validRows'] ??
                decoded['imported'] ??
                decoded['questionCount'] ??
                0) as num
            : 0;
        return TestUploadResult.success(
          imported: imported.toInt(),
          message: decoded is Map ? decoded['message'] as String? : null,
          // Every issue is kept, not just the warnings: a 200 that still
          // reports a non-warning row is something the admin has to see.
          issues: issues,
        );
      }

      return TestUploadResult.failure(
        _messageFrom(decoded, response.statusCode, 'upload the questions'),
        issues,
      );
    } catch (e) {
      return TestUploadResult.failure('Could not reach the server: $e', const []);
    }
  }

  /// Step 3. The paper exactly as a student would sit it, plus the answer key.
  Future<({bool isSuccess, TestPreview? preview, String? errorMessage})> preview(
      int testId) async {
    final token = await _token();
    if (token == null) {
      return (isSuccess: false, preview: null, errorMessage: 'Session expired. Please log in again.');
    }

    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/admin/tests/$testId/preview'), headers: _headers(token))
          .timeout(_timeout);
      final decoded = _tryDecode(response.body);

      if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
        return (isSuccess: true, preview: TestPreview.fromJson(decoded), errorMessage: null);
      }
      return (
        isSuccess: false,
        preview: null,
        errorMessage: _messageFrom(decoded, response.statusCode, 'load the preview'),
      );
    } catch (e) {
      return (isSuccess: false, preview: null, errorMessage: 'Could not reach the server: $e');
    }
  }

  Future<TestResult> publish(int testId) => _post(testId, 'publish', 'publish the test');

  Future<TestResult> unpublish(int testId) =>
      _post(testId, 'unpublish', 'unpublish the test');

  Future<TestResult> _post(int testId, String action, String verb) async {
    final token = await _token();
    if (token == null) return TestResult.failure('Session expired. Please log in again.');

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/admin/tests/$testId/$action'),
            headers: _headers(token),
          )
          .timeout(_timeout);

      final decoded = _tryDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return TestResult.success(_testFrom(decoded));
      }
      return TestResult.failure(_messageFrom(decoded, response.statusCode, verb));
    } catch (e) {
      return TestResult.failure('Could not reach the server: $e');
    }
  }

  /// Removes every question AND unpublishes the test. The caller must have
  /// confirmed both consequences first - a published test with no questions
  /// would be a broken row in the student's list.
  Future<TestResult> clearQuestions(int testId) async {
    final token = await _token();
    if (token == null) return TestResult.failure('Session expired. Please log in again.');

    try {
      final response = await http
          .delete(
            Uri.parse('$_baseUrl/admin/tests/$testId/questions'),
            headers: _headers(token),
          )
          .timeout(_timeout);

      final decoded = _tryDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 204) {
        return TestResult.success(_testFrom(decoded));
      }
      return TestResult.failure(
        _messageFrom(decoded, response.statusCode, 'clear the questions'),
      );
    } catch (e) {
      return TestResult.failure('Could not reach the server: $e');
    }
  }

  /// Deletes the test outright.
  ///
  /// Questions, images AND attempts cascade, so the server refuses with 409
  /// once anyone has sat the paper. That refusal is surfaced verbatim - it
  /// tells the admin to unpublish instead, which is the reversible action.
  Future<TestDeleteResult> deleteTest(int testId) async {
    final token = await _token();
    if (token == null) {
      return TestDeleteResult.failure('Session expired. Please log in again.');
    }

    try {
      final response = await http
          .delete(
            Uri.parse('$_baseUrl/admin/tests/$testId'),
            headers: _headers(token),
          )
          .timeout(_timeout);

      final decoded = _tryDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 204) {
        final message = decoded is Map ? decoded['message'] as String? : null;
        return TestDeleteResult.success(message ?? 'Test deleted.');
      }

      return TestDeleteResult.failure(
        _messageFrom(decoded, response.statusCode, 'delete the test'),
        attemptCount:
            decoded is Map ? (decoded['attemptCount'] as num?)?.toInt() : null,
      );
    } catch (e) {
      return TestDeleteResult.failure('Could not reach the server: $e');
    }
  }

}
