import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;

import '../models/sheet_row_model.dart';

/// Thrown when the sheet responds but its contents can't be used. The message
/// is written for the admin reading the screen, not for a log.
class SheetCsvException implements Exception {
  final String message;
  const SheetCsvException(this.message);

  @override
  String toString() => message;
}

/// Reads a published Google Sheet CSV directly - no backend involved.
///
/// This is the "what does the spreadsheet actually say" view, deliberately
/// bypassing the API so it can be compared against what the import produced.
class SheetCsvService {
  final http.Client _client;

  SheetCsvService({http.Client? client}) : _client = client ?? http.Client();

  static const Duration _timeout = Duration(seconds: 20);

  Future<List<SheetQuestion>> fetchQuestions(String csvUrl) async {
    final http.Response response;
    try {
      response = await _client.get(Uri.parse(csvUrl)).timeout(_timeout);
    } on http.ClientException {
      throw const SheetCsvException('Network error. Check your connection and try again.');
    } catch (e) {
      throw SheetCsvException('Could not reach the sheet: $e');
    }

    if (response.statusCode != 200) {
      throw SheetCsvException('The sheet returned ${response.statusCode}. '
          'Check the link is published to the web.');
    }

    final body = utf8.decode(response.bodyBytes);

    // An unpublished sheet redirects to a sign-in page, which arrives as a 200
    // full of HTML. Trusting the status alone would feed that to the parser.
    if (body.trimLeft().startsWith('<')) {
      throw const SheetCsvException(
        'That link returned a web page, not CSV. In the Sheet use '
        'File > Share > Publish to web and pick "Comma-separated values".',
      );
    }

    return parseCsv(body);
  }

  /// Split out from the fetch so it can be tested without a network call.
  List<SheetQuestion> parseCsv(String body) {
    // Rows addressable by column name: the sheet carries columns whose order
    // has changed before, so position-based parsing would silently misread.
    final List<CsvRow> rows;
    try {
      rows = Csv().decodeWithHeaders(body);
    } on FormatException catch (e) {
      throw SheetCsvException('That file is not valid CSV: ${e.message}');
    }

    if (rows.isEmpty) return const [];

    if (!rows.first.headerMap.containsKey('question_text')) {
      throw const SheetCsvException(
        'No "question_text" column found. Is this the right tab?',
      );
    }

    final questions = <SheetQuestion>[];

    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      String cell(String column) => (row[column] ?? '').toString().trim();

      final text = cell('question_text');
      if (text.isEmpty) continue; // trailing blank rows are normal in a sheet

      final options = <String>[];
      final optionImages = <String?>[];

      // Two spellings in the wild: option1..option6 the way a sheet writes
      // them, option_a..option_f the way a printed paper does. Both say the
      // same thing, and refusing one of them is refusing the admin's file.
      for (var n = 1; n <= 6; n++) {
        final letter = String.fromCharCode(96 + n); // a, b, c...
        final optionText = _first([
          cell('option$n'),
          cell('option_$letter'),
          cell('option${letter.toUpperCase()}'),
        ]);
        if (optionText.isEmpty) continue;
        options.add(optionText);
        final image = _first([
          cell('option${n}_image_url'),
          cell('option_${letter}_image_url'),
        ]);
        optionImages.add(image.isEmpty ? null : image);
      }

      final questionImage = cell('question_image_url');
      final tagsRaw = cell('tags');

      questions.add(SheetQuestion(
        questionText: text,
        questionImageUrl: questionImage.isEmpty ? null : questionImage,
        difficulty: cell('difficulty'),
        marksCorrect: cell('marks_correct'),
        marksIncorrect: cell('marks_incorrect'),
        explanation: cell('explanation'),
        status: cell('status').isEmpty ? 'active' : cell('status'),
        tags: tagsRaw.isEmpty
            ? const []
            : tagsRaw.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList(),
        options: options,
        optionImageUrls: optionImages,
        correctOption: readCorrectOption(cell('correct_option')),
        // Either spelling: a file written for the API says accessType, one
        // written by a person says access.
        accessType: (cell('access_type').isEmpty
                ? (cell('accessType').isEmpty
                    ? cell('access')
                    : cell('accessType'))
                : cell('access_type'))
            .toLowerCase(),
        subjectName: cell('subject'),
        topicName: cell('topic'),
        // +2: the header is line 1 and spreadsheets count from 1.
        sourceRow: index + 2,
      ));
    }

    return questions;
  }
}

/// The first of these that says anything.
String _first(List<String> values) =>
    values.firstWhere((v) => v.trim().isNotEmpty, orElse: () => '').trim();

/// The answer column, as a number or as the letter a paper writes it with.
///
/// "3" and "C" mean the same option; a sheet written for a printed exam uses
/// the letter, and refusing it would be refusing the admin's own file.
/// 0 means it says neither, which the caller reports as a bad row.
int readCorrectOption(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return 0;

  final number = int.tryParse(value);
  if (number != null) return number;

  if (value.length != 1) return 0;
  final letter = value.toUpperCase().codeUnitAt(0);
  const a = 65; // 'A'
  return letter >= a && letter <= a + 5 ? letter - a + 1 : 0;
}
