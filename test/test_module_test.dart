import 'package:flutter_test/flutter_test.dart';

import 'package:admin_drapp/models/admin_test_model.dart';
import 'package:admin_drapp/models/test_results_model.dart';

/// The two locks and the expiry rule are where a wrong default does real
/// damage: one lets an admin rescore a sat paper, the other reports candidates
/// who left hours ago as still in the room.
void main() {
  AdminTest paper({int attempts = 0, bool locked = false}) => AdminTest.fromJson({
        'id': 1,
        'name': 'Grand Test 1',
        'courseId': 22,
        'courseTypeId': 20,
        'instructions': 'No going back.',
        'totalQuestions': 200,
        'questionCount': 200,
        'marksCorrect': 4,
        'marksIncorrect': -1,
        'durationMinutes': 180,
        'attemptCount': attempts,
        'isLocked': locked,
      });

  group('the two locks', () {
    test('a fresh test edits everything', () {
      final t = paper();
      expect(t.canEditScoring, isTrue);
      expect(t.canEditContent, isTrue);
      expect(t.scoringLockReason, isNull);
    });

    test('a started attempt freezes scoring but not content', () {
      final t = paper(attempts: 3);
      expect(t.canEditScoring, isFalse);
      expect(t.canEditContent, isTrue);
      expect(t.scoringLockReason, contains('3 student attempts have started'));
    });

    test('a submitted attempt freezes content', () {
      final t = paper(attempts: 3, locked: true);
      expect(t.canEditContent, isFalse);
      expect(t.contentLockReason, contains('already submitted'));
    });
  });

  group('the update payload respects the locks', () {
    test('a fresh test sends the scoring fields', () {
      final body = paper().toUpdatePayload();
      expect(body['totalQuestions'], 200);
      expect(body['marksCorrect'], 4);
      expect(body['durationMinutes'], 180);
      expect(body['courseTypeId'], 20);
    });

    test('an attempted test drops them, keeping name and instructions', () {
      // Sending a frozen field would take a 409 the admin cannot act on.
      final body = paper(attempts: 2).toUpdatePayload();
      expect(body.containsKey('totalQuestions'), isFalse);
      expect(body.containsKey('marksCorrect'), isFalse);
      expect(body.containsKey('durationMinutes'), isFalse);
      expect(body.containsKey('courseTypeId'), isFalse);
      expect(body['name'], 'Grand Test 1');
      expect(body['instructions'], 'No going back.');
    });
  });

  group('live vs expired attempts', () {
    TestAttempt attemptOf(Map<String, dynamic> json) =>
        TestAttempt.fromJson({'id': 1, 'studentName': 'A', ...json});

    test('an unsubmitted attempt with time left is live', () {
      final a = attemptOf({'status': 'in_progress', 'remainingSeconds': 600});
      expect(a.isLive, isTrue);
      expect(a.isExpired, isFalse);
    });

    test('an expired status is not live', () {
      final a = attemptOf({'status': 'expired'});
      expect(a.isLive, isFalse);
      expect(a.isExpired, isTrue);
    });

    test('time already up is not live, whatever the status says', () {
      // The server closes an attempt only when the student next touches it,
      // so "in_progress" with no time left is a candidate who already left.
      final a = attemptOf({'status': 'in_progress', 'remainingSeconds': 0});
      expect(a.isExpired, isTrue);
      expect(a.isLive, isFalse);
    });

    test('a submitted attempt is neither live nor counted as expired', () {
      final a = attemptOf({
        'status': 'submitted',
        'submittedAt': '2026-08-30T10:00:00.000Z',
        'score': 120,
        'maxScore': 200,
      });
      expect(a.isSubmitted, isTrue);
      expect(a.isLive, isFalse);
      expect(a.scoreLabel, '120 / 200');
      expect(a.percent, 60);
    });
  });

  test('leaderboard rows fall back to positional rank', () {
    final row = LeaderboardRow.fromJson({
      'student': {'id': 4, 'name': 'Asha'},
      'bestScore': 180,
      'maxScore': 200,
      'attemptCount': 3,
    }, 1);

    expect(row.rank, 1);
    expect(row.studentName, 'Asha');
    expect(row.scoreLabel, '180 / 200');
    expect(row.attemptCount, 3);
  });
}
