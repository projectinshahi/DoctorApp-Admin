import 'package:flutter_test/flutter_test.dart';

import 'package:admin_drapp/services/question_image_service.dart';
import 'package:admin_drapp/widget/question_image_view.dart';

/// SVG detection decides which renderer runs, and the renderer is what keeps
/// an SVG's script away from the panel. Getting it from the URL matters
/// because the question row stores only the URL - the `format` field exists
/// solely in the upload response.
void main() {
  group('isSvg', () {
    test('detects an svg by its URL extension', () {
      expect(
        QuestionImageView.isSvg(
            'https://res.cloudinary.com/x/image/upload/v1/question_images/a.svg'),
        isTrue,
      );
      expect(QuestionImageView.isSvg('https://cdn/x/a.SVG'), isTrue);
    });

    test('raster formats are not svg', () {
      expect(QuestionImageView.isSvg('https://cdn/a.png'), isFalse);
      expect(QuestionImageView.isSvg('https://cdn/a.jpg'), isFalse);
      expect(QuestionImageView.isSvg('https://cdn/a.webp'), isFalse);
    });

    test('a query string does not fool it either way', () {
      // Uri.path drops the query, so ?v=2 cannot hide the extension...
      expect(QuestionImageView.isSvg('https://cdn/a.svg?v=2'), isTrue);
      // ...and "svg" appearing only in the query is not an SVG.
      expect(QuestionImageView.isSvg('https://cdn/a.png?type=svg'), isFalse);
    });
  });

  test('the upload response keeps the publicId, not just the URL', () {
    // The URL cannot delete a file. Losing the publicId leaves the asset
    // unreachable rather than merely unreferenced.
    final image = QuestionImage.fromJson({
      'url': 'https://res.cloudinary.com/x/image/upload/v1/question_images/s2.svg',
      'publicId': 'question_images/s2',
      'originalFilename': 'sample-ecg-lead-ii.svg',
      'bytes': 1468,
      'format': 'svg',
    });

    expect(image.publicId, 'question_images/s2');
    expect(image.originalFilename, 'sample-ecg-lead-ii.svg');
    expect(image.bytes, 1468);
  });

  test('the accepted extensions match what the server takes', () {
    expect(QuestionImageService.allowedExtensions,
        containsAll(['jpg', 'jpeg', 'png', 'webp', 'svg']));
    expect(QuestionImageService.allowedExtensions, isNot(contains('pdf')));
    expect(QuestionImageService.maxBytes, 2 * 1024 * 1024);
  });
}
