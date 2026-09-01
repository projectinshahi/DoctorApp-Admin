import 'package:flutter_test/flutter_test.dart';

import 'package:admin_drapp/models/admin_account_model.dart';
import 'package:admin_drapp/services/admin_account_service.dart';

void main() {
  test('reads the admin off the real /admin/me shape', () {
    final admin = AdminAccount.fromJson({
      'id': 1,
      'email': 'admin@yourapp.com',
      'name': 'Super Admin',
      'role': 'admin',
      'status': 'active',
      'createdAt': '2026-01-04T10:00:00.000Z',
      'updatedAt': '2026-08-31T10:00:00.000Z',
    });

    expect(admin.id, 1);
    expect(admin.displayName, 'Super Admin');
    expect(admin.isActive, isTrue);
    expect(admin.createdAt, isNotNull);
  });

  test('falls back to the email when no name is set', () {
    final admin = AdminAccount.fromJson({
      'id': 2,
      'email': 'second@yourapp.com',
      'name': '   ',
      'role': 'admin',
      'status': 'disabled',
    });

    expect(admin.displayName, 'second@yourapp.com');
    expect(admin.isActive, isFalse);
  });

  group('password errors are routed to the field the server blamed', () {
    test('a wrong current password names the current field', () {
      final result = PasswordChangeResult.failure(
        'Your current password is incorrect',
        field: PasswordChangeResult.fieldCurrent,
      );
      expect(result.isSuccess, isFalse);
      expect(result.fieldError, PasswordChangeResult.fieldCurrent);
    });

    test('a rejected new password names the new field', () {
      final result = PasswordChangeResult.failure(
        'New password must be at least 8 characters',
        field: PasswordChangeResult.fieldNew,
      );
      expect(result.fieldError, PasswordChangeResult.fieldNew);
    });

    test('an unattributed failure names no field', () {
      final result = PasswordChangeResult.failure('Could not reach the server');
      expect(result.fieldError, isNull);
    });
  });

  group('only 401 and 403 end the session', () {
    test('a dead account must re-authenticate', () {
      final result = AdminAccountResult.failure(
        'This admin account no longer exists',
        mustReauthenticate: true,
      );
      expect(result.mustReauthenticate, isTrue);
    });

    test('a network failure must not log anyone out', () {
      // Treating a blip as a dead session throws an admin back to login and
      // loses whatever they had typed.
      final result =
          AdminAccountResult.failure('Could not reach the server: timeout');
      expect(result.mustReauthenticate, isFalse);
    });
  });

  test('emailChanged rides on a successful profile save', () {
    const admin = AdminAccount(
      id: 1,
      email: 'new@yourapp.com',
      role: 'admin',
      status: 'active',
    );

    expect(AdminAccountResult.success(admin).emailChanged, isFalse);
    expect(
      AdminAccountResult.success(admin, emailChanged: true).emailChanged,
      isTrue,
    );
  });
}
