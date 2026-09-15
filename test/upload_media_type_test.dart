import 'package:flutter_test/flutter_test.dart';

import 'package:admin_drapp/services/upload_media_type.dart';

/// Without a contentType every multipart part goes up as
/// application/octet-stream and the server's fileFilter refuses it, whatever
/// the file actually is. This is the table that prevents that.
void main() {
  test('every image type the uploads accept has a real MIME type', () {
    expect(uploadMediaType('ecg.png').toString(), 'image/png');
    expect(uploadMediaType('ecg.jpg').toString(), 'image/jpeg');
    expect(uploadMediaType('ecg.jpeg').toString(), 'image/jpeg');
    expect(uploadMediaType('ecg.webp').toString(), 'image/webp');
    // The one the original table missed, so every SVG upload was refused.
    expect(uploadMediaType('ecg.svg').toString(), 'image/svg+xml');
  });

  test('handout types are covered too', () {
    expect(uploadMediaType('notes.pdf').toString(), 'application/pdf');
    expect(uploadMediaType('notes.doc').toString(), 'application/msword');
    expect(uploadMediaType('notes.docx').toString(),
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document');
  });

  test('case and paths do not change the answer', () {
    expect(uploadMediaType('ECG.PNG').toString(), 'image/png');
    expect(uploadMediaType('Sample Q1.SVG').toString(), 'image/svg+xml');
  });

  test('an unknown extension keeps the honest default', () {
    // Better refused by name than mislabelled as something it is not.
    expect(uploadMediaType('archive.zip').toString(),
        'application/octet-stream');
    expect(uploadMediaType('noextension').toString(),
        'application/octet-stream');
  });
}
