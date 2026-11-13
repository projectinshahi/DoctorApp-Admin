import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_drapp/Screen/QuestionBank/question_bank_screen.dart';

/// The dashboard shows this inside a scroll view, so the screen is laid out
/// with unbounded height. A TabBarView there renders nothing at all - this is
/// the test that caught it.
Widget _inTheDashboard() => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: QuestionBankScreen(
            quizzes: SizedBox(height: 40, child: Text('quizzes panel')),
            import: SizedBox(height: 40, child: Text('import panel')),
          ),
        ),
      ),
    );

void main() {
  testWidgets('lays out with unbounded height, showing the first tab',
      (tester) async {
    await tester.pumpWidget(_inTheDashboard());

    expect(tester.takeException(), isNull);
    expect(find.text('Quizzes'), findsOneWidget);
    expect(find.text('Add quiz from CSV'), findsOneWidget);
    expect(find.text('quizzes panel'), findsOneWidget);
    expect(find.text('import panel'), findsNothing);
  });

  testWidgets('a tap swaps which panel is shown', (tester) async {
    await tester.pumpWidget(_inTheDashboard());

    await tester.tap(find.text('Add quiz from CSV'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('import panel'), findsOneWidget);
    expect(find.text('quizzes panel'), findsNothing);

    await tester.tap(find.text('Quizzes'));
    await tester.pumpAndSettle();
    expect(find.text('quizzes panel'), findsOneWidget);
  });
}
