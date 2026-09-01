import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/const/api_constant.dart';
import '../core/const/local_storegae.dart';
import '../models/admin_test_model.dart';
import '../models/test_results_model.dart';

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

/// Images upload with partial success: some files land, others are named in
/// `errors`. That is normal, not a failure, so both halves come back.
class TestImageResult {
  final bool isSuccess;

  /// Hosted URLs, in upload order. Previews render from these, never from the
  /// local bytes - a local preview would show a file the server may not hold.
  final List<String> urls;

  /// Files the server refused, by name.
  final List<TestUploadIssue> failures;

  final String? errorMessage;

  const TestImageResult._({
    required this.isSuccess,
    this.urls = const [],
    this.failures = const [],
    this.errorMessage,
  });

  factory TestImageResult.success(
    List<String> urls, {
    List<TestUploadIssue> failures = const [],
  }) =>
      TestImageResult._(isSuccess: true, urls: urls, failures: failures);

  factory TestImageResult.failure(String message) =>
      TestImageResult._(isSuccess: false, errorMessage: message);

  bool get isPartial => urls.isNotEmpty && failures.isNotEmpty;
}

class TestAttemptListResult {
  final bool isSuccess;
  final List<TestAttempt> attempts;
  final String? errorMessage;

  const TestAttemptListResult._({
    required this.isSuccess,
    this.attempts = const [],
    this.errorMessage,
  });

  factory TestAttemptListResult.success(List<TestAttempt> attempts) =>
      TestAttemptListResult._(isSuccess: true, attempts: attempts);

  factory TestAttemptListResult.failure(String message) =>
      TestAttemptListResult._(isSuccess: false, errorMessage: message);
}

class LeaderboardResult {
  final bool isSuccess;
  final List<LeaderboardRow> rows;
  final LeaderboardStats stats;
  final String? errorMessage;

  const LeaderboardResult._({
    required this.isSuccess,
    this.rows = const [],
    this.stats = const LeaderboardStats(),
    this.errorMessage,
  });

  factory LeaderboardResult.success(
    List<LeaderboardRow> rows, {
    LeaderboardStats stats = const LeaderboardStats(),
  }) =>
      LeaderboardResult._(isSuccess: true, rows: rows, stats: stats);

  factory LeaderboardResult.failure(String message) =>
      LeaderboardResult._(isSuccess: false, errorMessage: message);
}

class InProgressResult {
  final bool isSuccess;

  /// Someone is writing.
  final List<InProgressAttempt> live;

  /// Out of time but not yet closed by the server - they walked away.
  final List<InProgressAttempt> expired;

  /// The server's own counts, kept rather than recomputed from the page: the
  /// list is paginated, so counting rows would report only this page.
  final int liveCount;
  final int expiredCount;

  final int page;
  final int totalPages;

  final String? errorMessage;

  const InProgressResult._({
    required this.isSuccess,
    this.live = const [],
    this.expired = const [],
    this.liveCount = 0,
    this.expiredCount = 0,
    this.page = 1,
    this.totalPages = 1,
    this.errorMessage,
  });

  factory InProgressResult.success(
    List<InProgressAttempt> all, {
    int? liveCount,
    int? expiredCount,
    int page = 1,
    int totalPages = 1,
  }) {
    final live = all.where((a) => !a.expired).toList();
    final expired = all.where((a) => a.expired).toList();
    return InProgressResult._(
      isSuccess: true,
      live: live,
      expired: expired,
      liveCount: liveCount ?? live.length,
      expiredCount: expiredCount ?? expired.length,
      page: page,
      totalPages: totalPages,
    );
  }

  factory InProgressResult.failure(String message) =>
      InProgressResult._(isSuccess: false, errorMessage: message);
}

class TestDeleteResult {
  final bool isSuccess;
  final String message;

  /// Present on a 409: how many students have already sat the paper.
  final int? attemptCount;

  /// How many of those attempts were actually submitted.
  final int? submittedCount;

