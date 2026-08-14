import 'package:flutter/material.dart';

import '../models/lesson_detail_model.dart';
import '../services/lesson_detail_service.dart';

class LessonDetailsProvider extends ChangeNotifier {
  final LessonDetailsService _service = LessonDetailsService();

  bool isLoading = false;
  String? errorMessage;
  LessonDetail? lesson;

  Future<void> loadLesson(int lessonId, {bool includeChapter = false}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    final result = await _service.getLesson(lessonId: lessonId, includeChapter: includeChapter);

    isLoading = false;
    if (result.isSuccess) {
      lesson = result.lesson;
    } else {
      errorMessage = result.errorMessage;
    }
    notifyListeners();
  }
}