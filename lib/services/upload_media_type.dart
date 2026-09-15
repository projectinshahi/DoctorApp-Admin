import 'package:http_parser/http_parser.dart';

/// The MIME type for an upload, from its file extension.
///
/// **Without this every multipart upload goes out as
/// `application/octet-stream`**, and the backend's multer fileFilter rejects
/// it — "Unsupported file type application/octet-stream" — even for a
/// perfectly valid PNG. `MultipartFile.fromBytes` does not sniff the bytes and
/// does not guess from the name; if no contentType is passed, that default is
/// what the server sees.
///
/// Shared rather than copied: this was fixed once for lesson uploads and the
/// question-image upload silently kept the bug, so the two had to be the same
/// function for the fix to mean anything.
MediaType uploadMediaType(String filename) {
  final ext = filename.toLowerCase().split('.').last;
  switch (ext) {
    // Images
    case 'jpg':
    case 'jpeg':
      return MediaType('image', 'jpeg');
    case 'png':
      return MediaType('image', 'png');
    case 'webp':
      return MediaType('image', 'webp');
    // Accepted everywhere an image is, and the one the old table missed.
    case 'svg':
      return MediaType('image', 'svg+xml');
    // Video
    case 'mp4':
      return MediaType('video', 'mp4');
    case 'mov':
      return MediaType('video', 'quicktime');
    case 'mkv':
      return MediaType('video', 'x-matroska');
    case 'webm':
      return MediaType('video', 'webm');
    // Documents
    case 'pdf':
      return MediaType('application', 'pdf');
    case 'doc':
      return MediaType('application', 'msword');
    case 'docx':
      return MediaType(
        'application',
        'vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
    default:
      // Deliberately the same default the http package would use. A file the
      // server will refuse is better refused by name than mislabelled as
      // something it is not.
      return MediaType('application', 'octet-stream');
  }
}
