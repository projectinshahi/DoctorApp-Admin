import 'package:flutter/foundation.dart';

import '../models/question_bank_model.dart';
import '../services/subject_topic_service.dart';

/// Subjects, plus the topics of whichever subject is currently selected.
class SubjectTopicProvider extends ChangeNotifier {
  final SubjectTopicService _service;

  SubjectTopicProvider({SubjectTopicService? service})
      : _service = service ?? SubjectTopicService();

  bool isLoading = false;
  bool isUpdating = false;
  String? errorMessage;

  List<Subject> subjects = [];

  /// Which subject [topics] belongs to. Null means nothing is loaded, which
  /// is not the same as loaded-and-empty.
  int? loadedSubjectId;
  List<Topic> topics = [];

  Map<int, String> get subjectNamesById => {for (final s in subjects) s.id: s.name};
  Map<int, String> get topicNamesById => {for (final t in topics) t.id: t.name};

  Future<bool> loadSubjects({bool? isActive = true}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    final result = await _service.getSubjects(isActive: isActive);

    isLoading = false;
    if (result.isSuccess) {
      subjects = result.subjects ?? [];
    } else {
      errorMessage = result.errorMessage;
    }
    notifyListeners();
    return result.isSuccess;
  }

  Future<bool> loadTopics({required int subjectId, bool? isActive = true}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    final result = await _service.getTopics(subjectId: subjectId, isActive: isActive);

    isLoading = false;
    if (result.isSuccess) {
      loadedSubjectId = subjectId;
      topics = result.topics ?? [];
    } else {
      errorMessage = result.errorMessage;
    }
    notifyListeners();
    return result.isSuccess;
  }

  /// Dropped whenever the subject selection changes, so a stale topic can't
  /// survive into the next subject's filter.
  void clearTopics() {
    loadedSubjectId = null;
    topics = [];
    notifyListeners();
  }

  Future<bool> createSubject({required String name}) =>
      _write(() => _service.createSubject(name: name).then((r) => (r.isSuccess, r.errorMessage)));

  Future<bool> updateSubject({required int subjectId, String? name, bool? isActive}) =>
      _write(() => _service
          .updateSubject(subjectId: subjectId, name: name, isActive: isActive)
          .then((r) => (r.isSuccess, r.errorMessage)));

  Future<bool> createTopic({required int subjectId, required String name}) =>
      _write(() => _service
          .createTopic(subjectId: subjectId, name: name)
          .then((r) => (r.isSuccess, r.errorMessage)));

  Future<bool> updateTopic({required int topicId, String? name, bool? isActive}) =>
      _write(() => _service
          .updateTopic(topicId: topicId, name: name, isActive: isActive)
          .then((r) => (r.isSuccess, r.errorMessage)));

  Future<bool> _write(Future<(bool, String?)> Function() call) async {
    isUpdating = true;
    errorMessage = null;
    notifyListeners();

    final (ok, message) = await call();

    isUpdating = false;
    if (!ok) errorMessage = message;
    notifyListeners();
    return ok;
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }
}
