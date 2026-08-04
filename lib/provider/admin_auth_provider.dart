import 'package:flutter/material.dart';

import '../core/const/local_storegae.dart';
import '../models/admin_auth_model.dart';
import '../services/admin_login_services.dart';

class AdminAuthProvider extends ChangeNotifier {
  final AdminAuthService _adminAuthService = AdminAuthService();

  bool _isLoading = false;
  String? _errorMessage;
  AdminAuthResultModel? _authResult;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  AdminAuthResultModel? get authResult => _authResult;

  Future<bool> adminLogin({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _adminAuthService.adminLogin(
        email: email,
        password: password,
      );

      _authResult = result;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _adminAuthService.logout();
    _authResult = null;
    notifyListeners();
  }

  Future<bool> checkIfLoggedIn() async {
    return await AdminLocalStorage.isLoggedIn();
  }
}