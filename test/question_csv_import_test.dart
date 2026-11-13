import 'package:flutter_test/flutter_test.dart';

import 'package:admin_drapp/Screen/QuestionBank/quiz_import_tab.dart';
import 'package:admin_drapp/models/question_bank_model.dart';
import 'package:admin_drapp/services/sheet_csv_service.dart';

/// A small file, written the way an admin writes one.
const _csv = '''
subject,topic,question_text,option1,option2,option3,option4,option5,correct_option,access,status,difficulty,marks_correct,explanation,tags
Anatomy,Thorax,Which nerve supplies the diaphragm?,Vagus,Phrenic,Radial,Ulnar,,B,,,easy,2,C3 C4 C5 keeps the diaphragm alive,"anatomy, thorax"
Biochemistry,Electrolytes,Normal serum potassium?,2.0-3.0,3.5-5.0,5.5-7.0,7.5-9.0,9.5-11.0,2,premium,draft,hard,1,,
''';

void main() {
  final parsed = SheetCsvService().parseCsv(_csv);

  group('reading the file', () {
    test('a row knows which line it came from', () {
      // Line 1 is the header, so the first question is line 2.
      expect(parsed.map((q) => q.sourceRow), [2, 3]);
    });

    test('the answer may be a letter or a number', () {
      expect(parsed.first.correctOption, 2); // "B"
      expect(parsed.last.correctOption, 2); // "2"
      expect(readCorrectOption('F'), 6);
      expect(readCorrectOption('a'), 1);
      expect(readCorrectOption(''), 0);
      expect(readCorrectOption('G'), 0);
      expect(readCorrectOption('option 2'), 0);
    });

    test('blank options are dropped, so four stays four', () {
      expect(parsed.first.options.length, 4);
      expect(parsed.last.options.length, 5);
    });
  });

  group('what is checked before anything is sent', () {
    test('a clean file has nothing to say', () {
      expect(validateQuestions(parsed), isEmpty);
    });

    test('a row that does not say where it belongs is refused', () {
      final issues = validateQuestions(SheetCsvService().parseCsv(
        'question_text,option1,option2,option3,option4,correct_option\n'
        'Belongs nowhere,A,B,C,D,1\n',
      ));

      expect(issues.single.field, 'subject, topic');
      expect(issues.single.isWarning, isFalse);
    });

    test('fewer than four options is refused, naming the line', () {
      final thin = SheetCsvService().parseCsv(
        'subject,topic,question_text,option1,option2,correct_option\n'
        'Anatomy,Thorax,Two options only,Yes,No,1\n',
      );

      final issues = validateQuestions(thin);
      expect(issues, hasLength(1));
      expect(issues.single.row, 2);
      expect(issues.single.isWarning, isFalse);
      expect(issues.single.message, contains('four is the minimum'));
    });

    test('an answer pointing at a blank option is refused', () {
      final issues = validateQuestions(SheetCsvService().parseCsv(
        'subject,topic,question_text,option1,option2,option3,option4,'
        'correct_option\n'
        'Anatomy,Thorax,Answer out of range,A,B,C,D,5\n',
      ));

      expect(issues.single.field, 'correct_option');
      expect(issues.single.isWarning, isFalse);
    });

    test('a missing answer is refused, and says how to write one', () {
      final issues = validateQuestions(SheetCsvService().parseCsv(
        'subject,topic,question_text,option1,option2,option3,option4,'
        'correct_option\n'
        'Anatomy,Thorax,No answer given,A,B,C,D,\n',
      ));

      expect(issues.single.message, contains('1-6 or A-F'));
    });

    test('nonsense in difficulty or marks only warns - a default covers it',
        () {
      final issues = validateQuestions(SheetCsvService().parseCsv(
        'subject,topic,question_text,option1,option2,option3,option4,'
        'correct_option,difficulty,marks_correct\n'
        'Anatomy,Thorax,Odd metadata,A,B,C,D,1,impossible,lots\n',
      ));

      expect(issues, hasLength(2));
      expect(issues.every((i) => i.isWarning), isTrue);
    });
  });

  group('what each row starts as on the review screen', () {
    test('free and published unless the file says otherwise', () {
      final first = choiceFor(parsed.first);
      expect(first.free, isTrue);
      expect(first.published, isTrue);
    });

    test('the file can say premium and draft', () {
      final second = choiceFor(parsed.last);
      expect(second.free, isFalse);
      expect(second.published, isFalse);
    });

    test('the subject and topic come off the row', () {
      expect(parsed.first.subjectName, 'Anatomy');
      expect(parsed.first.topicName, 'Thorax');
      expect(parsed.last.topicName, 'Electrolytes');
    });
  });

  group('what gets sent to the bank', () {
    final question =
        questionFrom(parsed.first, subjectId: 7, topicId: 12, free: true);

    test('the subject and topic come from the pickers, not the file', () {
      expect(question.subjectId, 7);
      expect(question.topicId, 12);
    });

    test('exactly one option is the correct one, in file order', () {
      expect(question.options.map((o) => o.optionText),
          ['Vagus', 'Phrenic', 'Radial', 'Ulnar']);
      expect(question.options.where((o) => o.isCorrect).map((o) => o.optionText),
          ['Phrenic']);
      expect(question.options.map((o) => o.displayOrder), [0, 1, 2, 3]);
    });

    test('marks, difficulty and tags travel; blanks take the defaults', () {
      expect(question.marksCorrect, 2);
      expect(question.marksIncorrect, 0);
      expect(question.difficulty, Difficulty.easy);
      expect(question.tagNames, ['anatomy', 'thorax']);

      final second =
          questionFrom(parsed.last, subjectId: 7, topicId: 12, free: false);
      expect(second.explanation, isNull);
      expect(second.tagNames, isEmpty);
      expect(second.accessType, 'premium');
    });

    test('the payload is the one the create endpoint already takes', () {
      final payload = question.toPayload();
      expect(payload['subjectId'], 7);
      expect(payload['topicId'], 12);
      expect(payload['difficulty'], 'easy');
      expect(payload['accessType'], 'free');
      expect((payload['options'] as List), hasLength(4));
      // Status is not in the create body - a draft is hidden afterwards.
      expect(payload.containsKey('status'), isFalse);
    });
  });
}