  /// The server saying a forced delete is possible. A 409 without it is a
  /// refusal, not a confirmation step.
  final bool canForce;

  final int? deletedAttempts;
  final int? deletedAnswers;

  const TestDeleteResult._({
    required this.isSuccess,
    required this.message,
    this.attemptCount,
    this.submittedCount,
    this.canForce = false,
    this.deletedAttempts,
    this.deletedAnswers,
  });

  factory TestDeleteResult.success(
    String message, {
    int? deletedAttempts,
    int? deletedAnswers,
  }) =>
      TestDeleteResult._(
        isSuccess: true,
        message: message,
        deletedAttempts: deletedAttempts,
        deletedAnswers: deletedAnswers,
      );

  factory TestDeleteResult.failure(
    String message, {
    int? attemptCount,
    int? submittedCount,
    bool canForce = false,
  }) =>
      TestDeleteResult._(
        isSuccess: false,
        message: message,
        attemptCount: attemptCount,
        submittedCount: submittedCount,
        canForce: canForce,
      );

  /// A 409 that names a way forward is the confirmation step, not an error.
  bool get needsConfirmation => !isSuccess && canForce && (attemptCount ?? 0) > 0;
}

class TestResult {
  final bool isSuccess;
  final AdminTest? test;
  final String? errorMessage;

  /// The server dropped a published test back to draft because of this edit.
  /// A live paper going dark unnoticed is a support ticket, so it is surfaced.
  final bool unpublished;

  /// Live counters returned by the question writes, so the "97 of 100" figure
  /// updates without a refetch.
  final int? questionCount;
  final bool? readyToPublish;

  /// Field-level problems from a 400, e.g. "Option B needs text or an image".
  final List<TestUploadIssue> problems;

  /// Fields the server refused to change because students have started.
  final List<String> lockedFields;

  final int? attemptCount;

  const TestResult._({
    required this.isSuccess,
    this.test,
    this.errorMessage,
    this.unpublished = false,
    this.questionCount,
    this.readyToPublish,
    this.problems = const [],
    this.lockedFields = const [],
    this.attemptCount,
  });

  factory TestResult.success(
    AdminTest? test, {
    bool unpublished = false,
    int? questionCount,
    bool? readyToPublish,
  }) =>
      TestResult._(
        isSuccess: true,
        test: test,
        unpublished: unpublished,
        questionCount: questionCount,
        readyToPublish: readyToPublish,
      );

  factory TestResult.failure(
    String message, {
    List<TestUploadIssue> problems = const [],
    List<String> lockedFields = const [],
    int? attemptCount,
  }) =>
      TestResult._(
        isSuccess: false,
        errorMessage: message,
        problems: problems,
        lockedFields: lockedFields,
        attemptCount: attemptCount,
      );
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
/// UPDATE   PATCH  /api/admin/tests/:id
/// IMAGES   POST   /api/admin/tests/:id/images            (multipart, "images")
/// Q-ADD    POST   /api/admin/tests/:id/questions
/// Q-EDIT   PATCH  /api/admin/tests/:id/questions/:qid
/// Q-DEL    DELETE /api/admin/tests/:id/questions/:qid
/// ATTEMPTS GET    /api/admin/tests/:id/attempts
/// BOARD    GET    /api/admin/tests/:id/leaderboard
/// LIVE     GET    /api/admin/test-attempts/in-progress
/// DELETE   DELETE /api/admin/tests/:id[?deleteAttempts=true]
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

