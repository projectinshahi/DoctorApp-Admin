import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'upload_media_type.dart';

import '../core/const/api_constant.dart';
import '../core/const/local_storegae.dart';

/// One uploaded file.
///
/// [publicId] is kept alongside the URL because it is the ONLY handle that can
/// delete the file. Storing just the URL leaves the asset unreachable rather
/// than merely unreferenced.
class QuestionImage {
  final String url;
  final String publicId;
  final String? originalFilename;
  final int? bytes;

  const QuestionImage({
    required this.url,
    required this.publicId,
    this.originalFilename,
    this.bytes,
  });

  factory QuestionImage.fromJson(Map<String, dynamic> json) => QuestionImage(
        url: (json['url'] ?? '') as String,
        publicId: (json['publicId'] ?? '') as String,
        originalFilename: json['originalFilename'] as String?,
        bytes: (json['bytes'] as num?)?.toInt(),
      );
}

class QuestionImageResult {
  final bool isSuccess;
  final QuestionImage? image;
  final String? errorMessage;

  const QuestionImageResult._(
      {required this.isSuccess, this.image, this.errorMessage});

  factory QuestionImageResult.success(QuestionImage image) =>
      QuestionImageResult._(isSuccess: true, image: image);

  factory QuestionImageResult.failure(String message) =>
      QuestionImageResult._(isSuccess: false, errorMessage: message);
}

/// Uploading and deleting question images.
///
/// UPLOAD  POST   /api/uploads/question-image   multipart, field "image"
/// DELETE  DELETE /api/uploads/question-image   { publicId }
///
/// The upload is NOT tied to a question - the file goes up while the question
/// is still being written and has no id yet. So whoever calls this owns the
/// cleanup: an admin who uploads and abandons the form leaves an orphan unless
/// [delete] is called.
class QuestionImageService {
  static const String _baseUrl = ApiConstant.baseUrl;
  static const Duration _timeout = Duration(seconds: 60);

  /// Accepted by the server. A PDF is refused with a 400.
  static const allowedExtensions = ['jpg', 'jpeg', 'png', 'webp', 'svg'];

  /// 2MB, enforced server-side. Checked here too so a large file fails
  /// instantly instead of after the upload.
  static const maxBytes = 2 * 1024 * 1024;

  Future<String?> _token() => AdminLocalStorage.getToken();

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

  Future<QuestionImageResult> upload({
    required Uint8List bytes,
    required String filename,
  }) async {
    final token = await _token();
    if (token == null) {
      return QuestionImageResult.failure('Session expired. Please log in again.');
    }

    if (bytes.length > maxBytes) {
      final mb = (bytes.length / (1024 * 1024)).toStringAsFixed(1);
      return QuestionImageResult.failure(
          'That file is ${mb}MB. The limit is 2MB.');
    }

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/uploads/question-image'),
      )
        ..headers['Authorization'] = 'Bearer $token'
        // One file per request, and the field is named "image".
        //
        // contentType is not optional in practice: without it the part goes up
        // as application/octet-stream and the server's fileFilter refuses a
        // valid PNG.
        ..files.add(http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: filename,
          contentType: uploadMediaType(filename),
        ));

      final streamed = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamed);
      final decoded = _tryDecode(response.body);

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          decoded is Map<String, dynamic>) {
        return QuestionImageResult.success(QuestionImage.fromJson(decoded));
      }
      return QuestionImageResult.failure(
          _messageFrom(decoded, response.statusCode, 'upload the image'));
    } catch (e) {
      return QuestionImageResult.failure('Could not reach the server: $e');
    }
  }

  /// Removes an uploaded file.
  ///
  /// Deleting one that is already gone also reports success - the goal is that
  /// it is gone, not that this call was the one that did it. Cloudinary's CDN
  /// may keep serving the URL briefly afterwards; that is caching, and the
  /// response is the truth.
  Future<bool> delete(String publicId) async {
    if (publicId.trim().isEmpty) return false;
    final token = await _token();
    if (token == null) return false;

    try {
      final response = await http
          .delete(
            Uri.parse('$_baseUrl/uploads/question-image'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'publicId': publicId}),
          )
          .timeout(_timeout);

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      // A failed cleanup leaves an orphan, which is untidy but harmless - it
      // must never block the admin from finishing or leaving the form.
      return false;
    }
  }
}
