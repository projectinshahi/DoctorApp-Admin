import 'package:flutter_test/flutter_test.dart';

import 'package:admin_drapp/services/lesson_services.dart';

LessonOption lesson(int id, String title, {String type = 'video'}) =>
    LessonOption.fromJson({
      'id': id,
      'title': title,
      'type': type,
      'chapter': {'id': 12, 'title': 'Cardiology'},
    });

void main() {
  test('the label is the title alone', () {
    // The dropdown already says which subject it is filtered by, so the
    // chapter and where the subject came from would only be noise.
    final items = lessonDropdownItems([
      lesson(49, 'testing', type: 'quiz'),
      lesson(50, 'cardilogy based test'),
    ]);
    expect(items.map((i) => i.label).toList(),
        ['testing', 'cardilogy based test']);
  });

  test('a shared title gets its type, and only that pair does', () {
    // "Obstetrics" exists today as both a video and a text lesson.
    final items = lessonDropdownItems([
      lesson(39, 'Obstetrics', type: 'video'),
      lesson(40, 'Obstetrics', type: 'text'),
      lesson(41, 'Cardiology basics', type: 'video'),
    ]);
    expect(items.map((i) => i.label).toList(),
        ['Obstetrics (video)', 'Obstetrics (text)', 'Cardiology basics']);
  });

  test('titles differing only by case or spacing count as the same', () {
    final items = lessonDropdownItems([
      lesson(1, 'Obstetrics', type: 'video'),
      lesson(2, ' obstetrics ', type: 'text'),
    ]);
    expect(items.every((i) => i.label.contains('(')), isTrue);
  });

  test('ids and order survive the labelling', () {
    final items = lessonDropdownItems([lesson(49, 'testing'), lesson(7, 'b')]);
    expect(items.map((i) => i.id).toList(), [49, 7]);
  });

  test('where a subject came from is parsed but never shown', () {
    // subjectFromQuiz is useful when managing lessons; it is not for this
    // dropdown, so it must not reach the label.
    final quiz = LessonOption.fromJson({
      'id': 49,
      'title': 'testing',
      'type': 'quiz',
      'subjectId': null,
      'subjectFromQuiz': 7,
      'chapter': {'id': 12, 'title': 'Cardiology'},
    });
    expect(quiz.subjectFromQuiz, 7);
    expect(lessonDropdownItems([quiz]).single.label, 'testing');
  });

  test('an empty answer stays empty - no lessons are invented', () {
    expect(lessonDropdownItems(const []), isEmpty);
  });
}
