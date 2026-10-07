import 'package:admin_drapp/Screen/Dashbord/add_edit_lesson_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('what one tick means for isFreePreview', () {
    test('a free course has nothing to preview, ticked or not', () {
      expect(
        lessonFreePreview(coursePremium: false, isFree: true, current: false),
        isFalse,
      );
      expect(
        lessonFreePreview(coursePremium: false, isFree: false, current: false),
        isFalse,
      );
    });

    test('free on a premium course IS the preview', () {
      expect(
        lessonFreePreview(coursePremium: true, isFree: true, current: false),
        isTrue,
      );
    });

    test('premium on a premium course closes the preview', () {
      // The case the flag exists for: a lesson switched to premium must not
      // stay open on a preview flag set when it was free.
      expect(
        lessonFreePreview(coursePremium: true, isFree: false, current: true),
        isFalse,
      );
    });

    test('an unknown course keeps whatever the lesson already had', () {
      expect(
        lessonFreePreview(coursePremium: null, isFree: true, current: true),
        isTrue,
      );
      expect(
        lessonFreePreview(coursePremium: null, isFree: false, current: false),
        isFalse,
      );
    });
  });
}
