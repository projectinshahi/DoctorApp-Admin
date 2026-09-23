import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/const/api_constant.dart';
import '../core/const/local_storegae.dart';
import '../models/rapid_recall_model.dart';

class RecallResult {
  final bool isSuccess;
  final RapidRecall? recall;
  final String? errorMessage;

  const RecallResult._({required this.isSuccess, this.recall, this.errorMessage});

  factory RecallResult.success(RapidRecall? recall) =>
      RecallResult._(isSuccess: true, recall: recall);

  factory RecallResult.failure(String message) =>
      RecallResult._(isSuccess: false, errorMessage: message);
}

class RecallListResult {
  final bool isSuccess;
  final List<RapidRecall> recalls;
  final String? errorMessage;

  const RecallListResult._({
    required this.isSuccess,
    this.recalls = const [],
    this.errorMessage,
  });

  factory RecallListResult.success(List<RapidRecall> recalls) =>
      RecallListResult._(isSuccess: true, recalls: recalls);

  factory RecallListResult.failure(String message) =>
      RecallListResult._(isSuccess: false, errorMessage: message);
}

/// The outcome of PUT /cards and of DELETE, both of which report a count the
/// UI quotes back rather than counting for itself.
class RecallCountResult {
  final bool isSuccess;
  final int count;
  final List<RapidRecallCard> cards;
  final String? errorMessage;

  const RecallCountResult._({
    required this.isSuccess,
    this.count = 0,
    this.cards = const [],
    this.errorMessage,
  });

  factory RecallCountResult.success(int count, {List<RapidRecallCard> cards = const []}) =>
      RecallCountResult._(isSuccess: true, count: count, cards: cards);

  factory RecallCountResult.failure(String message) =>
      RecallCountResult._(isSuccess: false, errorMessage: message);
}

/// Rapid Recall decks.
///
/// LIST    GET    /api/admin/rapid-recalls?courseId=&…&status=&search=
/// ONE     GET    /api/admin/rapid-recalls/:id          (includes cards)
/// CREATE  POST   /api/admin/rapid-recalls
/// UPDATE  PATCH  /api/admin/rapid-recalls/:id
/// CARDS   PUT    /api/admin/rapid-recalls/:id/cards    (the whole deck)
/// DELETE  DELETE /api/admin/rapid-recalls/:id
///
/// The scope chain is validated server-side on every write: a course type from
/// a different course is refused rather than saved as a deck nobody can see.
/// Those arrive as plain 400s and are shown verbatim.
class RapidRecallService {
  static const String _baseUrl = ApiConstant.baseUrl;
  static const Duration _timeout = Duration(seconds: 30);

