import 'package:flutter/cupertino.dart';
import '../models/panal_model.dart';

import '../models/Course_model.dart';
import '../models/course_details_model.dart'; // adjust path to wherever CourseDetails/CourseDetailsResponse live
import '../services/course_Services.dart';

class CourseProvider extends ChangeNotifier {
  final CourseService _courseService = CourseService();

  bool _isLoading = false;
  String? _errorMessage;
  CourseModel? _createdCourse;

  bool _isUpdating = false;
  String? _updateErrorMessage;
  CourseDetails? _updatedCourse;

  bool _isDeleting = false;
  String? _deleteErrorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  CourseModel? get createdCourse => _createdCourse;

  bool get isUpdating => _isUpdating;
  String? get updateErrorMessage => _updateErrorMessage;
  CourseDetails? get updatedCourse => _updatedCourse;

  bool get isDeleting => _isDeleting;
  String? get deleteErrorMessage => _deleteErrorMessage;

  Future<bool> createCourse({
    required String title,
    required String status,
    String? description,
    String? thumbnail,
    String? classGrade,
    String? difficulty,
    String accessType = 'free',
    int displayOrder = 0,
    List<CourseTypeModel> courseTypes = const [],
    List<AdminPlanModel> plans = const [],
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final course = await _courseService.createCourse(
        title: title,
        status: status,
        description: description,
        thumbnail: thumbnail,
        classGrade: classGrade,
        difficulty: difficulty,
        accessType: accessType,
        displayOrder: displayOrder,
        courseTypes: courseTypes,
        plans: plans,
      );

      _createdCourse = course;
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

  Future<bool> updateCourse({
    required int courseId,
    String? title,
    String? description,
    String? thumbnail,
    String? classGrade,
    String? difficulty,
    String? accessType,
    int? displayOrder,
    String? status,
    List<String>? subjectNames,
  }) async {
    _isUpdating = true;
    _updateErrorMessage = null;
    notifyListeners();

    try {
      final course = await _courseService.updateCourse(
        courseId: courseId,
        title: title,
        description: description,
        thumbnail: thumbnail,
        classGrade: classGrade,
        difficulty: difficulty,
        accessType: accessType,
        displayOrder: displayOrder,
        status: status,
        subjectNames: subjectNames,
      );

      _updatedCourse = course;
      _isUpdating = false;
      notifyListeners();

      return true;
    } catch (e) {
      _updateErrorMessage = e.toString().replaceFirst('Exception: ', '');
      _isUpdating = false;
      notifyListeners();

      return false;
    }
  }

  Future<bool> deleteCourse({required int courseId}) async {
    _isDeleting = true;
    _deleteErrorMessage = null;
    notifyListeners();

    try {
      await _courseService.deleteCourse(courseId: courseId);

      _isDeleting = false;
      notifyListeners();

      return true;
    } catch (e) {
      _deleteErrorMessage = e.toString().replaceFirst('Exception: ', '');
      _isDeleting = false;
      notifyListeners();

      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    _updateErrorMessage = null;
    _deleteErrorMessage = null;
    notifyListeners();
  }

  void reset() {
    _isLoading = false;
    _errorMessage = null;
    _createdCourse = null;

    _isUpdating = false;
    _updateErrorMessage = null;
    _updatedCourse = null;

    _isDeleting = false;
    _deleteErrorMessage = null;

    notifyListeners();
  }
}