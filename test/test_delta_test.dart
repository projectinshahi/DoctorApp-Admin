import 'package:flutter_test/flutter_test.dart';

import 'package:admin_drapp/models/admin_test_model.dart';
import 'package:admin_drapp/models/test_results_model.dart';

void main() {
  group('sections are derived from question labels', () {
    final preview = TestPreview.fromJson({
      'sections': [
        {'name': 'Part A', 'questionCount': 2, 'firstOrder': 1,
         'lastOrder': 2, 'contiguous': true},
        {'name': 'Part B', 'questionCount': 2, 'firstOrder': 3,
         'lastOrder': 6, 'contiguous': false},
      ],
      'unsectionedCount': 1,
      'questions': [
        {'id': 1, 'questionText': 'Q1', 'correctOption': 'A',
         'section': 'Part A', 'questionOrder': 1,
         'options': ['a', 'b']},
      ],
    });

    test('reads the section rollups', () {
      expect(preview.sections.length, 2);
      expect(preview.sectionNames, ['Part A', 'Part B']);
      expect(preview.sections[1].contiguous, isFalse);
    });

    test('a half-labelled paper is flagged', () {
      // Questions outside every part are invisible until a student sees them.
      expect(preview.isPartlySectioned, isTrue);
    });

    test('no sections at all is normal, not half-labelled', () {
      final flat = TestPreview.fromJson({
        'unsectionedCount': 40,
        'questions': const [],
      });
      expect(flat.sections, isEmpty);
      expect(flat.isPartlySectioned, isFalse);
    });

    test('questions carry their section and order', () {
      final q = preview.questions.single;
      expect(q.section, 'Part A');
      expect(q.questionOrder, 1);
    });
  });

  group('live attempts', () {
    InProgressAttempt parse(Map<String, dynamic> json) =>
        InProgressAttempt.fromJson({
          'attemptId': 6,
          'student': {'id': 30, 'name': 'Keerthana Bineesh'},
          'test': {'id': 10, 'name': 'test 1', 'totalQuestions': 10,
                   'durationMinutes': 30},
          'answeredCount': 1,
          'remainingCount': 9,
          ...json,
        });

    test('reads the documented shape', () {
      final a = parse({'secondsRemaining': 1524, 'expired': false});
      expect(a.attemptId, 6);
      expect(a.studentName, 'Keerthana Bineesh');
      expect(a.testName, 'test 1');
      expect(a.expired, isFalse);
      expect(a.answeredFraction, closeTo(0.1, 0.001));
    });

    test('the clock comes from the deadline, not the stale count', () {
      final now = DateTime.utc(2026, 9, 1, 12, 0, 0);
      final a = parse({
        'secondsRemaining': 1524,
        'deadlineAt': now.add(const Duration(seconds: 90)).toIso8601String(),
      });
      // A long gap between refetches must not leave the clock lying.
      expect(a.remainingAt(now), 90);
      expect(a.remainingAt(now.add(const Duration(minutes: 5))), 0);
    });

    test('formats mm:ss and only shows hours when there are any', () {
      expect(InProgressAttempt.clock(1524), '25:24');
      expect(InProgressAttempt.clock(59), '00:59');
      expect(InProgressAttempt.clock(0), '00:00');
      expect(InProgressAttempt.clock(-5), '00:00');
      expect(InProgressAttempt.clock(3661), '1:01:01');
    });

    test('no total means no progress fraction', () {
      // An invented denominator would be worse than no bar at all.
      final a = InProgressAttempt.fromJson({
        'attemptId': 1,
        'test': {'id': 1, 'name': 'x'},
        'answeredCount': 3,
      });
      expect(a.answeredFraction, isNull);
    });
  });

  group('leaderboard', () {
    test('renders the server rank, never a row index', () {
      // Ties share a rank and the next one skips: 1, 2, 2, 4.
      final rows = [
        {'rank': 1, 'student': {'name': 'A'}, 'score': 10},
        {'rank': 2, 'student': {'name': 'B'}, 'score': 8},
        {'rank': 2, 'student': {'name': 'C'}, 'score': 8},
        {'rank': 4, 'student': {'name': 'D'}, 'score': 5},
      ];
      final parsed = [
        for (var i = 0; i < rows.length; i++)
          LeaderboardRow.fromJson(rows[i], i + 1),
      ];

      expect(parsed.map((r) => r.rank).toList(), [1, 2, 2, 4]);
    });

    test('scores can be negative', () {
      final row = LeaderboardRow.fromJson(
          {'rank': 9, 'student': {'name': 'E'}, 'score': -2.5, 'maxScore': 40},
          9);
      expect(row.score, -2.5);
      expect(row.scoreLabel, '-2.5 / 40');
    });

    test('stats keep median beside average', () {
      final stats = LeaderboardStats.fromJson(
          {'highest': 2, 'lowest': 1, 'average': 1.5, 'median': 1.5,
           'fastestSeconds': 8});
      expect(stats.median, 1.5);
      expect(stats.fastestSeconds, 8);
      expect(stats.isEmpty, isFalse);
      expect(const LeaderboardStats().isEmpty, isTrue);
    });
  });

  test('attempts read skippedCount and timeTakenSeconds', () {
    final a = TestAttempt.fromJson({
      'id': 1,
      'student': {'name': 'A'},
      'score': 7,
      'maxScore': 10,
      'correctCount': 7,
      'wrongCount': 2,
      'skippedCount': 1,
      'timeTakenSeconds': 843,
      'status': 'submitted',
    });

    expect(a.skippedCount, 1);
    expect(a.timeTakenSeconds, 843);
    expect(a.percent, 70);
  });

  test('test type rides in both payloads', () {
    final t = AdminTest.fromJson({
      'id': 1,
      'name': 'Grand Test',
      'courseId': 22,
      'type': 'mock',
      'totalQuestions': 10,
      'questionCount': 10,
    });

    expect(t.type, 'mock');
    expect(t.toCreatePayload()['type'], 'mock');
    expect(t.toUpdatePayload()['type'], 'mock');

    // Frozen once anyone has started.
    final locked = AdminTest.fromJson({
      'id': 1, 'name': 'Grand Test', 'courseId': 22, 'type': 'mock',
      'totalQuestions': 10, 'questionCount': 10, 'attemptCount': 1,
    });
    expect(locked.toUpdatePayload().containsKey('type'), isFalse);
    expect(locked.toUpdatePayload()['name'], 'Grand Test');
  });
}
