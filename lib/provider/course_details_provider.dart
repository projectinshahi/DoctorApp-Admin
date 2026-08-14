import 'package:flutter/material.dart';

import '../models/course_details_model.dart';
import '../services/course_details_service.dart';

class CourseDetailsProvider extends ChangeNotifier {
  final CourseDetailsService _service = CourseDetailsService();

  CourseDetails? _courseDetails;
  bool _isLoading = false;
  String? _errorMessage;

  CourseDetails? get courseDetails => _courseDetails;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadCourseDetails(int courseId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _courseDetails = await _service.fetchCourseDetails(courseId);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}