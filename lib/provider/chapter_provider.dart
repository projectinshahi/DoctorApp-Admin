import 'package:flutter/foundation.dart';

import '../models/chapter_summary_model.dart';
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
/// Read side: the chapters (syllabus) of ONE course type.
///
/// One instance per exam-type card, so each card tracks its own load state and
/// two cards expanding at once never overwrite each other. The raw response is
/// printed to the terminal by ChapterService.getChapters.
class ChapterListProvider extends ChangeNotifier {
  final ChapterService _service;

  ChapterListProvider({ChapterService? service}) : _service = service ?? ChapterService();

  bool isLoading = false;
  String? errorMessage;
  List<ChapterSummary> chapters = [];

  /// False until the first response lands - lets the UI keep showing the
  /// count from the course-types list instead of a premature "0 syllabus".
  bool loadedOnce = false;

  Future<void> load(int courseTypeId) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    final result = await _service.getChapters(courseTypeId: courseTypeId);

    isLoading = false;
    loadedOnce = true;
    if (result.isSuccess) {
      chapters = result.chapters ?? [];
    } else {
      errorMessage = result.errorMessage;
    }
    notifyListeners();
  }
}