  /// Field-level complaints from a 400, e.g. "Option B needs text or an
  /// image". Rendered under the field rather than as a page banner.
  List<TestUploadIssue> _problemsFrom(dynamic decoded) {
    if (decoded is! Map) return const [];
    final raw = decoded['problems'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map((json) => TestUploadIssue(
              row: 0,
              field: (json['field'] ?? '') as String,
              message: (json['message'] ?? '') as String,
            ))
        .toList();
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

  Future<TestResult> publish(int testId) =>
      _setPublished(testId, true, 'publish the test');

  /// Unpublish is the same endpoint with the flag flipped - it is the
  /// reversible action, and the one a delete dialog offers first.
  Future<TestResult> unpublish(int testId) =>
      _setPublished(testId, false, 'unpublish the test');

  Future<TestResult> _setPublished(int testId, bool isPublished, String verb) =>
      _post(testId, 'publish', verb, body: {'isPublished': isPublished});

  Future<TestResult> _post(
    int testId,
    String action,
    String verb, {
    Map<String, dynamic>? body,
  }) async {
    final token = await _token();
    if (token == null) return TestResult.failure('Session expired. Please log in again.');

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/admin/tests/$testId/$action'),
            headers: _headers(token),
            body: body == null ? null : jsonEncode(body),
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
  Future<TestDeleteResult> deleteTest(
    int testId, {
    /// Second step of a two-step delete. Without it the server refuses (409)
    /// once anyone has sat the paper; with it their results go too. It is a
    /// separate, deliberate decision and never defaults to true.
    bool deleteAttempts = false,
  }) async {
    final token = await _token();
    if (token == null) {
      return TestDeleteResult.failure('Session expired. Please log in again.');
    }

    try {
      final response = await http
          .delete(
            Uri.parse('$_baseUrl/admin/tests/$testId').replace(
              queryParameters:
                  deleteAttempts ? {'deleteAttempts': 'true'} : null,
            ),
            headers: _headers(token),
          )
          .timeout(_timeout);

      final decoded = _tryDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 204) {
        final message = decoded is Map ? decoded['message'] as String? : null;
        return TestDeleteResult.success(
          message ?? 'Test deleted.',
          deletedAttempts: decoded is Map
              ? (decoded['deletedAttempts'] as num?)?.toInt()
              : null,
          deletedAnswers: decoded is Map
              ? (decoded['deletedAnswers'] as num?)?.toInt()
              : null,
        );
      }

      return TestDeleteResult.failure(
        _messageFrom(decoded, response.statusCode, 'delete the test'),
        attemptCount:
            decoded is Map ? (decoded['attemptCount'] as num?)?.toInt() : null,
        submittedCount:
            decoded is Map ? (decoded['submittedCount'] as num?)?.toInt() : null,
        canForce: decoded is Map && (decoded['canForce'] as bool? ?? false),
      );
    } catch (e) {
      return TestDeleteResult.failure('Could not reach the server: $e');
    }
  }


  /// Edits the test itself.
  ///
  /// The payload is built by [AdminTest.toUpdatePayload], which drops the
  /// frozen fields, so a locked paper cannot be sent a change it will reject.
  Future<TestResult> updateTest(AdminTest test) async {
    final token = await _token();
    if (token == null) {
      return TestResult.failure('Session expired. Please log in again.');
    }

    try {
      final response = await http
          .patch(
            Uri.parse('$_baseUrl/admin/tests/${test.id}'),
            headers: _headers(token),
            body: jsonEncode(test.toUpdatePayload()),
          )
          .timeout(_timeout);

      final decoded = _tryDecode(response.body);
      if (response.statusCode == 200) {
        return TestResult.success(
          _testFrom(decoded),
          unpublished: decoded is Map && (decoded['unpublished'] as bool? ?? false),
        );
      }
      return TestResult.failure(
        _messageFrom(decoded, response.statusCode, 'save the test'),
        problems: _problemsFrom(decoded),
        lockedFields: decoded is Map && decoded['lockedFields'] is List
            ? (decoded['lockedFields'] as List).map((e) => '$e').toList()
            : const [],
        attemptCount:
            decoded is Map ? (decoded['attemptCount'] as num?)?.toInt() : null,
      );
    } catch (e) {
      return TestResult.failure('Could not reach the server: $e');
    }
  }

  /// Uploads question images.
  ///
  /// These go up BEFORE the CSV, because a CSV row carries an image URL, not
  /// the file - the URL has to exist before the row referencing it is
  /// imported.
  ///
  /// Partial success is normal: some files land while others are refused, and
  /// both halves are returned rather than the whole batch being called a
  /// failure.
  ///
  /// SVG is accepted. It is only safe because the host serves it from a
  /// different origin than this app, so a script inside one has nothing here
  /// to reach, and because flutter_svg does not execute script. Render from
  /// the returned URL - never inline the file into the page.
  Future<TestImageResult> uploadImages({
    required int testId,
    required List<({Uint8List bytes, String filename})> files,
  }) async {
    final token = await _token();
    if (token == null) {
      return TestImageResult.failure('Session expired. Please log in again.');
    }
    if (files.isEmpty) return TestImageResult.success(const []);

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/admin/tests/$testId/images'),
      )..headers['Authorization'] = 'Bearer $token';

      for (final file in files) {
        request.files.add(http.MultipartFile.fromBytes(
          'images',
          file.bytes,
          filename: file.filename,
        ));
      }

      final streamed = await request.send().timeout(_uploadTimeout);
      final response = await http.Response.fromStream(streamed);
      final decoded = _tryDecode(response.body);

      final isOk = (response.statusCode == 200 || response.statusCode == 201) &&
          !(decoded is Map && decoded['error'] != null);

      if (isOk) {
        return TestImageResult.success(
          _urlsFrom(decoded),
          failures: _issuesFrom(decoded),
        );
      }
      return TestImageResult.failure(
          _messageFrom(decoded, response.statusCode, 'upload the images'));
    } catch (e) {
      return TestImageResult.failure('Could not reach the server: $e');
    }
  }

