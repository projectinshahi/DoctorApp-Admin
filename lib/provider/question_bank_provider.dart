import 'package:flutter/foundation.dart';

import '../models/question_bank_model.dart';
import '../services/question_bank_service.dart';
import '../services/subject_topic_service.dart';

/// Holds the filter state, the loaded page, and the bulk-mode selection.
///
/// Split from QuestionUpdateProvider on purpose - the same reason
/// ChapterUpdateProvider is separate from CourseDetailsProvider: "loading the
/// list" and "saving a question" are different states and shouldn't collide.
class QuestionListProvider extends ChangeNotifier {
  final QuestionBankService _service;

  QuestionListProvider({QuestionBankService? service})
      : _service = service ?? QuestionBankService();

  bool isLoading = false;
  String? errorMessage;

  List<Question> questions = [];
  int total = 0;
  int page = 1;
  int limit = 20;

  // ── Filters (all combine into one query) ───────────────────────────
  int? subjectId;
  int? topicId;
  Difficulty? difficulty;
  QuestionStatus? status;
  String? tag;
  String? search;
  String? sort;

  /// Ids ticked for bulk mode.
  final Set<int> selectedIds = {};

  int get totalPages => limit <= 0 ? 1 : (total / limit).ceil().clamp(1, 1 << 30);
  bool get hasPrevPage => page > 1;
  bool get hasNextPage => page < totalPages;

  bool get hasFilters =>
      subjectId != null ||
      topicId != null ||
      difficulty != null ||
      status != null ||
      (tag?.isNotEmpty ?? false) ||
      (search?.isNotEmpty ?? false) ||
      (sort?.isNotEmpty ?? false);

  /// Rebuilds the query from whatever the filters currently hold.
  Future<bool> fetchQuestions() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    final result = await _service.getQuestions(
      subjectId: subjectId,
      topicId: topicId,
      difficulty: difficulty,
      status: status,
      tag: tag,
      search: search,
      sort: sort,
      page: page,
      limit: limit,
    );

    isLoading = false;
    if (result.isSuccess) {
      final loaded = result.page!;
      questions = loaded.questions;
      total = loaded.total;
      limit = loaded.limit;

      // Deleting the last row on the last page would otherwise strand the
      // admin on an empty page.
      if (questions.isEmpty && loaded.page > 1) {
        page = loaded.page - 1;
        return fetchQuestions();
      }
      page = loaded.page;
      selectedIds.retainAll(questions.map((q) => q.id).toSet());
    } else {
      errorMessage = result.errorMessage;
    }
    notifyListeners();
    return result.isSuccess;
  }

  /// Any filter change resets to page 1 - staying on page 7 of a brand new
  /// query is how you end up staring at a blank list.
  Future<bool> applyFilters({
    int? subjectId,
    int? topicId,
    Difficulty? difficulty,
    QuestionStatus? status,
    String? tag,
    String? search,
    String? sort,
    bool clearSubject = false,
    bool clearTopic = false,
    bool clearDifficulty = false,
    bool clearStatus = false,
    bool clearSort = false,
  }) {
    if (clearSubject) {
      this.subjectId = null;
      this.topicId = null; // a topic only means something inside its subject
    } else if (subjectId != null) {
      if (subjectId != this.subjectId) this.topicId = null;
      this.subjectId = subjectId;
    }

    if (clearTopic) {
      this.topicId = null;
    } else if (topicId != null) {
      this.topicId = topicId;
    }

    if (clearDifficulty) {
      this.difficulty = null;
    } else if (difficulty != null) {
      this.difficulty = difficulty;
    }

    if (clearStatus) {
      this.status = null;
    } else if (status != null) {
      this.status = status;
    }

    if (clearSort) {
      this.sort = null;
    } else if (sort != null) {
      this.sort = sort;
    }

    if (tag != null) this.tag = tag.trim().isEmpty ? null : tag.trim();
    if (search != null) this.search = search.trim().isEmpty ? null : search.trim();

    page = 1;
    return fetchQuestions();
  }

  Future<bool> clearFilters() {
    subjectId = null;
    topicId = null;
    difficulty = null;
    status = null;
    tag = null;
    search = null;
    sort = null;
    page = 1;
    return fetchQuestions();
  }

  Future<bool> goToPage(int next) {
    if (next < 1 || next > totalPages || next == page) return Future.value(true);
    page = next;
    return fetchQuestions();
  }

  // ── Bulk selection ─────────────────────────────────────────────────

  void toggleSelected(int questionId) {
    selectedIds.contains(questionId)
        ? selectedIds.remove(questionId)
        : selectedIds.add(questionId);
    notifyListeners();
  }

  /// Select-all is scoped to the current page - the ids off-page aren't
  /// loaded, so "all" can only honestly mean "all of these".
  void selectAll() {
    final pageIds = questions.map((q) => q.id).toSet();
    if (pageIds.isNotEmpty && selectedIds.containsAll(pageIds)) {
      selectedIds.removeAll(pageIds);
    } else {
      selectedIds.addAll(pageIds);
    }
    notifyListeners();
  }

  bool get isPageFullySelected {
    final pageIds = questions.map((q) => q.id).toSet();
    return pageIds.isNotEmpty && selectedIds.containsAll(pageIds);
  }

  void clearSelection() {
    selectedIds.clear();
    notifyListeners();
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }
}

