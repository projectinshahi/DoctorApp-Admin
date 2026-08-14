import 'package:flutter/foundation.dart';

import '../services/chapter_services.dart';

/// State/logic layer for creating, renaming, or deleting a single chapter
/// (syllabus item) under a course type. Same split-provider pattern as
/// CourseTypeUpdateProvider - kept separate from CourseDetailsProvider so
/// "loading the course" and "saving a chapter" states never collide.
class ChapterUpdateProvider extends ChangeNotifier {
  final ChapterService _service;

  ChapterUpdateProvider({ChapterService? service}) : _service = service ?? ChapterService();

  bool isUpdating = false;
  bool isDeleting = false;
  String? errorMessage;

  Future<bool> createChapter({
    required int courseTypeId,
    required String title,
    int? displayOrder,
  }) async {
    isUpdating = true;
    errorMessage = null;
    notifyListeners();

    final result = await _service.createChapter(
      courseTypeId: courseTypeId,
      title: title,
      displayOrder: displayOrder,
    );

    isUpdating = false;
    if (!result.isSuccess) {
      errorMessage = result.errorMessage;
    }
    notifyListeners();
    return result.isSuccess;
  }

  Future<bool> updateChapter({
    required int courseTypeId,
    required int chapterId,
    String? title,
    int? displayOrder,
  }) async {
    isUpdating = true;
    errorMessage = null;
    notifyListeners();

    final result = await _service.updateChapter(
      courseTypeId: courseTypeId,
      chapterId: chapterId,
      title: title,
      displayOrder: displayOrder,
    );

    isUpdating = false;
    if (!result.isSuccess) {
      errorMessage = result.errorMessage;
    }
    notifyListeners();
    return result.isSuccess;
  }

  Future<bool> deleteChapter({
    required int courseTypeId,
    required int chapterId,
  }) async {
    isDeleting = true;
    errorMessage = null;
    notifyListeners();

    final result = await _service.deleteChapter(
      courseTypeId: courseTypeId,
      chapterId: chapterId,
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