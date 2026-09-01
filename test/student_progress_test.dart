import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin_drapp/models/student_progress_model.dart';

/// The real payload from GET /admin/students/:id, trimmed to the parts the
/// screen reads.
const _payload = '''
{
  "id": 7,
  "email": "a@b.com",
  "progress": {
    "lessons": { "total": 6, "completed": 4, "remaining": 2, "percent": 67 },
    "videos":  { "total": 3, "completed": 2, "inProgress": 1, "percent": 67 },
    "notes":   { "total": 1, "completed": 0, "percent": 0 },
    "quizzes": { "total": 2, "attempted": 2, "completed": 2, "remaining": 0, "percent": 100 },
    "qbank":   { "attempted": 5, "correct": 2, "wrong": 3, "accuracy": 40 },
    "tests":   { "attempted": 2, "submitted": 1, "bestScore": 1 },
    "bookmarks": { "questions": 0, "lessons": 1 },
    "lastActivityAt": "2026-08-31T05:32:46.967Z"
  },
  "chapters": [
    {
      "id": 3,
      "title": "Internal Medicine",
      "total": 2,
      "completed": 2,
      "percent": 100,
      "lessons": [
        { "id": 10, "title": "Cardio", "completed": true, "visibleToStudent": true },
        { "id": 11, "title": "Renal", "completed": true, "visibleToStudent": false }
      ]
    }
  ],
  "recentQuizAttempts": [
    { "id": 1, "quizTitle": "Cardio quiz", "score": 7, "total": 10, "percent": 70,
      "attemptedAt": "2026-08-30T10:00:00.000Z" }
  ],
  "recentTestAttempts": [
    { "id": 2, "testTitle": "Mock 1", "score": 1, "status": "submitted",
      "submittedAt": "2026-08-29T09:00:00.000Z" }
  ]
}
''';