/// Writes only. Same isUpdating / isDeleting / errorMessage / clearError
/// shape as ChapterUpdateProvider; the screen calls _refresh() afterwards
/// rather than the provider reloading a list it doesn't own.
class QuestionUpdateProvider extends ChangeNotifier {
  final QuestionBankService _service;

  QuestionUpdateProvider({QuestionBankService? service})
      : _service = service ?? QuestionBankService();

  bool isUpdating = false;
  bool isDeleting = false;
  String? errorMessage;

  /// Creates the question, then applies [status] through the dedicated
  /// status endpoint if it isn't the server's default. The create payload
  /// itself carries no status field - PATCH /questions/:id/status is the
  /// only documented way to set it.
  Future<bool> createQuestion(Question question) async {
    isUpdating = true;
    errorMessage = null;
    notifyListeners();

    final result = await _service.createQuestion(question);
    final ok = await _applyStatusIfNeeded(result, question.status);

    isUpdating = false;
    if (!ok) errorMessage ??= result.errorMessage;
    notifyListeners();
    return ok;
  }

  Future<bool> updateQuestion(int questionId, Question question) async {
    isUpdating = true;
    errorMessage = null;
    notifyListeners();

    final result = await _service.updateQuestion(questionId, question);
    bool ok = result.isSuccess;

    if (ok && (result.question?.status ?? QuestionStatus.active) != question.status) {
      final statusResult = await _service.updateStatus(questionId, question.status);
      ok = statusResult.isSuccess;
      if (!ok) errorMessage = statusResult.errorMessage;
    }

    isUpdating = false;
    if (!ok) errorMessage ??= result.errorMessage;
    notifyListeners();
    return ok;
  }

  Future<bool> _applyStatusIfNeeded(QuestionResult result, QuestionStatus wanted) async {
    if (!result.isSuccess) return false;

    final created = result.question;
    if (created == null || created.status == wanted) return true;

    final statusResult = await _service.updateStatus(created.id, wanted);
    if (!statusResult.isSuccess) errorMessage = statusResult.errorMessage;
    return statusResult.isSuccess;
  }

  /// How many quiz pools shrank on the last successful delete. Null when the
  /// backend didn't say.
  int? lastAffectedQuizzes;

  /// Deletion cascades the question's options and tags and cannot be undone.
  /// A 409 message lands in [errorMessage] untouched so the UI shows it.
  Future<bool> deleteQuestion(int questionId) async {
    isDeleting = true;
    errorMessage = null;
    lastAffectedQuizzes = null;
    notifyListeners();

    final result = await _service.deleteQuestion(questionId);

    isDeleting = false;
    if (result.isSuccess) {
      lastAffectedQuizzes = result.affectedQuizzes;
    } else {
      errorMessage = result.errorMessage;
    }
    notifyListeners();
    return result.isSuccess;
  }

  Future<bool> updateStatus(int questionId, QuestionStatus status) =>
      _write(() => _service.updateStatus(questionId, status));

  Future<bool> bulkUpdateStatus(List<int> questionIds, QuestionStatus status) =>
      _write(() => _service.bulkUpdateStatus(questionIds, status));

  Future<bool> duplicateQuestion(int questionId) =>
      _write(() => _service.duplicateQuestion(questionId));

  Future<bool> _write(Future<QuestionResult> Function() call) async {
    isUpdating = true;
    errorMessage = null;
    notifyListeners();

    final result = await call();

    isUpdating = false;
    if (!result.isSuccess) errorMessage = result.errorMessage;
    notifyListeners();
    return result.isSuccess;
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }
}

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
