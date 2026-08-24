import 'package:flutter/material.dart';

import '../models/lesson_detail_model.dart';
import '../services/lesson_detail_service.dart';

class LessonDetailsProvider extends ChangeNotifier {
  final LessonDetailsService _service = LessonDetailsService();

  bool isLoading = false;
  String? errorMessage;
  LessonDetail? lesson;

  /// A request can outlive the widget that started it: the screen is popped
  /// while the load is still in flight, and the continuation notifies a
  /// provider that has already been disposed. ChangeNotifier throws on that,
  /// so the notification is dropped instead - nothing is listening anyway.
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

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