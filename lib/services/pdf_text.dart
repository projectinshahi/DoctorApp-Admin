import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart';

/// A PDF that cannot be read, in words an admin can act on.
class PdfTextException implements Exception {
  final String message;
  const PdfTextException(this.message);

  @override
  String toString() => message;
}

/// The text layer of [bytes].
///
/// A scan is a photograph of a page: it carries no text at all, and no amount
/// of parsing recovers what was never encoded. Worth saying plainly - the next
/// step there is an OCR pass, not another upload.
String extractPdfText(Uint8List bytes) {
  final PdfDocument document;
  try {
    document = PdfDocument(inputBytes: bytes);
  } catch (_) {
    throw const PdfTextException(
      'That file could not be opened as a PDF. If it is password protected, '
      'remove the password and try again.',
    );
  }

  try {
    final text = PdfTextExtractor(document).extractText();
    if (text.trim().isEmpty) {
      throw const PdfTextException(
        'That PDF has no selectable text - it is a scan of the page. Run it '
        'through OCR first, or paste the instructions in by hand.',
      );
    }
    return text;
  } finally {
    document.dispose();
  }
}
