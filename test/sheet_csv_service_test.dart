import 'package:flutter_test/flutter_test.dart';

import 'package:admin_drapp/core/const/sheet_sources.dart';
import 'package:admin_drapp/models/sheet_row_model.dart';
import 'package:admin_drapp/services/sheet_csv_service.dart';

const _csv = '''
question_text,question_image_url,difficulty,tags,status,option1,option1_image_url,option2,option2_image_url,option3,option3_image_url,option4,option4_image_url,correct_option
Which organism causes CAP?,,medium,"pulmonology,dha",active,Streptococcus pneumoniae,,Mycobacterium tuberculosis,,Pseudomonas aeruginosa,,Aspergillus fumigatus,,1
"A patient with COPD, low FEV1/FVC?",http://img/q.png,easy,copd,Inactive,Obstructive,http://img/a.png,Restrictive,,,,,,2
Only two options here,,easy,,active,Yes,,No,,,,,,9
,,,,,,,,,,,,,
''';

void main() {
  group('sheet scoring columns', _scoring);
  group('SheetSources tab derivation', _sources);

  final service = SheetCsvService();
  List<SheetQuestion> rows() => service.parseCsv(_csv);

  test('parses by header name and drops trailing blank rows', () {
    expect(rows(), hasLength(3));
    expect(rows().first.questionText, 'Which organism causes CAP?');
    expect(rows().first.tags, ['pulmonology', 'dha']);
  });

  test('a quoted field containing a comma stays one field', () {
    expect(rows()[1].questionText, 'A patient with COPD, low FEV1/FVC?');
  });

  test('status casing from the sheet is tolerated', () {
    // The sheet has "Inactive" with a capital I; the panel must still read it
    // as not-active rather than defaulting to active.
    expect(rows()[1].status, 'Inactive');
    expect(rows()[1].isActive, isFalse);
    expect(rows()[0].isActive, isTrue);
  });

  test('correct_option is 1-based in the sheet, 0-based in the model', () {
    expect(rows()[0].correctOption, 1);
    expect(rows()[0].correctIndex, 0);
    expect(rows()[1].correctIndex, 1);
  });

  test('blank option columns are dropped, images stay index-aligned', () {
    expect(rows()[1].options, ['Obstructive', 'Restrictive']);
    expect(rows()[1].optionImageUrls, ['http://img/a.png', null]);
  });

  test('an out-of-range correct_option reports null, not a wrong answer', () {
    expect(rows()[2].options, hasLength(2));
    expect(rows()[2].correctIndex, isNull);
    expect(rows()[2].isCorrect(0), isFalse);
  });

  test('a missing question_text column is rejected with a readable message', () {
    expect(
      () => service.parseCsv('name,age\nAda,36\n'),
      throwsA(isA<SheetCsvException>()
          .having((e) => e.message, 'message', contains('question_text'))),
    );
  });
}

/// The real sheet's column set, which carries scoring and an explanation the
/// earlier fixture predates.
const _scoredCsv = '''
question_text,difficulty,marks_correct,marks_incorrect,explanation,tags,status,option1,option2,correct_option
Inferior wall MI leads?,medium,2,-0.5,"II, III, aVF are inferior.",ecg,active,Inferior,Anterior,1
No scoring on this row,,,,,,active,Yes,No,2
''';

void _scoring() {
  final rows = SheetCsvService().parseCsv(_scoredCsv);

  test('marks and explanation are read verbatim from the sheet', () {
    expect(rows.first.marksCorrect, '2');
    expect(rows.first.marksIncorrect, '-0.5');
    expect(rows.first.explanation, 'II, III, aVF are inferior.');
    expect(rows.first.correctAnswer, 'Inferior');
  });

  test('a row with no scoring columns filled reads as empty, not zero', () {
    // Empty means "the sheet did not say"; rendering it as 0 would claim the
    // question is worth nothing.
    expect(rows[1].marksCorrect, isEmpty);
    expect(rows[1].marksIncorrect, isEmpty);
    expect(rows[1].explanation, isEmpty);
  });
}

void _sources() {
  test('subjects are derived from the tab titles, deduplicated in order', () {
    expect(SheetSources.subjects.first, 'Internal Med');
    expect(SheetSources.subjects, contains('OBGYN'));
    expect(SheetSources.subjects.toSet(), hasLength(SheetSources.subjects.length));
  });

  test('topics are the tabs under one subject only', () {
    expect(SheetSources.topicsFor('OBGYN'), ['Obstetrics', 'Gynaecology']);
    expect(SheetSources.topicsFor(null), isEmpty);
  });

  test('a topic containing " - " would not split the subject twice', () {
    expect(SheetSources.topicsFor('Internal Med'), contains('GI & Hepatology'));
  });

  test('tabFor returns null for a pair the sheet does not have', () {
    expect(SheetSources.tabFor('OBGYN', 'Cardiology'), isNull);
    expect(SheetSources.tabFor('OBGYN', 'Obstetrics'), 'OBGYN - Obstetrics');
  });
}
