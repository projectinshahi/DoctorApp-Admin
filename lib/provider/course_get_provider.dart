import 'package:flutter/material.dart';

import '../models/course_get_model.dart';
import '../services/courseget_service.dart';


class CourseListGetProvider extends ChangeNotifier {
  final CourseListGetService _service = CourseListGetService();

  List<CourseListGetModel> courses = [];

  bool isLoadingCourses = false;

  String? coursesErrorMessage;

  Future<void> fetchCourses({
    String? status,
    String? accessType,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    isLoadingCourses = true;
    coursesErrorMessage = null;
    notifyListeners();

    try {
      courses = await _service.fetchCourses(
        status: status,
        accessType: accessType,
        search: search,
        page: page,
        limit: limit,
      );
    } catch (e) {
      coursesErrorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoadingCourses = false;
      notifyListeners();
    }
  }

  void clearCourses() {
    courses.clear();
    notifyListeners();
  }
}