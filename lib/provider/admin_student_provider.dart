import 'package:flutter/foundation.dart';

import '../models/admin_student_model.dart';
import '../services/admin_student_service.dart';


class AdminStudentProvider extends ChangeNotifier {
  final AdminStudentService _service =
  AdminStudentService();

  List<AdminStudentModel> _students = [];

  PaginationModel? _pagination;

  bool _isLoading = false;

  String? _errorMessage;

  List<AdminStudentModel> get students => _students;

  PaginationModel? get pagination => _pagination;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  Future<void> loadStudents({
    int page = 1,
    int limit = 10,
  }) async {
    _isLoading = true;
    _errorMessage = null;

    notifyListeners();

    try {
      final response = await _service.getStudents(
        page: page,
        limit: limit,
      );

      _students = response.data;
      _pagination = response.pagination;
    } catch (e) {
      _errorMessage = e.toString();
      _students = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshStudents() async {
    await loadStudents(
      page: _pagination?.page ?? 1,
      limit: _pagination?.limit ?? 10,
    );
  }
}