  Future<String?> _token() => AdminLocalStorage.getToken();

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  /// Guards against an HTML error page, which a cold start on the host does
  /// return - decoding one unguarded throws a FormatException the screens
  /// would render as a crash rather than an error.
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
      if (decoded['message'] != null) return '${decoded['message']}';
    }
    return 'Could not $verb (status $status)';
  }

  RapidRecall? _recallFrom(dynamic decoded) {
    if (decoded is! Map) return null;
    final raw = decoded['rapidRecall'] ?? decoded['recall'] ?? decoded['data'];
    if (raw is Map<String, dynamic>) return RapidRecall.fromJson(raw);
    if (decoded['id'] != null) {
      return RapidRecall.fromJson(decoded.cast<String, dynamic>());
    }
    return null;
  }

  /// Every filter is optional, matching the funnel: a deck narrowed only to a
  /// course is as valid as one pinned to a lesson.
  ///
  /// [chapterId] is the subject: chapters are what this form calls subjects.
  Future<RecallListResult> list({
    int? courseId,
    int? courseTypeId,
    int? chapterId,
    int? lessonId,
    String? status,
    String? search,
  }) async {
    final token = await _token();
    if (token == null) {
      return RecallListResult.failure('Session expired. Please log in again.');
    }

    final query = <String, String>{
      if (courseId != null) 'courseId': '$courseId',
      if (courseTypeId != null) 'courseTypeId': '$courseTypeId',
      if (chapterId != null) 'chapterId': '$chapterId',
      if (lessonId != null) 'lessonId': '$lessonId',
      if (status != null && status.isNotEmpty) 'status': status,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    };

    try {
      final uri = Uri.parse('$_baseUrl/admin/rapid-recalls')
          .replace(queryParameters: query.isEmpty ? null : query);
      final response =
          await http.get(uri, headers: _headers(token)).timeout(_timeout);
      final decoded = _tryDecode(response.body);

      if (response.statusCode == 200) {
        final raw = decoded is Map
            ? (decoded['rapidRecalls'] ?? decoded['recalls'] ?? decoded['data'])
            : decoded;
        if (raw is! List) return RecallListResult.success(const []);
        return RecallListResult.success(raw
            .whereType<Map<String, dynamic>>()
            .map(RapidRecall.fromJson)
            .toList());
      }
      return RecallListResult.failure(
          _messageFrom(decoded, response.statusCode, 'load the decks'));
    } catch (e) {
      return RecallListResult.failure('Could not reach the server: $e');
    }
  }

  /// The only call that returns the cards.
  Future<RecallResult> getOne(int id) async {
    final token = await _token();
    if (token == null) {
      return RecallResult.failure('Session expired. Please log in again.');
    }

    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/admin/rapid-recalls/$id'),
              headers: _headers(token))
          .timeout(_timeout);
      final decoded = _tryDecode(response.body);

      if (response.statusCode == 200) {
        final recall = _recallFrom(decoded);
        if (recall == null) {
          return RecallResult.failure('The server did not return the deck.');
        }
        return RecallResult.success(recall);
      }
      return RecallResult.failure(
          _messageFrom(decoded, response.statusCode, 'load the deck'));
    } catch (e) {
      return RecallResult.failure('Could not reach the server: $e');
    }
  }

  Future<RecallResult> create(RapidRecall recall) =>
      _write('POST', '$_baseUrl/admin/rapid-recalls', recall.toWritePayload(),
          'create the deck');

  Future<RecallResult> update(int id, Map<String, dynamic> body) =>
      _write('PATCH', '$_baseUrl/admin/rapid-recalls/$id', body,
          'save the deck');

  /// draft <-> published. Separate from [update] because it is one field and
  /// resending the scope chain would risk a 400 on an unrelated save.
  Future<RecallResult> setStatus(int id, {required bool published}) => _write(
        'PATCH',
        '$_baseUrl/admin/rapid-recalls/$id',
        {'status': published ? 'published' : 'draft'},
        published ? 'publish the deck' : 'unpublish the deck',
      );

  Future<RecallResult> _write(
    String method,
    String url,
    Map<String, dynamic> body,
    String verb,
  ) async {
    final token = await _token();
    if (token == null) {
      return RecallResult.failure('Session expired. Please log in again.');
    }

    try {
      final uri = Uri.parse(url);
      final headers = _headers(token);
      final encoded = jsonEncode(body);

      final response = await (method == 'POST'
              ? http.post(uri, headers: headers, body: encoded)
              : http.patch(uri, headers: headers, body: encoded))
          .timeout(_timeout);

      final decoded = _tryDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return RecallResult.success(_recallFrom(decoded));
      }
      return RecallResult.failure(
          _messageFrom(decoded, response.statusCode, verb));
    } catch (e) {
      return RecallResult.failure('Could not reach the server: $e');
    }
  }

  /// Replaces the whole deck.
  ///
  /// Add, edit, remove and reorder are all this one call: the array as it
  /// looks on screen, with `displayOrder` taken from the index. There is no
  /// diffing to get wrong, and the server runs it in a transaction so a
  /// half-applied deck cannot happen.
  ///
  /// An empty list is valid and clears the deck.
  Future<RecallCountResult> saveCards(int id, List<RapidRecallCard> cards) async {
    final token = await _token();
    if (token == null) {
      return RecallCountResult.failure('Session expired. Please log in again.');
    }

    // The server names the offending position, and so does this: "a deck of
    // forty is unfixable otherwise" applies just as much before the request.
    for (var i = 0; i < cards.length; i++) {
      // The server's own rule - the image is optional, but a note must carry
      // an image or some text.
      if (cards[i].isEmpty) {
        return RecallCountResult.failure(
            'Note ${i + 1} needs an image or some text.');
      }
    }

    try {
      final response = await http
          .put(
            Uri.parse('$_baseUrl/admin/rapid-recalls/$id/cards'),
            headers: _headers(token),
            body: jsonEncode({'cards': [for (final c in cards) c.toJson()]}),
          )
          .timeout(_timeout);

      final decoded = _tryDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final raw = decoded is Map ? decoded['cards'] : null;
        return RecallCountResult.success(
          decoded is Map
              ? ((decoded['cardCount'] as num?)?.toInt() ?? cards.length)
              : cards.length,
          cards: raw is List
              ? raw
                  .whereType<Map<String, dynamic>>()
                  .map(RapidRecallCard.fromJson)
                  .toList()
              : const [],
        );
      }
      return RecallCountResult.failure(
          _messageFrom(decoded, response.statusCode, 'save the cards'));
    } catch (e) {
      return RecallCountResult.failure('Could not reach the server: $e');
    }
  }

  /// Returns the card count the server reports, so the confirmation can quote
  /// it rather than a number this app guessed.
  Future<RecallCountResult> delete(int id) async {
    final token = await _token();
    if (token == null) {
      return RecallCountResult.failure('Session expired. Please log in again.');
    }

    try {
      final response = await http
          .delete(Uri.parse('$_baseUrl/admin/rapid-recalls/$id'),
              headers: _headers(token))
          .timeout(_timeout);
      final decoded = _tryDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 204) {
        return RecallCountResult.success(decoded is Map
            ? ((decoded['cardCount'] ?? decoded['deletedCards'] ?? 0) as num)
                .toInt()
            : 0);
      }
      return RecallCountResult.failure(
          _messageFrom(decoded, response.statusCode, 'delete the deck'));
    } catch (e) {
      return RecallCountResult.failure('Could not reach the server: $e');
    }
  }
}
