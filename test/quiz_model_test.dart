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

    test('missing optional fields fall back without throwing', () {
      final q = Quiz.fromJson({'id': 5});
      expect(q.title, '');
      expect(q.subjectId, 0);
      expect(q.questionCount, isNull, reason: 'null means "serve everything"');
      expect(q.availableQuestions, 0);
      expect(q.status, 'active');
      expect(q.isUnderfilled, isFalse);
      expect(q.isTaken, isFalse);
    });

    test('reads the nested subject / topic / lesson objects from list rows', () {
      final q = Quiz.fromJson(_quiz({
        'subject': {'id': 1, 'name': 'Physiology'},
        'topic': {'id': 3, 'name': 'Cardiac cycle'},
        'lesson': {'id': 21, 'title': 'Cardiology Quiz'},
      }));
      expect(q.subjectName, 'Physiology');
      expect(q.topicName, 'Cardiac cycle');
      expect(q.linkedLessonId, 21);
      expect(q.linkedLessonTitle, 'Cardiology Quiz');
      expect(q.isTaken, isTrue, reason: 'must be disabled in the picker');
    });
  });

  group('isUnderfilled', () {
    test('trusts the server flag when present', () {
      expect(Quiz.fromJson(_quiz({'isUnderfilled': true})).isUnderfilled, isTrue);
      expect(
        Quiz.fromJson(_quiz({'isUnderfilled': false, 'availableQuestions': 4})).isUnderfilled,
        isFalse,
        reason: 'the server overrides the computed fallback',
      );
    });

    test('falls back to the counters when the flag is absent', () {
      expect(Quiz.fromJson(_quiz({'availableQuestions': 4})).isUnderfilled, isTrue);
      expect(Quiz.fromJson(_quiz({'availableQuestions': 10})).isUnderfilled, isFalse);
      expect(Quiz.fromJson(_quiz({'availableQuestions': 40})).isUnderfilled, isFalse);
    });

    test('an unreported pool is not underfilled', () {
      // availableQuestions defaults to 0; that is "not reported", and must
      // never render as "only 0 questions available".
      expect(Quiz.fromJson(_quiz({})).availableQuestions, 0);
      expect(Quiz.fromJson(_quiz({})).isUnderfilled, isFalse);
    });
  });

  group('examTagsOf', () {
    test('returns distinct non-empty tags, sorted', () {
      final quizzes = [
        Quiz.fromJson(_quiz({'examTag': 'NEET'})),
        Quiz.fromJson(_quiz({'examTag': 'AIIMS'})),
        Quiz.fromJson(_quiz({'examTag': 'NEET'})),
        Quiz.fromJson(_quiz({'examTag': '  '})),
        Quiz.fromJson(_quiz({'examTag': null})),
      ];
      expect(examTagsOf(quizzes), ['AIIMS', 'NEET']);
      expect(examTagsOf(const []), isEmpty);
    });
  });

  test('toPayload carries only the create fields', () {
    final payload = Quiz.fromJson(_quiz({'availableQuestions': 40})).toPayload();
    expect(payload['title'], 'Cardiac cycle — rapid fire');
    expect(payload['subjectId'], 1);
    expect(payload['topicId'], 3);
    expect(payload['examTag'], 'NEET');
    expect(payload['questionCount'], 10);
    expect(payload.containsKey('availableQuestions'), isFalse);
    expect(payload.containsKey('id'), isFalse);
  });

  group('preview', () {
    final json = {
      'quiz': _quiz({}),
      'availableQuestions': 2,
      'isUnderfilled': true,
      'totalQuestions': 1,
      'totalMarks': 4.0,
      'questions': [
        {
          'id': 9,
          'questionText': 'Which valve closes first?',
          'difficulty': 'medium',
          'marksCorrect': 4,
          'marksIncorrect': -1,
          'explanation': 'Mitral closes before tricuspid.',
          'correctOptionId': 2,
          'tagNames': ['high-yield'],
          'options': [
            {'id': 2, 'optionText': 'Mitral', 'displayOrder': 1, 'isCorrect': true},
            {'id': 1, 'optionText': 'Aortic', 'displayOrder': 0, 'isCorrect': false},
          ],
        },
      ],
    };

    test('parses the answer key and sorts options by displayOrder', () {
      final preview = QuizPreview.fromJson(json);
      expect(preview.quiz.id, 5);
      expect(preview.totalMarks, 4.0);
      expect(preview.questions.single.options.first.optionText, 'Aortic',
          reason: 'displayOrder 0 sorts first');
      expect(preview.questions.single.options.last.isCorrect, isTrue);
    });

    test('a stripped answer key leaves isCorrect null, not false', () {
      // The student-facing serve omits isCorrect entirely. Null must stay
      // null so the UI can render "unknown" instead of marking every option
      // wrong.
      final option = QuizOption.fromJson({'id': 1, 'optionText': 'Aortic', 'displayOrder': 0});
      expect(option.isCorrect, isNull);
    });

    test('marksLabel drops the negative half when there is none', () {
      expect(
        QuizQuestion.fromJson({
          'id': 1,
          'questionText': 'q',
          'marksCorrect': 2,
          'marksIncorrect': -0.5,
          'options': const [],
        }).marksLabel,
        '+2 / -0.5',
      );
      expect(
        QuizQuestion.fromJson({
          'id': 1,
          'questionText': 'q',
          'marksCorrect': 2,
          'marksIncorrect': 0,
          'options': const [],
        }).marksLabel,
        '+2',
      );
    });
  });
}
