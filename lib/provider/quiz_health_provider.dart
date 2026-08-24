import 'package:flutter/foundation.dart';

import '../models/quiz_model.dart';
import '../services/quiz_service.dart';

/// How a quiz is failing, if it is. Ordered worst-first so the list can sort
/// on it directly.
enum QuizHealth {
  /// No lesson links to it, so no student can reach it at all.
  orphaned,

  /// Asks for more questions than its filter currently matches.
  underfilled,

  healthy,
}

/// Reads every quiz, then fills in the pool counts per row.
///
/// The list endpoint carries the orphan signal (`lesson`) but not the pool
/// counts - those only exist on GET /api/quizzes/:id. So the list renders
/// immediately and each row's counts resolve afterwards, rather than the whole
/// screen waiting on N detail calls.
class QuizHealthProvider extends ChangeNotifier {
  final QuizService _service;

  QuizHealthProvider({QuizService? service}) : _service = service ?? QuizService();

  /// Detail calls in flight at once. Nine quizzes today; this only matters if
  /// that grows, and it keeps a slow backend from seeing a burst.
  static const int _detailConcurrency = 4;

  bool isLoading = false;
  String? errorMessage;

  /// Rows from the list endpoint, in display order.
  List<Quiz> quizzes = [];

  /// Pool counts by quiz id, filled in as each detail call lands. A row absent
  /// here is still loading or its detail call failed - both render as "counts
  /// unavailable", never as an error.
  final Map<int, Quiz> _details = {};
  final Set<int> _detailsPending = {};

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

  /// The row as currently known: detail when it has landed, list row otherwise.
  Quiz quizFor(int id) =>
      _details[id] ?? quizzes.firstWhere((q) => q.id == id);

  bool hasPoolCounts(int id) => _details.containsKey(id);
  bool isPoolLoading(int id) => _detailsPending.contains(id);

  QuizHealth healthOf(Quiz quiz) {
    if (!quiz.isTaken) return QuizHealth.orphaned;
    // Underfill is only knowable once the detail call has landed.
    if (hasPoolCounts(quiz.id) && quizFor(quiz.id).isUnderfilled) {
      return QuizHealth.underfilled;
    }
    return QuizHealth.healthy;
  }

  int countOf(QuizHealth health) =>
      quizzes.where((q) => healthOf(quizFor(q.id)) == health).length;

  /// True once every row's pool counts have resolved - the totals in the
  /// summary are provisional until then.
  bool get isPoolComplete => _detailsPending.isEmpty && !isLoading;

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    _details.clear();
    _detailsPending.clear();
    notifyListeners();

    // Every quiz, not just the active ones: an inactive quiz still linked to a
    // lesson is exactly the kind of thing this screen exists to show.
    final result = await _service.list(status: null);

    isLoading = false;
    if (!result.isSuccess) {
      errorMessage = result.errorMessage;
      quizzes = [];
      notifyListeners();
      return;
    }

    quizzes = _sorted(result.quizzes ?? []);
    notifyListeners();

    await _loadPoolCounts();
  }

  /// Orphans first, then underfilled, then healthy - so the broken ones are
  /// visible without scrolling. Re-sorted as counts arrive, since underfill
  /// isn't known until then.
  List<Quiz> _sorted(List<Quiz> rows) {
    final sorted = [...rows];
    sorted.sort((a, b) {
      final byHealth = healthOf(_details[a.id] ?? a).index
          .compareTo(healthOf(_details[b.id] ?? b).index);
      if (byHealth != 0) return byHealth;
      return b.id.compareTo(a.id); // newest first within a group
    });
    return sorted;
  }

  Future<void> _loadPoolCounts() async {
    final queue = [...quizzes];
    _detailsPending.addAll(queue.map((q) => q.id));
    notifyListeners();

    Future<void> worker() async {
      while (queue.isNotEmpty && !_disposed) {
        final quiz = queue.removeAt(0);
        final result = await _service.get(quiz.id);

        if (_disposed) return;
        _detailsPending.remove(quiz.id);
        // A failed detail call leaves the row without counts. That is a
        // missing readout, not an error state - the row is still valid.
        if (result.isSuccess && result.quiz != null) {
          _details[quiz.id] = result.quiz!;
        }
        notifyListeners();
      }
    }

    await Future.wait(
      List.generate(_detailConcurrency.clamp(1, queue.length.clamp(1, 99)), (_) => worker()),
    );

    if (_disposed) return;
    quizzes = _sorted(quizzes);
    notifyListeners();
  }
}
