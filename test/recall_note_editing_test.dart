import 'package:admin_drapp/Screen/RapidRecall/recall_note_list.dart';
import 'package:admin_drapp/models/rapid_recall_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Two empty notes used to be the same object - `const RapidRecallCard()` is
/// canonicalised - and the controllers are keyed by identity, so both rows
/// shared one pair of them. Typing in one note appeared in the other.
void main() {
  testWidgets('two new notes are separate objects, so they type separately',
      (tester) async {
    var cards = <RapidRecallCard>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: RecallNoteList(
                cards: cards,
                onChanged: (next) => setState(() => cards = next),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Add note'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add note'));
    await tester.pumpAndSettle();

    expect(cards.length, 2);
    expect(identical(cards[0], cards[1]), isFalse,
        reason: 'a shared object means shared controllers');

    final titles = find.widgetWithText(TextField, 'Pseudo gout');
    expect(titles, findsNWidgets(2));

    await tester.enterText(titles.first, 'Gout');
    await tester.pumpAndSettle();

    // The second note must still be empty.
    final second = tester.widget<TextField>(titles.at(1));
    expect(second.controller?.text ?? '', isEmpty);
  });

  testWidgets('the field keeps focus while typing, letter after letter',
      (tester) async {
    // The row key used to come from the card's identity, and every keystroke
    // replaces the card - so the row was discarded and rebuilt mid-word. The
    // field lost focus after one letter and the next had to be tapped for.
    var cards = <RapidRecallCard>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: RecallNoteList(
                cards: cards,
                onChanged: (next) => setState(() => cards = next),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Add note'));
    await tester.pumpAndSettle();

    final title = find.widgetWithText(TextField, 'Pseudo gout');
    await tester.tap(title);
    await tester.pumpAndSettle();

    // One letter at a time, the way a person types.
    for (final letter in 'Gout'.split('')) {
      final state = tester.state<EditableTextState>(
          find.descendant(of: title, matching: find.byType(EditableText)));
      state.updateEditingValue(TextEditingValue(
        text: state.textEditingValue.text + letter,
        selection: TextSelection.collapsed(
            offset: state.textEditingValue.text.length + 1),
      ));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<EditableText>(find.descendant(
                of: title, matching: find.byType(EditableText)))
            .focusNode
            .hasFocus,
        isTrue,
        reason: 'focus was lost after typing "$letter"',
      );
    }

    expect(find.text('Gout'), findsOneWidget);
  });

  test('a title alone survives a round trip as a title', () {
    // Known wrinkle, recorded rather than fixed here: one `note` field holds
    // both halves, split on the first blank line.
    final note = RapidRecallCard.composeNote('Gout', 'Crystals in the joint');
    final card = RapidRecallCard(note: note);

    expect(card.noteTitle, 'Gout');
    expect(card.noteBody, 'Crystals in the joint');
  });
}
