import 'package:flutter_test/flutter_test.dart';

import 'package:admin_drapp/widget/student_progress_widgets.dart';

/// The breakdown screen labels whatever counters the API sent, so a key the
/// backend adds later still has to read as a label.
void main() {
  test('camelCase keys become sentence-case labels', () {
    expect(humanizeKey('inProgress'), 'In progress');
    expect(humanizeKey('bestScore'), 'Best score');
    expect(humanizeKey('total'), 'Total');
    expect(humanizeKey('completed'), 'Completed');
  });

  test('handles digits and already-spaced input', () {
    expect(humanizeKey('top5Score'), 'Top5 score');
    expect(humanizeKey(''), '');
  });
}
