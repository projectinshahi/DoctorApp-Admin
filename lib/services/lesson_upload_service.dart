


import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import '../core/const/local_storegae.dart';
import '../core/const/api_constant.dart';
import 'upload_media_type.dart';

class UploadResult {
  final bool isSuccess;
  final String? url;
  final String? publicId;
  final String? fileType;
  final int? durationSeconds;
  final String? errorMessage;

  UploadResult._({
    required this.isSuccess,
    this.url,
    this.publicId,
    this.fileType,
    this.durationSeconds,
    this.errorMessage,
  });

  factory UploadResult.success({
    required String url,
    required String publicId,
    String? fileType,
    int? durationSeconds,
  }) =>
      UploadResult._(
        isSuccess: true,
        url: url,
        publicId: publicId,
        fileType: fileType,
        durationSeconds: durationSeconds,
      );

  factory UploadResult.failure(String message) => UploadResult._(isSuccess: false, errorMessage: message);
}

class DeleteResult {
  final bool isSuccess;
  final String? errorMessage;

  DeleteResult._({required this.isSuccess, this.errorMessage});

  factory DeleteResult.success() => DeleteResult._(isSuccess: true);
  factory DeleteResult.failure(String message) => DeleteResult._(isSuccess: false, errorMessage: message);
}

class LessonUploadService {
  final String baseUrl;

  LessonUploadService({this.baseUrl = ApiConstant.root});

  Future<String?> _getToken() async {
    final adminToken = await AdminLocalStorage.getToken();
    return (adminToken == null || adminToken.isEmpty) ? null : adminToken;
  }

  String? _errorMessageFrom(dynamic decoded, int statusCode, String failureVerb) {
    if (decoded is Map && decoded['error'] is Map && decoded['error']['message'] != null) {
      return decoded['error']['message'].toString();
    }
    return 'Failed to $failureVerb (status $statusCode)';
  }

  // ── Uploads ────────────────────────────────────────────────────────

  Future<UploadResult> uploadVideo(Uint8List bytes, String filename) async {
    return _uploadFile(
      endpoint: '/api/uploads/lesson-video',
      fieldName: 'video',
      bytes: bytes,
      filename: filename,
      failureVerb: 'upload video',
      parseExtra: (decoded) => {
        'durationSeconds': (decoded['durationSeconds'] as num?)?.toInt(),
      },
    );
  }

  Future<UploadResult> uploadNote(Uint8List bytes, String filename) async {
    return _uploadFile(
      endpoint: '/api/uploads/lesson-note',
      fieldName: 'note',
      bytes: bytes,
      filename: filename,
      failureVerb: 'upload note',
      parseExtra: (decoded) => {
        'fileType': decoded['fileType'] as String?,
      },
    );
  }

  Future<UploadResult> uploadThumbnail(Uint8List bytes, String filename) async {
    return _uploadFile(
      endpoint: '/api/uploads/lesson-thumbnail',
      fieldName: 'thumbnail',
      bytes: bytes,
      filename: filename,
      failureVerb: 'upload thumbnail',
      parseExtra: (_) => {},
    );
  }

  Future<UploadResult> _uploadFile({
    required String endpoint,
    required String fieldName,
    required Uint8List bytes,
    required String filename,
    required String failureVerb,
    required Map<String, dynamic> Function(Map<String, dynamic> decoded) parseExtra,
  }) async {
    final adminToken = await _getToken();
    if (adminToken == null) return UploadResult.failure('Session expired. Please log in again.');

    final uri = Uri.parse('$baseUrl$endpoint');

    try {
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $adminToken'
        ..files.add(http.MultipartFile.fromBytes(
          fieldName,
          bytes,
          filename: filename,
          contentType: uploadMediaType(filename),
        ));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);
      final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};

      if (response.statusCode == 200 && decoded is Map && decoded['url'] != null && decoded['publicId'] != null) {
        final extra = parseExtra(decoded.cast<String, dynamic>());
        return UploadResult.success(
          url: decoded['url'] as String,
          publicId: decoded['publicId'] as String,
          fileType: extra['fileType'] as String?,
          durationSeconds: extra['durationSeconds'] as int?,
        );
      }
      return UploadResult.failure(_errorMessageFrom(decoded, response.statusCode, failureVerb)!);
    } on http.ClientException {
      return UploadResult.failure('Network error. Please check your connection.');
    } on FormatException {
      return UploadResult.failure('Unexpected response from server.');
    } catch (e) {
      return UploadResult.failure('Something went wrong: $e');
    }
  }

  // ── Deletes ────────────────────────────────────────────────────────

  Future<DeleteResult> deleteVideo(String publicId) => _deleteAsset(
    endpoint: '/api/uploads/lesson-video',
    publicId: publicId,
    failureVerb: 'delete video',
  );

  Future<DeleteResult> deleteNote(String publicId) => _deleteAsset(
    endpoint: '/api/uploads/lesson-note',
    publicId: publicId,
    failureVerb: 'delete note',
  );

  Future<DeleteResult> deleteThumbnail(String publicId) => _deleteAsset(
    endpoint: '/api/uploads/lesson-thumbnail',
    publicId: publicId,
    failureVerb: 'delete thumbnail',
  );

  Future<DeleteResult> _deleteAsset({
    required String endpoint,
    required String publicId,
    required String failureVerb,
  }) async {
    final adminToken = await _getToken();
    if (adminToken == null) return DeleteResult.failure('Session expired. Please log in again.');

    final uri = Uri.parse('$baseUrl$endpoint');

    try {
      final response = await http
          .delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $adminToken',
        },
        body: jsonEncode({'publicId': publicId}),
      )
          .timeout(const Duration(seconds: 15));

      final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};

      if (response.statusCode == 200 && decoded is Map && decoded['deleted'] == true) {
        return DeleteResult.success();
      }
      return DeleteResult.failure(_errorMessageFrom(decoded, response.statusCode, failureVerb)!);
    } on http.ClientException {
      return DeleteResult.failure('Network error. Please check your connection.');
    } on FormatException {
      return DeleteResult.failure('Unexpected response from server.');
    } catch (e) {
      return DeleteResult.failure('Something went wrong: $e');
    }
  }
}