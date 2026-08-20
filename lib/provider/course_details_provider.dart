import 'package:flutter/material.dart';

import '../models/course_details_model.dart';
import '../models/course_types_model.dart';
import '../services/course_details_service.dart';

class CourseDetailsProvider extends ChangeNotifier {
  final CourseDetailsService _service = CourseDetailsService();

  CourseDetails? _courseDetails;
  CourseTypesResponse? _courseTypesOnly;
  bool _isLoading = false;
  String? _errorMessage;
  String? _degradedReason;

  CourseDetails? get courseDetails => _courseDetails;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Exam types loaded from the narrow public endpoint, set only while
  /// [isDegraded]. Null in normal operation.
  CourseTypesResponse? get courseTypesOnly => _courseTypesOnly;

  /// True when the full admin tree failed and the screen is running on the
  /// course-types endpoint alone: exam types but no chapters or lessons, and
  /// published exam types only.
  bool get isDegraded => _degradedReason != null && _courseTypesOnly != null;

  /// What the full endpoint said, so the UI can show the real cause rather
  /// than a generic "couldn't load".
  String? get degradedReason => _degradedReason;

  Future<void> loadCourseDetails(int courseId) async {
    _isLoading = true;
    _errorMessage = null;
    _degradedReason = null;
    notifyListeners();

    try {
      _courseDetails = await _service.fetchCourseDetails(courseId);
      // Full tree is healthy again - drop any previous degraded state so the
      // screen returns to normal on its own once the backend is deployed.
      _courseTypesOnly = null;
    } catch (e) {
      final fullTreeError = e.toString().replaceFirst('Exception: ', '');

      // The full tree reads lessons and can fail on its own; the course-types
      // route doesn't, so it's worth one attempt before giving up entirely.
      try {
        _courseTypesOnly = await _service.fetchCourseTypes(courseId);
        _courseDetails = null;
        _degradedReason = fullTreeError;
        _errorMessage = null;
      } catch (_) {
        // Both reads failed - report the original error, which is the useful
        // one; the fallback's failure is a symptom, not the cause.
        _courseDetails = null;
        _courseTypesOnly = null;
        _errorMessage = fullTreeError;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