  /// Pulls hosted URLs out of whatever shape the images response takes.
  List<String> _urlsFrom(dynamic decoded) {
    final raw = decoded is Map
        ? (decoded['images'] ?? decoded['urls'] ?? decoded['uploaded'] ??
            decoded['data'])
        : decoded;
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is String)
          item
        else if (item is Map)
          '${item['url'] ?? item['secureUrl'] ?? item['secure_url'] ?? ''}',
    ].where((u) => u.isNotEmpty).toList();
  }

  // ── One question at a time ───────────────────────────────────────

  Future<TestResult> createQuestion(int testId, Map<String, dynamic> body) =>
      _questionWrite('POST', '$_baseUrl/admin/tests/$testId/questions', body,
          'add the question');

  Future<TestResult> updateQuestion(
          int testId, int questionId, Map<String, dynamic> body) =>
      _questionWrite('PATCH',
          '$_baseUrl/admin/tests/$testId/questions/$questionId', body,
          'save the question');

  Future<TestResult> deleteQuestion(int testId, int questionId) =>
      _questionWrite('DELETE',
          '$_baseUrl/admin/tests/$testId/questions/$questionId', null,
          'delete the question');

  Future<TestResult> _questionWrite(
    String method,
    String url,
    Map<String, dynamic>? body,
    String verb,
  ) async {
    final token = await _token();
    if (token == null) {
      return TestResult.failure('Session expired. Please log in again.');
    }

    try {
      final uri = Uri.parse(url);
      final headers = _headers(token);
      final encoded = body == null ? null : jsonEncode(body);

      final response = await switch (method) {
        'POST' => http.post(uri, headers: headers, body: encoded),
        'PATCH' => http.patch(uri, headers: headers, body: encoded),
        _ => http.delete(uri, headers: headers),
      }
          .timeout(_timeout);

      final decoded = _tryDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return TestResult.success(
          null,
          questionCount:
              decoded is Map ? (decoded['questionCount'] as num?)?.toInt() : null,
          readyToPublish:
              decoded is Map ? decoded['readyToPublish'] as bool? : null,
        );
      }
      return TestResult.failure(
        _messageFrom(decoded, response.statusCode, verb),
        problems: _problemsFrom(decoded),
      );
    } catch (e) {
      return TestResult.failure('Could not reach the server: $e');
    }
  }

  // ── Results ──────────────────────────────────────────────────────

  /// Every attempt, retakes included. Not the leaderboard.
  Future<TestAttemptListResult> getAttempts(
    int testId, {
    int page = 1,
    int limit = 50,
    String? status,
  }) async {
    final query = [
      'page=$page',
      'limit=$limit',
      if (status != null) 'status=$status',
    ].join('&');

    final decoded =
        await _get('/admin/tests/$testId/attempts?$query', 'load attempts');
    if (decoded.error != null) {
      return TestAttemptListResult.failure(decoded.error!);
    }
    return TestAttemptListResult.success(
      _listOf(decoded.body, const ['attempts', 'data', 'items'],
          TestAttempt.fromJson),
    );
  }

  /// One row per student - their best attempt only.
  Future<LeaderboardResult> getLeaderboard(int testId, {int limit = 100}) async {
    final decoded = await _get(
        '/admin/tests/$testId/leaderboard?limit=$limit', 'load the leaderboard');
    if (decoded.error != null) return LeaderboardResult.failure(decoded.error!);

    final raw =
        _rawList(decoded.body, const ['leaderboard', 'entries', 'rows', 'data']);
    final stats = decoded.body is Map ? decoded.body['stats'] : null;

    return LeaderboardResult.success(
      [
        // The index is only a last resort. Ties share a rank and the next one
        // skips, so numbering rows would disagree with what students see.
        for (var i = 0; i < raw.length; i++)
          LeaderboardRow.fromJson(raw[i], i + 1),
      ],
      stats: stats is Map<String, dynamic>
          ? LeaderboardStats.fromJson(stats)
          : const LeaderboardStats(),
    );
  }

  /// Live invigilation, across every test.
  ///
  /// The result splits live from expired. An attempt that ran out of time is
  /// only closed when the student next touches it, so counting those as live
  /// would report a room full of candidates who left hours ago.
  Future<InProgressResult> getInProgress({
    int? courseId,
    int? testId,
    int page = 1,
    int limit = 50,
  }) async {
    final query = [
      if (courseId != null) 'courseId=$courseId',
      if (testId != null) 'testId=$testId',
      'page=$page',
      'limit=$limit',
    ].join('&');

    final decoded = await _get(
        '/admin/test-attempts/in-progress?$query', 'load live attempts');
    if (decoded.error != null) return InProgressResult.failure(decoded.error!);

    final body = decoded.body;
    final pagination = body is Map ? body['pagination'] : null;

    return InProgressResult.success(
      _listOf(body, const ['attempts', 'data', 'items'],
          InProgressAttempt.fromJson),
      liveCount: body is Map ? (body['liveCount'] as num?)?.toInt() : null,
      expiredCount: body is Map ? (body['expiredCount'] as num?)?.toInt() : null,
      page: pagination is Map ? ((pagination['page'] as num?)?.toInt() ?? 1) : 1,
      totalPages: pagination is Map
          ? ((pagination['totalPages'] as num?)?.toInt() ?? 1)
          : 1,
    );
  }

  Future<({dynamic body, String? error})> _get(String path, String verb) async {
    final token = await _token();
    if (token == null) {
      return (body: null, error: 'Session expired. Please log in again.');
    }

    try {
      final response = await http
          .get(Uri.parse('$_baseUrl$path'), headers: _headers(token))
          .timeout(_timeout);
      final decoded = _tryDecode(response.body);

      if (response.statusCode == 200) return (body: decoded, error: null);
      return (
        body: null,
        error: _messageFrom(decoded, response.statusCode, verb),
      );
    } catch (e) {
      return (body: null, error: 'Could not reach the server: $e');
    }
  }

  List<Map<String, dynamic>> _rawList(dynamic decoded, List<String> keys) {
    final raw = decoded is Map
        ? keys.map((k) => decoded[k]).firstWhere((v) => v is List,
            orElse: () => null)
        : decoded;
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  List<T> _listOf<T>(
    dynamic decoded,
    List<String> keys,
    T Function(Map<String, dynamic>) parse,
  ) =>
      _rawList(decoded, keys).map(parse).toList();
}