void main() {
  final detail =
      StudentDetail.fromJson(jsonDecode(_payload) as Map<String, dynamic>);

  test('reads every progress block off the real payload', () {
    final p = detail.progress;
    expect(p.lessons['total'], 6);
    expect(p.lessons['remaining'], 2);
    expect(p.lessons['percent'], 67);
    expect(p.videos['inProgress'], 1);
    expect(p.qbank['accuracy'], 40);
    expect(p.tests['bestScore'], 1);
    expect(p.bookmarks['lessons'], 1);
    expect(p.hasAnyActivity, isTrue);
  });

  test('a missing counter is null, not zero', () {
    // "no videos on this course" must not render the same as "0 of 3 watched".
    expect(detail.progress.notes['inProgress'], isNull);
    expect(detail.progress.notes['completed'], 0);
    expect(ProgressBlock.fromJson(null).isEmpty, isTrue);
  });

  test('completed + not visible is completed AND locked', () {
    final lessons = detail.chapters.single.lessons;
    expect(lessons[0].completed, isTrue);
    expect(lessons[0].isCompletedButLocked, isFalse);
    expect(lessons[1].completed, isTrue);
    expect(lessons[1].visibleToStudent, isFalse);
    expect(lessons[1].isCompletedButLocked, isTrue);
  });

  test('chapter rollups are the server\'s, not recomputed', () {
    final chapter = detail.chapters.single;
    expect(chapter.percent, 100);
    expect(chapter.total, 2);
    // Drafts are excluded from the API totals, so lessons.length is NOT the
    // denominator - it just happens to match here.
    expect(detail.progress.lessons['total'], isNot(chapter.lessons.length));
  });

  test('attempt rows read either naming', () {
    expect(detail.recentQuizAttempts.single.title, 'Cardio quiz');
    expect(detail.recentQuizAttempts.single.scoreLabel, '7 / 10');
    expect(detail.recentQuizAttempts.single.percent, 70);
    expect(detail.recentTestAttempts.single.title, 'Mock 1');
    expect(detail.recentTestAttempts.single.scoreLabel, '1');
    expect(detail.recentTestAttempts.single.at, isNotNull);
  });

  test('percent is derived when the API omits it', () {
    final a = AttemptSummary.fromJson({
      'id': 9,
      'quiz': {'title': 'Renal quiz'},
      'marksObtained': 3,
      'totalQuestions': 8,
      'completedAt': '2026-08-28T08:00:00.000Z',
    });

    expect(a.title, 'Renal quiz');
    expect(a.scoreLabel, '3 / 8');
    expect(a.percent, 38); // 37.5 rounded
    expect(a.at, isNotNull);
  });

  test('a reported percent wins over the derived one', () {
    final a = AttemptSummary.fromJson({
      'id': 10,
      'title': 'Curved paper',
      'score': 3,
      'total': 8,
      'percentage': 50,
    });

    expect(a.percent, 50);
  });

  test('percent is null when there is nothing to derive it from', () {
    final a = AttemptSummary.fromJson({'id': 11, 'title': 'Unscored'});
    expect(a.percent, isNull);
    expect(a.scoreLabel, isNull);

    // A zero denominator must not divide.
    final zero = AttemptSummary.fromJson({'id': 12, 'score': 0, 'total': 0});
    expect(zero.percent, isNull);
  });

  test('history is only flagged as capped at 20', () {
    expect(detail.historyIsCapped, isFalse);

    final capped = StudentDetail(
      progress: const StudentProgress(),
      recentQuizAttempts: List.generate(
          20, (i) => AttemptSummary(id: i, title: 'Q$i')),
    );
    expect(capped.historyIsCapped, isTrue);
  });

  test('survives a payload nested under data', () {
    final nested = StudentDetail.fromJson({
      'data': jsonDecode(_payload) as Map<String, dynamic>,
    });
    expect(nested.progress.lessons['percent'], 67);
    expect(nested.chapters.single.title, 'Internal Medicine');
  });

  test('an attempt is in progress only when its status says so', () {
    bool open(String? status) =>
        AttemptSummary.fromJson({'id': 1, 'status': status}).isInProgress;

    expect(open('in_progress'), isTrue);
    expect(open('IN PROGRESS'), isTrue);
    expect(open('started'), isTrue);
    expect(open('pending'), isTrue);
    // Unknown counts as finished: showing a submitted attempt as still open
    // suggests work the student owes that they do not.
    expect(open(null), isFalse);
    expect(open('submitted'), isFalse);
    expect(open('completed'), isFalse);
  });

  test('chapter lessons split by completion', () {
    final chapter = detail.chapters.single;
    expect(chapter.completedLessons.length, 2);
    expect(chapter.pendingLessons, isEmpty);

    final mixed = ChapterProgress.fromJson({
      'id': 1,
      'title': 'Mixed',
      'total': 2,
      'completed': 1,
      'percent': 50,
      'lessons': [
        {'id': 1, 'title': 'Done', 'completed': true},
        {'id': 2, 'title': 'Open', 'completed': false},
      ],
    });
    expect(mixed.completedLessons.single.title, 'Done');
    expect(mixed.pendingLessons.single.title, 'Open');
  });

  test('finds the arrays under their alternate names', () {
    final alt = StudentDetail.fromJson({
      'id': 7,
      'progress': {
        'lessons': {'total': 2, 'completed': 1, 'percent': 50},
      },
      'quizAttempts': [
        {'id': 1, 'title': 'Alt quiz', 'score': 4, 'total': 5},
      ],
      'testAttempts': [
        {'id': 2, 'title': 'Alt test', 'score': 1},
      ],
      'chapterProgress': [
        {'id': 1, 'title': 'Alt chapter', 'total': 1, 'completed': 1,
         'percent': 100},
      ],
    });

    expect(alt.recentQuizAttempts.single.title, 'Alt quiz');
    expect(alt.recentQuizAttempts.single.percent, 80);
    expect(alt.recentTestAttempts.single.title, 'Alt test');
    expect(alt.chapters.single.title, 'Alt chapter');
  });

  test('finds arrays nested inside progress', () {
    final nested = StudentDetail.fromJson({
      'progress': {
        'lessons': {'total': 1, 'completed': 1, 'percent': 100},
        'recentQuizAttempts': [
          {'id': 3, 'title': 'Nested quiz', 'score': 2, 'total': 4},
        ],
      },
    });

    expect(nested.recentQuizAttempts.single.title, 'Nested quiz');
    expect(nested.recentQuizAttempts.single.percent, 50);
  });

  group('test leaderboard on a student attempt', () {
    test('reads rank, participants and best score', () {
      final a = AttemptSummary.fromJson({
        'id': 1,
        'testTitle': 'Grand Test 1',
        'score': 2,
        'total': 10,
        'leaderboard': {'rank': 3, 'totalParticipants': 24, 'bestScore': 2},
      });

      expect(a.leaderboard, isNotNull);
      expect(a.leaderboard!.placeLabel, '3rd of 24');
      expect(a.leaderboard!.bestScore, 2);
    });

    test('is null while the attempt is still running', () {
      // Absent is information - the ranking does not exist yet.
      final a = AttemptSummary.fromJson({'id': 2, 'title': 'Live'});
      expect(a.leaderboard, isNull);

      final empty = AttemptSummary.fromJson({'id': 3, 'leaderboard': {}});
      expect(empty.leaderboard, isNull);
    });

    test('ordinals handle the teens', () {
      String place(int rank) => AttemptLeaderboard(rank: rank).placeLabel!;

      expect(place(1), '1st');
      expect(place(2), '2nd');
      expect(place(3), '3rd');
      expect(place(4), '4th');
      // The naive rule gets these wrong.
      expect(place(11), '11th');
      expect(place(12), '12th');
      expect(place(13), '13th');
      expect(place(21), '21st');
      expect(place(112), '112th');
    });
  });

  test('survives a payload with no progress at all', () {
    final bare = StudentDetail.fromJson({'id': 1});
    expect(bare.progress.lessons.isEmpty, isTrue);
    expect(bare.progress.hasAnyActivity, isFalse);
    expect(bare.chapters, isEmpty);
  });
}
