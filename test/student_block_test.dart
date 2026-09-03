import 'package:flutter_test/flutter_test.dart';

import 'package:admin_drapp/models/admin_student_model.dart';
import 'package:admin_drapp/models/student_progress_model.dart';

AdminStudentModel student(String status) =>
    AdminStudentModel.fromJson({'id': 1, 'email': 'a@b.c', 'status': status});

void main() {
  group('status wire values', () {
    test('the three the API accepts are spelled exactly', () {
      // Anything else is a 400. "inactive" and "disabled" read like they would
      // work and do not, so the enum is the only way to send one.
      expect(StudentStatus.verified.wire, 'verified');
      expect(StudentStatus.unverified.wire, 'unverified');
      expect(StudentStatus.blocked.wire, 'blocked');
      expect(StudentStatus.values.length, 3);
    });

    test('"active" from the list endpoint still reads as verified', () {
      expect(student('active').statusValue, StudentStatus.verified);
      expect(student('active').isBlocked, isFalse);
    });

    test('an unknown status is never normalised into Active', () {
      final s = student('pending_review');
      expect(s.statusValue, isNull);
      expect(s.statusLabel, 'pending_review');
      expect(s.isBlocked, isFalse);
    });

    test('blocked is recognised whatever the casing', () {
      for (final raw in ['blocked', 'BLOCKED', ' Blocked ']) {
        expect(student(raw).isBlocked, isTrue, reason: raw);
        expect(student(raw).statusLabel, 'Blocked', reason: raw);
      }
    });
  });

  test('copyWith replaces only the status', () {
    final before = AdminStudentModel.fromJson({
      'id': 38,
      'name': 'Block Test',
      'email': 'a@b.c',
      'phone': '123',
      'status': 'verified',
    });
    final after = before.copyWith(status: 'blocked');

    expect(after.isBlocked, isTrue);
    expect(after.id, 38);
    expect(after.name, 'Block Test');
    expect(after.phone, '123');
  });

  group('session block', () {
    test('is read off the detail payload', () {
      final detail = StudentDetail.fromJson({
        'isLoggedIn': true,
        'currentDeviceId': 'PHONE-A',
        'lastSeenAt': '2026-09-02T10:00:00.000Z',
        'status': 'blocked',
      });

      expect(detail.isLoggedIn, isTrue);
      expect(detail.currentDeviceId, 'PHONE-A');
      expect(detail.lastSeenAt, isNotNull);
      expect(detail.status, 'blocked');
    });

    test('a payload with no session block reads as not signed in', () {
      final detail = StudentDetail.fromJson({});
      expect(detail.isLoggedIn, isFalse);
      expect(detail.currentDeviceId, isNull);
      expect(detail.lastSeenAt, isNull);
    });
  });
}
