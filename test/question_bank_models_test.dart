import 'package:flutter_test/flutter_test.dart';
import 'package:admin_drapp/models/question_bank_model.dart';

Map<String, dynamic> _question(Map<String, dynamic> extra) => {
      'id': 7,
      'subjectId': 1,
      'topicId': 3,
      'questionText': 'Which chamber pumps blood to the lungs?',
      'difficulty': 'hard',
      'status': 'active',
      'marksCorrect': 4,
      'marksIncorrect': -1,
      ...extra,
    };

void main() {
  group('envelope tolerance', () {
    test('reads the list from questions / data / items alike', () {
      for (final key in ['questions', 'data', 'items']) {
        final page = QuestionPage.fromJson({
          key: [_question({})],
          'total': 240,
          'page': 3,
          'limit': 20,
        }, fallbackLimit: 20);

        expect(page.questions.single.id, 7, reason: 'list under "$key"');
        expect(page.total, 240);
        expect(page.page, 3);
        expect(page.totalPages, 12);
      }
    });

    test('reads pagination from a nested meta or pagination object', () {
      final meta = QuestionPage.fromJson({
        'questions': [_question({})],
        'meta': {'total': 50, 'page': 2, 'limit': 10},
      }, fallbackLimit: 20);
      expect([meta.total, meta.page, meta.limit], [50, 2, 10]);

      final nested = QuestionPage.fromJson({
        'data': [_question({})],
        'pagination': {'total': 50, 'page': 2, 'limit': 10},
      }, fallbackLimit: 20);
      expect([nested.total, nested.page, nested.limit], [50, 2, 10]);
    });

    test('falls back sanely when the API sends no counters at all', () {
      final page = QuestionPage.fromJson(
        {'questions': [_question({}), _question({'id': 8})]},
        fallbackLimit: 20,
      );
      expect(page.total, 2);
      expect(page.page, 1);
      expect(page.limit, 20);
      expect(page.totalPages, 1);
    });
  });

  group('question parsing', () {
    test('difficulty and status round-trip through apiValue', () {
      final q = Question.fromJson(_question({}));
      expect(q.difficulty, Difficulty.hard);
      expect(q.difficulty.apiValue, 'hard');
      expect(q.status, QuestionStatus.active);
      expect(DifficultyX.fromApiValue('nonsense'), Difficulty.medium);
      expect(QuestionStatusX.fromApiValue(null), QuestionStatus.active);
    });

    test('nested subject and topic surface as names', () {
      final q = Question.fromJson(_question({
        'subject': {'id': 1, 'name': 'Physiology'},
        'topic': {'id': 3, 'name': 'Cardiac cycle'},
      }));
      expect(q.subjectName, 'Physiology');
      expect(q.topicName, 'Cardiac cycle');

      // Absent on some payloads - must not throw, must stay null.
      final bare = Question.fromJson(_question({}));
      expect(bare.subjectName, isNull);
      expect(bare.topicName, isNull);
    });

    test('tag names read from tagNames, objects, or plain strings', () {
      expect(Question.fromJson(_question({'tagNames': ['neet', 'heart']})).tagNames,
          ['neet', 'heart']);
      expect(Question.fromJson(_question({'tags': ['neet', 'heart']})).tagNames,
          ['neet', 'heart']);

      final withObjects = Question.fromJson(_question({
        'tags': [
          {'id': 1, 'name': 'neet'},
          {'id': 2, 'name': 'heart'},
        ],
        'tagIds': [1, 2],
      }));
      expect(withObjects.tagNames, ['neet', 'heart']);
      expect(withObjects.tags.map((t) => t.id), [1, 2]);
      expect(withObjects.tagIds, [1, 2]);
    });

    test('options sort by displayOrder and keep their image urls', () {
      final q = Question.fromJson(_question({
        'options': [
          {'id': 12, 'optionText': 'Right ventricle', 'isCorrect': true, 'displayOrder': 1},
          {
            'id': 11,
            'optionText': 'Left ventricle',
            'optionImageUrl': 'https://x.test/lv.png',
            'isCorrect': false,
            'displayOrder': 0,
          },
        ],
        'correctOptionId': 12,
      }));

      expect(q.options.map((o) => o.optionText), ['Left ventricle', 'Right ventricle']);
      expect(q.options.first.optionImageUrl, 'https://x.test/lv.png');
      expect(q.correctOptionId, 12);
    });

    test('a duplicate is flagged, an ordinary inactive question is not', () {
      final copy = Question.fromJson(_question({
        'status': 'inactive',
        'questionText': 'Which chamber pumps blood to the lungs? (Copy)',
      }));
      expect(copy.isUnreviewedCopy, isTrue);

      expect(Question.fromJson(_question({'status': 'inactive'})).isUnreviewedCopy, isFalse);
      expect(
          Question.fromJson(_question({'questionText': 'Something (Copy)'})).isUnreviewedCopy,
          isFalse);
    });

    test('payload carries exactly the create/update contract', () {
      final q = Question.fromJson(_question({
        'questionImageUrl': 'https://x.test/q.png',
        'tagNames': ['neet'],
        'correctOptionId': 12,
        'createdAt': '2026-08-01T10:00:00.000Z',
        'options': [
          {'id': 11, 'optionText': 'Left ventricle', 'isCorrect': false, 'displayOrder': 0},
          {'id': 12, 'optionText': 'Right ventricle', 'isCorrect': true, 'displayOrder': 1},
        ],
      }));

      final payload = q.toPayload();
      expect(payload.keys.toSet(), {
        'subjectId', 'topicId', 'questionText', 'questionImageUrl', 'difficulty',
        'marksCorrect', 'marksIncorrect', 'explanation', 'tags', 'options',
      });

      // Status moves only through PATCH /questions/:id/status; server-shaped
      // fields never travel back.
      expect(payload.containsKey('status'), isFalse);
      expect(payload.containsKey('correctOptionId'), isFalse);
      expect(payload.containsKey('createdAt'), isFalse);
      expect(payload['tags'], ['neet']);

      final firstOption = (payload['options'] as List).first as Map;
      expect(firstOption.keys.toSet(), {
        'optionText', 'optionImageUrl', 'isCorrect', 'displayOrder',
      });
      expect(firstOption.containsKey('id'), isFalse);
    });

    test('createdAt / updatedAt parse when present, stay null when not', () {
      final dated = Question.fromJson(_question({
        'createdAt': '2026-08-01T10:00:00.000Z',
        'updatedAt': '2026-08-02T11:30:00.000Z',
      }));
      expect(dated.createdAt?.year, 2026);
      expect(dated.updatedAt?.day, 2);
      expect(Question.fromJson(_question({})).createdAt, isNull);
    });
  });

  group('subject / topic', () {
    test('the abbreviated nested shape parses without isActive/displayOrder', () {
      final s = Subject.fromJson({'id': 1, 'name': 'Physiology'});
      expect(s.name, 'Physiology');
      expect(s.isActive, isTrue);
      expect(s.displayOrder, 0);
    });

    test('the full shape keeps isActive and displayOrder', () {
      final s = Subject.fromJson(
          {'id': 1, 'name': 'Physiology', 'isActive': false, 'displayOrder': 3});
      expect(s.isActive, isFalse);
      expect(s.displayOrder, 3);

      final t = Topic.fromJson(
          {'id': 2, 'subjectId': 1, 'name': 'Cardiac cycle', 'displayOrder': 2});
      expect(t.subjectId, 1);
      expect(t.displayOrder, 2);
    });

    test('lists parse from any envelope', () {
      expect(parseSubjects({'subjects': [{'id': 1, 'name': 'A'}]}).single.name, 'A');
      expect(parseSubjects([{'id': 1, 'name': 'A'}]).single.name, 'A');
      expect(parseTopics({'topics': [{'id': 1, 'subjectId': 2, 'name': 'T'}]}).single.subjectId, 2);
    });
  });
}
