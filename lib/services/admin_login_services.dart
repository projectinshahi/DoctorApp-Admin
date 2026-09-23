import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/const/api_constant.dart';
import '../core/const/local_storegae.dart';
import '../models/admin_auth_model.dart';

class AdminAuthService {
  Future<AdminAuthResultModel> adminLogin({
    required String email,
    required String password,
  }) async {
    print('AdminAuthService: Sending login request...');

    late final http.Response response;
    try {
      response = await http.post(
        Uri.parse(ApiConstant.adminlogn), // -> https://doctorapp-backend-cl2h.onrender.com/api/auth/admin/login
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );
    } catch (e, st) {
      print('AdminAuthService: HTTP request THREW an error: $e');
      print('AdminAuthService: Stack trace: $st');
      rethrow;
    }

    // The body is deliberately not printed: it carries the admin bearer token,
    // and anything printed here ends up in terminal scrollback and log files.
    print('AdminAuthService: Status code: ${response.statusCode}');

    if (response.statusCode == 200) {
      final result = AdminAuthResultModel.fromJson(jsonDecode(response.body));

      // Store token and admin info locally
      await AdminLocalStorage.saveToken(result.token);
      await AdminLocalStorage.saveAdminInfo(
        id: result.admin.id,
        email: result.admin.email,
        name: result.admin.name,
        role: result.admin.role,
      );

      print('AdminAuthService: Logged in as ${result.admin.email}, token saved.');

      return result;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error']?['message'] ?? 'Admin login failed');
    }
  }

  Future<void> logout() async {
    await AdminLocalStorage.clearAdminData();
    print('AdminAuthService: Admin logged out, local data cleared.');
  }
}