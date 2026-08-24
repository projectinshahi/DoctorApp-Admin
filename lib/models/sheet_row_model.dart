/// Models for reading a published Google Sheet CSV directly.
///
/// Named Sheet* to stay out of the way of [Subject] and [Question] in
/// question_bank_model.dart, which describe the *database* records. These two
/// describe what the spreadsheet says, which is exactly the comparison this
/// screen exists to let an admin make.
library;

/// One published sheet tab.
class SheetSubject {
  final String name;
  final String url;

  const SheetSubject({required this.name, required this.url});
}

/// One question row as the sheet has it.
class SheetQuestion {
  final String questionText;
  final String? questionImageUrl;
  final String difficulty;
  final String status;
  final List<String> tags;

  /// Scoring, kept exactly as the sheet wrote it ("2", "-0.5"). Parsing to a
  /// number here would round-trip badly - the sheet is the source of truth and
  /// this screen exists to show what it says.
  final String marksCorrect;
  final String marksIncorrect;

  final String explanation;

  /// Option texts in sheet order, blanks dropped.
  final List<String> options;

  /// Image URL per option, index-aligned with [options].
  final List<String?> optionImageUrls;

  /// 1-based, matching the sheet's `correct_option` column.
  final int correctOption;

  const SheetQuestion({
    required this.questionText,
    required this.options,
    required this.optionImageUrls,
    required this.correctOption,
    this.questionImageUrl,
    this.difficulty = '',
    this.status = 'active',
    this.tags = const [],
    this.marksCorrect = '',
    this.marksIncorrect = '',
    this.explanation = '',
  });

  bool get isActive => status.trim().toLowerCase() == 'active';

  /// 0-based index into [options], or null when the sheet didn't say - a row
  /// pointing at option 9 of 4 has no correct answer, and guessing one would
  /// show the admin a wrong answer key.
  int? get correctIndex {
    final index = correctOption - 1;
    return index >= 0 && index < options.length ? index : null;
  }

  bool isCorrect(int index) => index == correctIndex;

  /// The correct option's text, or null when [correctOption] is out of range.
  String? get correctAnswer {
    final i = correctIndex;
    return i == null ? null : options[i];
  }
}
