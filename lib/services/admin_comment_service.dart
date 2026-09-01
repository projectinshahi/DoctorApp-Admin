import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/const/api_constant.dart';
import '../core/const/local_storegae.dart';
import '../models/admin_comment_model.dart';

class CommentListResult {
  final bool isSuccess;
  final List<AdminComment> comments;

  /// The full set, independent of the active filter.
  final CommentCounts counts;

  final int page;
  final int totalPages;
  final int total;
  final String? errorMessage;

  const CommentListResult._({
    required this.isSuccess,
    this.comments = const [],
    this.counts = const CommentCounts(),
    this.page = 1,
    this.totalPages = 1,
    this.total = 0,
    this.errorMessage,
  });

  factory CommentListResult.success({
    required List<AdminComment> comments,
    required CommentCounts counts,
    int page = 1,
    int totalPages = 1,
    int total = 0,
  }) =>
      CommentListResult._(
        isSuccess: true,
        comments: comments,
        counts: counts,
        page: page,
        totalPages: totalPages,
        total: total,
      );

  factory CommentListResult.failure(String message) =>
      CommentListResult._(isSuccess: false, errorMessage: message);
}

/// Outcome of a moderation action.
///
/// [count] carries whichever number the endpoint reported - replies moved,
/// reports dismissed, replies deleted - so the toast can name it. Hiding one
/// row and silently affecting three is the surprise a moderator does not need.
class CommentActionResult {
  final bool isSuccess;
  final String message;
  final int count;

  const CommentActionResult._({
    required this.isSuccess,
    required this.message,
    this.count = 0,
  });

  factory CommentActionResult.success(String message, {int count = 0}) =>
      CommentActionResult._(isSuccess: true, message: message, count: count);

  factory CommentActionResult.failure(String message) =>
      CommentActionResult._(isSuccess: false, message: message);
}

class LessonCommentsResult {
  final bool isSuccess;
  final String message;
  final bool enabled;

  /// Comments already on the lesson. Turning a discussion off does not erase
  /// it, and the confirm dialog has to say so.
  final int existingComments;

  final String? errorMessage;

  const LessonCommentsResult._({
    required this.isSuccess,
    this.message = '',
    this.enabled = true,
    this.existingComments = 0,
    this.errorMessage,
  });

  factory LessonCommentsResult.success({
    required String message,
    required bool enabled,
    int existingComments = 0,
  }) =>
      LessonCommentsResult._(
        isSuccess: true,
        message: message,
        enabled: enabled,
        existingComments: existingComments,
      );

  factory LessonCommentsResult.failure(String message) =>
      LessonCommentsResult._(isSuccess: false, errorMessage: message);
}

/// Comment moderation.
///
/// LIST     GET    /admin/comments?status=&lessonId=&courseId=&search=&page=&limit=
/// STATUS   PATCH  /admin/comments/:id                { status }
/// DISMISS  POST   /admin/comments/:id/dismiss-reports
/// DELETE   DELETE /admin/comments/:id
/// REPLY    POST   /admin/comments/:id/reply         { body }
/// THREAD   GET    /admin/comments/:id
/// EDIT     PATCH  /admin/comments/:id/body          { body }
/// LESSON   PATCH  /admin/lessons/:lessonId/comments  { enabled }
///
/// Root-mounted, NOT /api/admin/... - the same prefix as students and
/// /admin/me.
class AdminCommentService {
  static const String _baseUrl = ApiConstant.root;
  static const Duration _timeout = Duration(seconds: 30);

