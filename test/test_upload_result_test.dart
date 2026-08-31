import 'package:flutter_test/flutter_test.dart';

import 'package:admin_drapp/models/admin_test_model.dart';
import 'package:admin_drapp/services/admin_test_service.dart';

/// The bug this guards: a 200 that carries a warnings array is a successful
/// import. Judging failure from `errors.length` rejects a good upload and
/// tells the admin nothing was saved when it was.
void main() {
  TestUploadIssue warning(int row) => TestUploadIssue(
        row: row,
        field: 'question_image_url',
        message: 'Not one of this test\'s uploaded images — check it loads',
        severity: 'warning',
      );

  TestUploadIssue error(int row) => TestUploadIssue(
        row: row,
        field: 'correct_option',
        message: 'Must be A, B, C or D',
      );

  test('a success carrying warnings is still a success', () {
    final result = TestUploadResult.success(
      imported: 1,
      message: 'Imported 1 question(s). The test is not published yet.',
      issues: [warning(2)],
    );

    expect(result.isSuccess, isTrue);
    expect(result.imported, 1);
    expect(result.hasWarnings, isTrue);
    expect(result.warnings.length, 1);
    expect(result.blocking, isEmpty);
    expect(result.message, contains('not published yet'));
  });

  test('a clean success has no warnings to stop on', () {
    final result = TestUploadResult.success(imported: 200, message: 'Imported 200.');
    expect(result.isSuccess, isTrue);
    expect(result.hasWarnings, isFalse);
    expect(result.issues, isEmpty);
  });

  test('severity splits the issues, not their count', () {
    final result = TestUploadResult.failure(
      'Nothing was saved',
      [error(4), warning(9), error(11)],
    );

    expect(result.isSuccess, isFalse);
    expect(result.blocking.length, 2);
    expect(result.warnings.length, 1);
  });

  test('an issue with no severity blocks', () {
    // Absent severity means error: treating an unlabelled row as a warning
    // would let a genuinely broken import through to review.
    expect(error(3).isWarning, isFalse);
    expect(warning(3).isWarning, isTrue);
    expect(
      TestUploadIssue.fromJson({'row': 1, 'field': 'x', 'message': 'y'})
          .isWarning,
      isFalse,
    );
    expect(
      TestUploadIssue.fromJson(
              {'row': 1, 'field': 'x', 'message': 'y', 'severity': 'warning'})
          .isWarning,
      isTrue,
    );
  });
}
