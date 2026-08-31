import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// Mirrors the counter in TestWizardScreen. The upload is blocked when the row
/// count differs from totalQuestions, so a miscount blocks a good file - the
/// quoted-comma case is exactly what naive splitting gets wrong.
int? countCsvRows(Uint8List bytes) {
  final String text;
  try {
    text = String.fromCharCodes(bytes);
  } catch (_) {
    return null;
  }
  if (text.trim().isEmpty) return null;

  var rows = 0;
  var inQuotes = false;
  var current = StringBuffer();

  void endLine() {
    if (current.toString().trim().isNotEmpty) rows++;
    current = StringBuffer();
  }

  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (char == '"') {
      if (inQuotes && i + 1 < text.length && text[i + 1] == '"') {
        current.write('""');
        i++;
        continue;
      }
      inQuotes = !inQuotes;
      current.write(char);
    } else if ((char == '\n' || char == '\r') && !inQuotes) {
      if (char == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      endLine();
    } else {
      current.write(char);
    }
  }
  endLine();

  if (rows == 0) return null;
  return rows - 1;
}

Uint8List csv(String text) => Uint8List.fromList(utf8.encode(text));

void main() {
  const header = 'question_text,option_a,option_b,option_c,option_d,correct_option,explanation';

  test('counts plain rows, excluding the header', () {
    expect(countCsvRows(csv('$header\nQ1,a,b,c,d,A,\nQ2,a,b,c,d,B,')), 2);
  });

  test('a comma inside a quoted stem does not add a row', () {
    expect(
      countCsvRows(csv('$header\n'
          '"A 54-year-old, previously well, presents with chest pain",a,b,c,d,A,\n')),
      1,
    );
  });

  test('a newline inside a quoted stem does not add a row', () {
    expect(
      countCsvRows(csv('$header\n"Line one\nLine two",a,b,c,d,A,\nQ2,a,b,c,d,B,')),
      2,
    );
  });

  test('an escaped double quote inside a quoted field is not a delimiter', () {
    expect(
      countCsvRows(csv('$header\n"He said ""stop"" loudly",a,b,c,d,A,\n')),
      1,
    );
  });

  test('trailing blank lines are ignored', () {
    expect(countCsvRows(csv('$header\nQ1,a,b,c,d,A,\n\n\n')), 1);
  });

  test('CRLF line endings count the same as LF', () {
    expect(countCsvRows(csv('$header\r\nQ1,a,b,c,d,A,\r\nQ2,a,b,c,d,B,\r\n')), 2);
  });

  test('header only means zero question rows', () {
    expect(countCsvRows(csv(header)), 0);
  });

  test('an empty file returns null rather than zero', () {
    expect(countCsvRows(csv('')), isNull);
    expect(countCsvRows(csv('   \n  ')), isNull);
  });
}
