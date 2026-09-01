import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/const/api_constant.dart';
import '../core/const/local_storegae.dart';
import '../models/admin_account_model.dart';

/// Outcome of loading the signed-in admin.
///
/// [mustReauthenticate] separates "your session is over" from "the request
/// failed": only the first should throw the admin back to login, and a
/// network blip must not.
class AdminAccountResult {
  final bool isSuccess;
  final AdminAccount? admin;
  final String? errorMessage;
  final bool mustReauthenticate;

  /// True when the server reports the email actually changed. The email is
  /// the login, so this needs saying out loud.
  final bool emailChanged;

  const AdminAccountResult._({
    required this.isSuccess,
    this.admin,
    this.errorMessage,
    this.mustReauthenticate = false,
    this.emailChanged = false,
  });

  factory AdminAccountResult.success(AdminAccount admin,
          {bool emailChanged = false}) =>
      AdminAccountResult._(
          isSuccess: true, admin: admin, emailChanged: emailChanged);

  factory AdminAccountResult.failure(String message,
          {bool mustReauthenticate = false}) =>
      AdminAccountResult._(
        isSuccess: false,
        errorMessage: message,
        mustReauthenticate: mustReauthenticate,
      );
}

/// Outcome of a password change.
///
/// [fieldError] is set when the server blamed a specific field, so the
/// message can be rendered under that input instead of in a generic banner.
class PasswordChangeResult {
  final bool isSuccess;
  final String message;
  final String? fieldError;

  const PasswordChangeResult._({
    required this.isSuccess,
    required this.message,
    this.fieldError,
  });

  factory PasswordChangeResult.success(String message) =>
      PasswordChangeResult._(isSuccess: true, message: message);

  factory PasswordChangeResult.failure(String message, {String? field}) =>
      PasswordChangeResult._(
          isSuccess: false, message: message, fieldError: field);

  /// Which input to show the error under: 'current' or 'new'.
  static const fieldCurrent = 'current';
  static const fieldNew = 'new';
}

/// The admin's own account.
///
/// ME        GET   /admin/me
/// PROFILE   PATCH /admin/me                 { name, email }
/// PASSWORD  POST  /admin/me/password        { currentPassword, newPassword }
///
/// Root-mounted, NOT /api/admin/me.
class AdminAccountService {
  static const String _baseUrl = ApiConstant.root;
  static const Duration _timeout = Duration(seconds: 30);

  Future<String?> _token() => AdminLocalStorage.getToken();

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  /// Decodes only if there is something to decode - a server missing a route
  /// answers with an HTML page, and the status code is more useful than a
  /// parse failure.
  dynamic _tryDecode(String body) {
    if (body.trim().isEmpty) return null;
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  String _messageFrom(dynamic decoded, int status, String fallback) {
    if (decoded is Map) {
      final error = decoded['error'];
      if (error is Map && error['message'] != null) return '${error['message']}';
      if (error is String) return error;
      if (decoded['message'] != null) return '${decoded['message']}';
    }
    return '$fallback (status $status)';
  }

  AdminAccount? _adminFrom(dynamic decoded) {
    if (decoded is! Map) return null;
    final raw = decoded['admin'] ?? decoded['data'] ?? decoded;
    return raw is Map<String, dynamic> ? AdminAccount.fromJson(raw) : null;
  }

  /// Called when the panel boots.
  ///
  /// A 401 here means the account is gone and a 403 that it is disabled -
  /// both end the session, but they are different facts and the admin is told
  /// which. Finding out at boot beats finding out after filling in a form.
  Future<AdminAccountResult> getMe() async {
    final token = await _token();
    if (token == null) {
      return AdminAccountResult.failure('Session expired. Please log in again.',
          mustReauthenticate: true);
    }

    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/admin/me'), headers: _headers(token))
          .timeout(_timeout);
      final decoded = _tryDecode(response.body);

      if (response.statusCode == 200) {
        final admin = _adminFrom(decoded);
        if (admin != null) return AdminAccountResult.success(admin);
        return AdminAccountResult.failure('The server sent an unreadable '
            'account response.');
      }

      if (response.statusCode == 401) {
        return AdminAccountResult.failure(
          _messageFrom(decoded, 401, 'This admin account no longer exists'),
          mustReauthenticate: true,
        );
      }
      if (response.statusCode == 403) {
        return AdminAccountResult.failure(
          _messageFrom(decoded, 403, 'Admin account is not active'),
          mustReauthenticate: true,
        );
      }

      return AdminAccountResult.failure(
          _messageFrom(decoded, response.statusCode, 'Could not load your account'));
    } catch (e) {
      // A network failure is not a dead session - it must not log anyone out.
      return AdminAccountResult.failure('Could not reach the server: $e');
    }
  }