  Future<String?> _token() => AdminLocalStorage.getToken();

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

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
    if (status == 404) return 'That comment no longer exists.';
    return 'Could not $verb (status $status)';
  }

  Future<CommentListResult> list({
    String status = 'reported',
    int? lessonId,
    int? courseId,
    String? search,
    int page = 1,
    int limit = 25,
  }) async {
    final token = await _token();
    if (token == null) {
      return CommentListResult.failure('Session expired. Please log in again.');
    }

    final uri = Uri.parse('$_baseUrl/admin/comments').replace(
      queryParameters: {
        // 'all' is the absence of a filter, not a value to send.
        if (status != 'all') 'status': status,
        if (lessonId != null) 'lessonId': '$lessonId',
        if (courseId != null) 'courseId': '$courseId',
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        'page': '$page',
        'limit': '$limit',
      },
    );

    try {
      final response =
          await http.get(uri, headers: _headers(token)).timeout(_timeout);
      final decoded = _tryDecode(response.body);

      if (response.statusCode == 200 && decoded is Map) {
        final rows = decoded['comments'];
        final pagination = decoded['pagination'];

        return CommentListResult.success(
          comments: rows is List
              ? rows
                  .whereType<Map<String, dynamic>>()
                  .map(AdminComment.fromJson)
                  .toList()
              : const [],
          counts: decoded['counts'] is Map<String, dynamic>
              ? CommentCounts.fromJson(
                  decoded['counts'] as Map<String, dynamic>)
              : const CommentCounts(),
          page: pagination is Map
              ? ((pagination['page'] as num?)?.toInt() ?? 1)
              : 1,
          totalPages: pagination is Map
              ? ((pagination['totalPages'] as num?)?.toInt() ?? 1)
              : 1,
          total: pagination is Map
              ? ((pagination['total'] as num?)?.toInt() ?? 0)
              : 0,
        );
      }

      return CommentListResult.failure(
          _messageFrom(decoded, response.statusCode, 'load comments'));
    } catch (e) {
      return CommentListResult.failure('Could not reach the server: $e');
    }
  }

  /// Hide or restore.
  ///
  /// Replies follow the parent both ways: hiding an abusive comment while
  /// leaving five replies quoting it achieves nothing, and restoring brings
  /// the thread back whole. Either decision also closes the open reports -
  /// hiding agrees with them, restoring overrules them - which is what keeps
  /// the queue emptying.
  Future<CommentActionResult> setStatus(int commentId, String status) async {
    final token = await _token();
    if (token == null) {
      return CommentActionResult.failure('Session expired. Please log in again.');
    }

    try {
      final response = await http
          .patch(
            Uri.parse('$_baseUrl/admin/comments/$commentId'),
            headers: _headers(token),
            body: jsonEncode({'status': status}),
          )
          .timeout(_timeout);

      final decoded = _tryDecode(response.body);

      if (response.statusCode == 200) {
        return CommentActionResult.success(
          (decoded is Map ? decoded['message'] as String? : null) ??
              (status == 'hidden' ? 'Comment hidden.' : 'Comment restored.'),
          count: decoded is Map
              ? ((decoded['affectedReplies'] as num?)?.toInt() ?? 0)
              : 0,
        );
      }

      return CommentActionResult.failure(_messageFrom(
          decoded, response.statusCode,
          status == 'hidden' ? 'hide the comment' : 'restore the comment'));
    } catch (e) {
      return CommentActionResult.failure('Could not reach the server: $e');
    }
  }

  /// "I looked, it's fine."
  ///
  /// Without this the only way out of the queue is to hide something that did
  /// not deserve it. Nothing to dismiss is a success with a count of 0, not an
  /// error.
  Future<CommentActionResult> dismissReports(int commentId) async {
    final token = await _token();
    if (token == null) {
      return CommentActionResult.failure('Session expired. Please log in again.');
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/admin/comments/$commentId/dismiss-reports'),
            headers: _headers(token),
          )
          .timeout(_timeout);

      final decoded = _tryDecode(response.body);

      if (response.statusCode == 200) {
        return CommentActionResult.success(
          (decoded is Map ? decoded['message'] as String? : null) ??
              'Reports dismissed.',
          count: decoded is Map
              ? ((decoded['dismissed'] as num?)?.toInt() ?? 0)
              : 0,
        );
      }

      return CommentActionResult.failure(
          _messageFrom(decoded, response.statusCode, 'dismiss the reports'));
    } catch (e) {
      return CommentActionResult.failure('Could not reach the server: $e');
    }
  }

  /// Permanent. No soft delete, no archive.
  ///
  /// A 404 is what a double-click produces, so it reads as "already gone"
  /// rather than as a failure the moderator has to act on.
  Future<CommentActionResult> delete(int commentId) async {
    final token = await _token();
    if (token == null) {
      return CommentActionResult.failure('Session expired. Please log in again.');
    }

    try {
      final response = await http
          .delete(
            Uri.parse('$_baseUrl/admin/comments/$commentId'),
            headers: _headers(token),
          )
          .timeout(_timeout);

      final decoded = _tryDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 204) {
        return CommentActionResult.success(
          (decoded is Map ? decoded['message'] as String? : null) ??
              'Deleted permanently.',
          count: decoded is Map
              ? ((decoded['deletedReplies'] as num?)?.toInt() ?? 0)
              : 0,
        );
      }

      if (response.statusCode == 404) {
        return CommentActionResult.success('That comment was already deleted.');
      }

      return CommentActionResult.failure(
          _messageFrom(decoded, response.statusCode, 'delete the comment'));
    } catch (e) {
      return CommentActionResult.failure('Could not reach the server: $e');
    }
  }

  /// Turn commenting on or off for a lesson.
  ///
  /// Turning a discussion off is not erasing it - new posts get a 409 and
  /// everything already there stays readable, which is why the response
  /// reports how many comments remain.
  Future<LessonCommentsResult> setLessonComments({
    required int lessonId,
    required bool enabled,
  }) async {
    final token = await _token();
    if (token == null) {
      return LessonCommentsResult.failure(
          'Session expired. Please log in again.');
    }

    try {
      final response = await http
          .patch(
            Uri.parse('$_baseUrl/admin/lessons/$lessonId/comments'),
            headers: _headers(token),
            body: jsonEncode({'enabled': enabled}),
          )
          .timeout(_timeout);

      final decoded = _tryDecode(response.body);

      if (response.statusCode == 200) {
        final lesson = decoded is Map ? decoded['lesson'] : null;
        return LessonCommentsResult.success(
          message: (decoded is Map ? decoded['message'] as String? : null) ??
              (enabled ? 'Commenting is on.' : 'Commenting is off.'),
          enabled: lesson is Map
              ? (lesson['commentsEnabled'] as bool? ?? enabled)
              : enabled,
          existingComments: decoded is Map
              ? ((decoded['existingComments'] as num?)?.toInt() ?? 0)
              : 0,
        );
      }

      return LessonCommentsResult.failure(_messageFrom(
          decoded, response.statusCode, 'change the comment setting'));
    } catch (e) {
      return LessonCommentsResult.failure('Could not reach the server: $e');
    }
  }

  /// What the sidebar badge should read.
  ///
  /// Comments arriving since the moderator last opened the screen, plus
  /// anything reported that they have not seen. A badge that only counted
  /// reports would stay dark while a student's question sat unanswered - and
  /// answering questions is most of what this screen is for.
  Future<int?> unseenCount() async {
    final seenAt = await AdminLocalStorage.getCommentsSeenAt();
    final result = await list(status: 'all', limit: 50);
    if (!result.isSuccess) return null;

    // Never opened: everything reported is what needs attention, rather than
    // a badge showing every comment ever written.
    if (seenAt == null) return result.counts.reported;

    return result.comments
        .where((c) => c.createdAt != null && c.createdAt!.isAfter(seenAt))
        .length;
  }

  /// Posts an admin reply under a comment.
  ///
  /// Not part of the documented five endpoints - this route has to exist
  /// server-side before it works, and a 404 is reported as exactly that
  /// rather than as a failed reply, so the admin knows it is a missing
  /// feature and not a lost message.
  Future<CommentActionResult> reply(int commentId, String body) async {
    final token = await _token();
    if (token == null) {
      return CommentActionResult.failure('Session expired. Please log in again.');
    }
    if (body.trim().isEmpty) {
      return CommentActionResult.failure('Write something first.');
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/admin/comments/$commentId/reply'),
            headers: _headers(token),
            body: jsonEncode({'body': body.trim()}),
          )
          .timeout(_timeout);

      final decoded = _tryDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return CommentActionResult.success(
          (decoded is Map ? decoded['message'] as String? : null) ??
              'Reply posted.',
        );
      }

      // A hidden parent: a visible reply under an invisible comment reads as
      // a reply to nothing.
      if (response.statusCode == 409) {
        return CommentActionResult.failure(
          _messageFrom(decoded, 409, 'post the reply'),
        );
      }

      return CommentActionResult.failure(
          _messageFrom(decoded, response.statusCode, 'post the reply'));
    } catch (e) {
      return CommentActionResult.failure('Could not reach the server: $e');
    }
  }

  /// The whole conversation around any comment in it.
  Future<({bool isSuccess, CommentThread? thread, String? errorMessage})>
      getThread(int commentId) async {
    final token = await _token();
    if (token == null) {
      return (
        isSuccess: false,
        thread: null,
        errorMessage: 'Session expired. Please log in again.'
      );
    }

    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/admin/comments/$commentId'),
              headers: _headers(token))
          .timeout(_timeout);
      final decoded = _tryDecode(response.body);

      if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
        return (
          isSuccess: true,
          thread: CommentThread.fromJson(decoded),
          errorMessage: null
        );
      }

      return (
        isSuccess: false,
        thread: null,
        errorMessage:
            _messageFrom(decoded, response.statusCode, 'load the thread')
      );
    } catch (e) {
      return (
        isSuccess: false,
        thread: null,
        errorMessage: 'Could not reach the server: $e'
      );
    }
  }

  /// Fixes a typo in an admin's own comment.
  ///
  /// A 403 means it was a student's comment. The button is hidden from
  /// [AdminComment.canEditBody] before it comes to that, but the message is
  /// surfaced verbatim if it does - rewriting someone's words is worse than
  /// anything they could have written.
  Future<CommentActionResult> updateBody(int commentId, String body) async {
    final token = await _token();
    if (token == null) {
      return CommentActionResult.failure('Session expired. Please log in again.');
    }
    if (body.trim().isEmpty) {
      return CommentActionResult.failure('A comment cannot be empty.');
    }

    try {
      final response = await http
          .patch(
            Uri.parse('$_baseUrl/admin/comments/$commentId/body'),
            headers: _headers(token),
            body: jsonEncode({'body': body.trim()}),
          )
          .timeout(_timeout);

      final decoded = _tryDecode(response.body);

      if (response.statusCode == 200) {
        return CommentActionResult.success(
          (decoded is Map ? decoded['message'] as String? : null) ??
              'Comment updated.',
        );
      }

      return CommentActionResult.failure(
          _messageFrom(decoded, response.statusCode, 'edit the comment'));
    } catch (e) {
      return CommentActionResult.failure('Could not reach the server: $e');
    }
  }
}
