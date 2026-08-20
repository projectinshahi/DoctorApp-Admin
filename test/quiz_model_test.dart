import 'package:flutter_test/flutter_test.dart';
import 'package:admin_drapp/models/quiz_model.dart';

Map<String, dynamic> _quiz(Map<String, dynamic> extra) => {
      'id': 5,
      'title': 'Cardiac cycle — rapid fire',
      'subjectId': 1,
      'topicId': 3,
      'examTag': 'NEET',
      'questionCount': 10,
      ...extra,
    };

void main() {
  group('parsing', () {
    test('reads the list from quizzes / data / items, or a bare list', () {
      for (final key in ['quizzes', 'data', 'items']) {
        expect(parseQuizzes({key: [_quiz({})]}).single.id, 5, reason: 'under "$key"');
      }
      expect(parseQuizzes([_quiz({})]).single.title, 'Cardiac cycle — rapid fire');
      expect(parseQuizzes({'unexpected': 'shape'}), isEmpty);
    });

    test('optional fields degrade to sane defaults', () {
      final q = Quiz.fromJson({'id': 1, 'title': 'T'});
      expect(q.subjectId, 0);
      expect(q.examTag, isNull);
      expect(q.questionCount, 0);
      expect(q.activeQuestionPool, isNull);
    });
  });

  group('isUnderfilled', () {
    test('true only when the pool is known and short of the count', () {
      expect(Quiz.fromJson(_quiz({'activeQuestionPool': 4})).isUnderfilled, isTrue);
      expect(Quiz.fromJson(_quiz({'activeQuestionPool': 10})).isUnderfilled, isFalse);
      expect(Quiz.fromJson(_quiz({'activeQuestionPool': 40})).isUnderfilled, isFalse);
    });

    test('an unreported pool is unknown, not zero — so no false warning', () {
      expect(Quiz.fromJson(_quiz({})).activeQuestionPool, isNull);
      expect(Quiz.fromJson(_quiz({})).isUnderfilled, isFalse);
    });
  });

  group('examTagsOf', () {
    test('dedupes, sorts, and drops null or blank tags', () {
      final quizzes = [
        Quiz.fromJson(_quiz({'id': 1, 'examTag': 'NEET'})),
        Quiz.fromJson(_quiz({'id': 2, 'examTag': 'AIIMS'})),
        Quiz.fromJson(_quiz({'id': 3, 'examTag': 'NEET'})),
        Quiz.fromJson(_quiz({'id': 4, 'examTag': null})),
        Quiz.fromJson(_quiz({'id': 5, 'examTag': '   '})),
      ];
      expect(examTagsOf(quizzes), ['AIIMS', 'NEET']);
      expect(examTagsOf(const []), isEmpty);
    });
  });

  test('create payload carries only what POST /api/quizzes takes', () {
    final payload = Quiz.fromJson(_quiz({'activeQuestionPool': 40})).toPayload();
    expect(payload.keys.toSet(), {
      'title', 'subjectId', 'topicId', 'examTag', 'questionCount',
    });
    // Server-owned fields never travel back.
    expect(payload.containsKey('id'), isFalse);
    expect(payload.containsKey('activeQuestionPool'), isFalse);
  });
}
