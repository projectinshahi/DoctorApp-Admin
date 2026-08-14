import 'package:flutter/foundation.dart';

import '../services/course_type_services.dart';

/// State/logic layer for creating or editing a single course type (exam type).
/// Keep this separate from CourseDetailsProvider so the "loading course
/// details" state and the "saving" state never collide in the UI.
class CourseTypeUpdateProvider extends ChangeNotifier {
  final CourseTypeService _service;

  CourseTypeUpdateProvider({CourseTypeService? service})
      : _service = service ?? CourseTypeService();

  bool isUpdating = false;
  bool isDeleting = false;
  String? errorMessage;

  Future<bool> createCourseType({
    required int courseId,
    required String title,
    required String status,
    String? description,
    String? accessType,
  }) async {
    isUpdating = true;
    errorMessage = null;
    notifyListeners();

    final result = await _service.createCourseType(
      courseId: courseId,
      title: title,
      status: status,
      description: description,
      accessType: accessType,
    );

    isUpdating = false;
    if (!result.isSuccess) {
      errorMessage = result.errorMessage;
    }
    notifyListeners();
    return result.isSuccess;
  }

  Future<bool> updateCourseType({
    required int courseId,
    required int courseTypeId,
    required String title,
    required String status,
    String? description,
    String? accessType,
  }) async {
    isUpdating = true;
    errorMessage = null;
    notifyListeners();

    final result = await _service.updateCourseType(
      courseId: courseId,
      courseTypeId: courseTypeId,
      title: title,
      status: status,
      description: description,
      accessType: accessType,
    );

    isUpdating = false;
    if (!result.isSuccess) {
      errorMessage = result.errorMessage;
    }
    notifyListeners();
    return result.isSuccess;
  }

  Future<bool> deleteCourseType({
    required int courseId,
    required int courseTypeId,
  }) async {
    isDeleting = true;
    errorMessage = null;
    notifyListeners();

    final result = await _service.deleteCourseType(
      courseId: courseId,
      courseTypeId: courseTypeId,
    );

    isDeleting = false;
    if (!result.isSuccess) {
      errorMessage = result.errorMessage;
    }
    notifyListeners();
    return result.isSuccess;
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }
}