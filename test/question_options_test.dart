import 'package:flutter_test/flutter_test.dart';

import 'package:admin_drapp/Screen/Test/question_form_sheet.dart';

/// Four options to six: A to D are required, E and F arrive through Add
/// option, and the answer may only ever point at an option that holds
/// something.
void main() {
  List<bool> flags(String pattern) =>
      [for (final c in pattern.split('')) c == '1'];

  group('what can be saved', () {
    test('the usual four, with a valid answer', () {
      expect(questionOptionProblem(flags('111100'), 'A'), isNull);
      expect(questionOptionProblem(flags('111100'), 'D'), isNull);
    });

    test('one of the first four missing is refused', () {
      expect(questionOptionProblem(flags('101100'), 'A'),
          'Option B needs text or an image');
    });

    test('six are accepted, and F can be the answer', () {
      expect(questionOptionProblem(flags('111111'), 'F', visible: 6), isNull);
      expect(questionOptionProblem(flags('111110'), 'E', visible: 5), isNull);
    });

    test('a row on screen has to be filled, which is what stops Save', () {
      expect(questionOptionProblem(flags('111100'), 'A', visible: 5),
          'Option E needs text or an image');
    });

    test('F behind an empty E is refused in the server\'s own words', () {
      // Not reachable through Add option, which is the point of the guard:
      // it catches a question that arrived with the hole already in it.
      expect(
        questionOptionProblem(flags('111101'), 'A'),
        'Option F is filled but Option E is empty - fill E, or move F into it',
      );
    });

    test('an answer pointing at an empty option is refused', () {
      expect(questionOptionProblem(flags('111100'), 'E'),
          'The correct answer is E, which is empty');
    });
  });

  group('which letters the answer may point at', () {
    test('only the options that hold something', () {
      expect(questionAnswerLetters(flags('111100')), ['A', 'B', 'C', 'D']);
      expect(questionAnswerLetters(flags('111110')),
          ['A', 'B', 'C', 'D', 'E']);
      expect(questionAnswerLetters(flags('111111')),
          ['A', 'B', 'C', 'D', 'E', 'F']);
    });

    test('a half-filled form never offers its blanks', () {
      expect(questionAnswerLetters(flags('101100')), ['A', 'C', 'D']);
      expect(questionAnswerLetters(flags('000000')), isEmpty);
    });
  });

  group('how many rows an existing question opens with', () {
    test('four at least, however few the question carries', () {
      expect(visibleQuestionOptions(2), 4);
      expect(visibleQuestionOptions(4), 4);
    });

    test('its extras are shown, and six is the ceiling', () {
      expect(visibleQuestionOptions(5), 5);
      expect(visibleQuestionOptions(6), 6);
      expect(visibleQuestionOptions(7), 6);
    });
  });
}
