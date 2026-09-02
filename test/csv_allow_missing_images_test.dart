import 'package:flutter_test/flutter_test.dart';

/// Mirrors the URL built in AdminTestService.uploadQuestions. The flag is a
/// query parameter, so getting it wrong fails silently: the server just keeps
/// its default and the admin sees the same refusal with the box ticked.
String uploadUrl(String base, int testId, {required bool allowMissingImages}) =>
    '$base/admin/tests/$testId/questions/upload'
    '${allowMissingImages ? '?allowMissingImages=true' : ''}';

/// Mirrors the "was it the images that blocked?" test in the wizard and the
/// error table. Both read the server's field name, which varies between
/// question_image_url, question_image_filename and option_a_image_url.
bool isImageField(String field) => field.toLowerCase().contains('image');

void main() {
  test('the flag is absent unless asked for, never sent as false', () {
    expect(uploadUrl('/api', 7, allowMissingImages: false),
        '/api/admin/tests/7/questions/upload');
    expect(uploadUrl('/api', 7, allowMissingImages: true),
        '/api/admin/tests/7/questions/upload?allowMissingImages=true');
  });

  test('every spelling of an image column is recognised', () {
    for (final field in [
      'question_image_url',
      'question_image_filename',
      'QUESTION_IMAGE_URL',
      'option_a_image_url',
      'optionDImageUrl',
    ]) {
      expect(isImageField(field), isTrue, reason: field);
    }
  });

  test('a non-image column never offers the images escape hatch', () {
    for (final field in ['correct_option', 'question_text', 'section']) {
      expect(isImageField(field), isFalse, reason: field);
    }
  });
}