  /// Name and email only. Role and status are decided server-side.
  Future<AdminAccountResult> updateProfile({
    String? name,
    String? email,
  }) async {
    final token = await _token();
    if (token == null) {
      return AdminAccountResult.failure('Session expired. Please log in again.',
          mustReauthenticate: true);
    }

    try {
      final response = await http
          .patch(
            Uri.parse('$_baseUrl/admin/me'),
            headers: _headers(token),
            body: jsonEncode({
              if (name != null) 'name': name,
              if (email != null) 'email': email,
            }),
          )
          .timeout(_timeout);

      final decoded = _tryDecode(response.body);

      if (response.statusCode == 200) {
        final admin = _adminFrom(decoded);
        if (admin == null) {
          return AdminAccountResult.failure(
              'The server sent an unreadable account response.');
        }
        await AdminLocalStorage.saveAdminInfo(
          id: admin.id,
          email: admin.email,
          name: admin.name,
          role: admin.role,
        );
        return AdminAccountResult.success(
          admin,
          emailChanged:
              decoded is Map && (decoded['emailChanged'] as bool? ?? false),
        );
      }

      if (response.statusCode == 401) {
        return AdminAccountResult.failure(
          _messageFrom(decoded, 401, 'This admin account no longer exists'),
          mustReauthenticate: true,
        );
      }

      return AdminAccountResult.failure(
          _messageFrom(decoded, response.statusCode, 'Could not save your changes'));
    } catch (e) {
      return AdminAccountResult.failure('Could not reach the server: $e');
    }
  }

  /// Changes the password and stores the fresh token the server returns.
  ///
  /// The token is saved before returning, so the admin keeps working instead
  /// of being bounced mid-task - a panel that says "Password changed" and then
  /// 401s on the next click looks broken.
  ///
  /// The current password is required even though a valid token is already
  /// held: the case this guards is a session left open on a shared machine.
  Future<PasswordChangeResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final token = await _token();
    if (token == null) {
      return PasswordChangeResult.failure(
          'Session expired. Please log in again.');
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/admin/me/password'),
            headers: _headers(token),
            body: jsonEncode({
              'currentPassword': currentPassword,
              'newPassword': newPassword,
            }),
          )
          .timeout(_timeout);

      final decoded = _tryDecode(response.body);

      if (response.statusCode == 200) {
        final fresh = decoded is Map ? decoded['token'] as String? : null;
        if (fresh != null && fresh.isNotEmpty) {
          await AdminLocalStorage.saveToken(fresh);
        }
        final admin = _adminFrom(decoded);
        if (admin != null) {
          await AdminLocalStorage.saveAdminInfo(
            id: admin.id,
            email: admin.email,
            name: admin.name,
            role: admin.role,
          );
        }
        return PasswordChangeResult.success(
            (decoded is Map ? decoded['message'] as String? : null) ??
                'Password changed');
      }

      final message = _messageFrom(
          decoded, response.statusCode, 'Could not change your password');

      // 401 here means the *current password* was wrong, not that the session
      // died - the wording names the field because "invalid credentials"
      // tells a signed-in admin nothing.
      if (response.statusCode == 401) {
        return PasswordChangeResult.failure(message,
            field: PasswordChangeResult.fieldCurrent);
      }
      if (response.statusCode == 400) {
        return PasswordChangeResult.failure(message,
            field: PasswordChangeResult.fieldNew);
      }
      return PasswordChangeResult.failure(message);
    } catch (e) {
      return PasswordChangeResult.failure('Could not reach the server: $e');
    }
  }
}
