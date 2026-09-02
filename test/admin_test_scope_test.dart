import 'package:flutter_test/flutter_test.dart';

import 'package:admin_drapp/models/admin_test_model.dart';

/// Scoping and deletability are both "null / zero means something specific"
/// rules, which is exactly where a wrong default does damage.
void main() {
  test('reads the nested course and courseType objects', () {
    final test = AdminTest.fromJson({
      'id': 1,
      'name': 'Grand Test 3',
      'courseId': 22,
      'courseTypeId': 20,
      'course': {'id': 22, 'title': 'Specialist Gulf Licensing Exam'},
      'courseType': {'id': 20, 'title': 'DHA'},
      'totalQuestions': 200,
      'questionCount': 200,
    });

    expect(test.title, 'Grand Test 3');
    expect(test.courseTitle, 'Specialist Gulf Licensing Exam');
    expect(test.courseTypeTitle, 'DHA');
    expect(test.isScopedToType, isTrue);
    expect(test.scopeLabel, 'DHA');
  });

  test('an unscoped row is named as the exception it now is', () {
    final test = AdminTest.fromJson({
      'id': 2,
      'name': 'Open paper',
      'courseId': 22,
      'courseTypeId': null,
      'totalQuestions': 10,
      'questionCount': 10,
    });

    // New papers always carry an exam type - the form refuses to submit
    // without one - so a null scope means an older row, not a deliberate
    // course-wide choice.
    expect(test.courseTypeId, isNull);
    expect(test.isScopedToType, isFalse);
    expect(test.scopeLabel, 'No exam type');
  });

  test('courseTypeId is sent even when null', () {
    // Omitting it would read as "unchanged" rather than "the whole course".
    const open = AdminTest(
      id: 0,
      courseId: 22,
      title: 'Open',
      totalQuestions: 10,
      questionCount: 0,
    );

    final payload = open.toCreatePayload();
    expect(payload.containsKey('courseTypeId'), isTrue);
    expect(payload['courseTypeId'], isNull);
    // The server names the field `name`, not `title`.
    expect(payload['name'], 'Open');
  });

  test('delete is refused once anyone has attempted', () {
    AdminTest withAttempts(int count, {bool locked = false}) =>
        AdminTest.fromJson({
          'id': 3,
          'name': 'Grand Test 1',
          'courseId': 22,
          'totalQuestions': 2,
          'questionCount': 2,
          'attemptCount': count,
          'isLocked': locked,
        });

    expect(withAttempts(0).canDelete, isTrue);
    expect(withAttempts(2).canDelete, isFalse);
    // isLocked also means attempted, even if the count did not come through.
    expect(withAttempts(0, locked: true).canDelete, isFalse);
  });
}
