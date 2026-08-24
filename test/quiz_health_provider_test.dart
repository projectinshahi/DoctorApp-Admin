import 'package:flutter_test/flutter_test.dart';

import 'package:admin_drapp/models/quiz_model.dart';
import 'package:admin_drapp/provider/quiz_health_provider.dart';
import 'package:admin_drapp/services/quiz_service.dart';

/// Serves a fixed list, and a per-id detail that may be missing (a detail call
/// that failed) - the case the screen has to render without erroring.
class _FakeQuizService extends QuizService {
  final List<Quiz> rows;
  final Map<int, Quiz> details;

  _FakeQuizService({required this.rows, this.details = const {}});

  @override
  Future<QuizListResult> list({
    int? subjectId,
    int? topicId,
    String? examTag,
    String? status = 'active',
  }) async =>
      QuizListResult.success(rows);

  @override
  Future<QuizResult> get(int quizId) async {
    final quiz = details[quizId];
    return quiz == null ? QuizResult.failure('boom') : QuizResult.success(quiz);
  }
}

Map<String, dynamic> _row(
  int id, {
  int? questionCount,
  Map<String, dynamic>? lesson,
  String status = 'active',
}) =>
    {
      'id': id,
      'title': 'Quiz $id',
      'subjectId': 7,
      'topicId': 2,
      'questionCount': questionCount,
      'status': status,
      'subject': {'id': 7, 'name': 'Internal Med'},
      'topic': {'id': 2, 'name': 'Pulmonology'},
      'lesson': lesson,
    };

Map<String, dynamic> _detail(
  int id, {
  int? questionCount,
  required int available,
  Map<String, dynamic>? lesson = const {'id': 1, 'title': 'L'},
}) =>
    {
      ..._row(id, questionCount: questionCount, lesson: lesson),
      'availableQuestions': available,
      'servedQuestions': questionCount == null ? available : (questionCount.clamp(0, available)),
      'isUnderfilled': questionCount != null && available < questionCount,
    };

void main() {
  test('a quiz with no lesson is orphaned regardless of its pool', () async {
    final provider = QuizHealthProvider(
      service: _FakeQuizService(
        rows: [Quiz.fromJson(_row(1, questionCount: 2, lesson: null))],
        details: {
          1: Quiz.fromJson(_detail(1, questionCount: 2, available: 10, lesson: null)),
        },
      ),
    );

    await provider.load();

    expect(provider.healthOf(provider.quizFor(1)), QuizHealth.orphaned);
    expect(provider.countOf(QuizHealth.orphaned), 1);
  });

  test('a linked quiz asking for more than it can serve is underfilled', () async {
    final provider = QuizHealthProvider(
      service: _FakeQuizService(
        rows: [Quiz.fromJson(_row(2, questionCount: 10, lesson: {'id': 1, 'title': 'L'}))],
        details: {2: Quiz.fromJson(_detail(2, questionCount: 10, available: 1))},
      ),
    );

    await provider.load();

    expect(provider.healthOf(provider.quizFor(2)), QuizHealth.underfilled);
    expect(provider.quizFor(2).servedQuestions, 1);
  });

  test('questionCount null means serve everything, never underfilled', () async {
    // The spec is explicit: a quiz with no count is never underfilled, and the
    // UI must not render "asks for null".
    final provider = QuizHealthProvider(
      service: _FakeQuizService(
        rows: [Quiz.fromJson(_row(3, lesson: {'id': 1, 'title': 'L'}))],
        details: {3: Quiz.fromJson(_detail(3, available: 4))},
      ),
    );

    await provider.load();

    expect(provider.quizFor(3).questionCount, isNull);
    expect(provider.quizFor(3).isUnderfilled, isFalse);
    expect(provider.healthOf(provider.quizFor(3)), QuizHealth.healthy);
  });

  test('a failed detail call leaves the row usable without pool counts', () async {
    final provider = QuizHealthProvider(
      service: _FakeQuizService(
        rows: [Quiz.fromJson(_row(4, questionCount: 5, lesson: {'id': 1, 'title': 'L'}))],
        details: const {}, // every detail call fails
      ),
    );

    await provider.load();

    expect(provider.errorMessage, isNull, reason: 'the list still loaded');
    expect(provider.quizzes, hasLength(1));
    expect(provider.hasPoolCounts(4), isFalse);
    expect(provider.healthOf(provider.quizFor(4)), QuizHealth.healthy,
        reason: 'unknown must not be reported as broken');
  });

  test('orphans sort ahead of underfilled, which sort ahead of healthy', () async {
    final provider = QuizHealthProvider(
      service: _FakeQuizService(
        rows: [
          Quiz.fromJson(_row(10, questionCount: 1, lesson: {'id': 1, 'title': 'L'})), // healthy
          Quiz.fromJson(_row(11, questionCount: 9, lesson: {'id': 1, 'title': 'L'})), // underfilled
          Quiz.fromJson(_row(12, questionCount: 1, lesson: null)),                    // orphan
        ],
        details: {
          10: Quiz.fromJson(_detail(10, questionCount: 1, available: 4)),
          11: Quiz.fromJson(_detail(11, questionCount: 9, available: 2)),
          12: Quiz.fromJson(_detail(12, questionCount: 1, available: 4, lesson: null)),
        },
      ),
    );

    await provider.load();

    expect(provider.quizzes.map((q) => q.id).toList(), [12, 11, 10]);
  });

  test('load() is safe when the provider is disposed mid-flight', () async {
    final provider = QuizHealthProvider(
      service: _FakeQuizService(
        rows: [Quiz.fromJson(_row(20, lesson: null))],
        details: {20: Quiz.fromJson(_detail(20, available: 1))},
      ),
    );

    final inFlight = provider.load();
    provider.dispose();

    await expectLater(inFlight, completes);
  });
}
