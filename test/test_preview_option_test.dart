import 'package:flutter_test/flutter_test.dart';

import 'package:admin_drapp/models/admin_test_model.dart';

/// The preview parser has to survive three shapes the backend and the sheets
/// actually use, and an image-only option must not be dropped.
void main() {
  group('TestPreviewQuestion options', () {
    test('reads a list of objects with optionImageUrl', () {
      final q = TestPreviewQuestion.fromJson({
        'id': 1,
        'questionText': 'Which ECG is this?',
        'questionImageUrl': 'https://cdn/q1.png',
        'correctOption': 'B',
        'options': [
          {'optionText': 'Sinus', 'optionImageUrl': 'https://cdn/a.png'},
          {'optionText': 'AF'},
        ],
      });

      expect(q.options.length, 2);
      expect(q.options[0].imageUrl, 'https://cdn/a.png');
      expect(q.options[0].hasImage, isTrue);
      expect(q.options[1].hasImage, isFalse);
      expect(q.hasImage, isTrue);
      expect(q.correctIndex, 1);
    });

    test('reads a list of bare strings', () {
      final q = TestPreviewQuestion.fromJson({
        'id': 2,
        'questionText': 'Capital?',
        'correctOption': 'A',
        'options': ['Delhi', 'Mumbai'],
      });

      expect(q.options.map((o) => o.text).toList(), ['Delhi', 'Mumbai']);
      expect(q.options.every((o) => !o.hasImage), isTrue);
      expect(q.hasImage, isFalse);
    });

    test('reads optionA..optionD columns with their image columns', () {
      final q = TestPreviewQuestion.fromJson({
        'id': 3,
        'question_text': 'Identify the lesion',
        'question_image_url': 'https://cdn/q3.png',
        'correct_option': 'C',
        'optionA': 'One',
        'option_b': 'Two',
        'optionAImageUrl': 'https://cdn/a3.png',
        'option_b_image_url': 'https://cdn/b3.png',
        'optionC': 'Three',
      });

      expect(q.options.length, 3);
      expect(q.options[0].imageUrl, 'https://cdn/a3.png');
      expect(q.options[1].imageUrl, 'https://cdn/b3.png');
      expect(q.options[2].hasImage, isFalse);
      expect(q.questionImageUrl, 'https://cdn/q3.png');
      expect(q.correctIndex, 2);
    });

    test('keeps an image-only option', () {
      final q = TestPreviewQuestion.fromJson({
        'id': 4,
        'questionText': 'Pick the matching diagram',
        'correctOption': 'A',
        'option1_image_url': 'https://cdn/d1.png',
        'option2_image_url': 'https://cdn/d2.png',
      });

      expect(q.options.length, 2);
      expect(q.options[0].text, '');
      expect(q.options[0].hasImage, isTrue);
      expect(q.correctIndex, 0);
    });

    test('blank image cells do not count as images', () {
      final q = TestPreviewQuestion.fromJson({
        'id': 5,
        'questionText': 'Q',
        'questionImageUrl': '   ',
        'correctOption': 'A',
        'options': [
          {'optionText': 'One', 'optionImageUrl': ''},
        ],
      });

      expect(q.hasImage, isFalse);
      expect(q.options.single.hasImage, isFalse);
    });

    test('correctIndex is null when the letter is out of range', () {
      final q = TestPreviewQuestion.fromJson({
        'id': 6,
        'questionText': 'Q',
        'correctOption': 'D',
        'options': ['One', 'Two'],
      });

      expect(q.correctIndex, isNull);
    });
  });
}
