import 'package:flutter_test/flutter_test.dart';

import 'package:admin_drapp/models/rapid_recall_model.dart';
import 'package:admin_drapp/Screen/RapidRecall/recall_scope_picker.dart';

void main() {
  group('scope is a funnel, not a path', () {
    test('a course-only deck is valid and has a one-step breadcrumb', () {
      final deck = RapidRecall.fromJson({
        'id': 1,
        'title': 'Pharm recall',
        'courseId': 22,
        'course': {'id': 22, 'title': 'GP GULF LICENSING EXAM'},
      });

      expect(deck.courseTypeId, isNull);
      expect(deck.chapterId, isNull);
      expect(deck.lessonId, isNull);
      expect(deck.breadcrumb, 'GP GULF LICENSING EXAM');
    });

    test('the breadcrumb stops wherever narrowing stopped', () {
      final deck = RapidRecall.fromJson({
        'id': 2,
        'title': 'ECG',
        'courseId': 22,
        'course': {'id': 22, 'title': 'GP GULF'},
        'courseType': {'id': 20, 'title': 'DHA'},
        // subject comes back as `name`, everything else as `title`
        'chapter': {'id': 17, 'title': 'Obstetrics And Gynecology'},
      });

      expect(deck.breadcrumb, 'GP GULF › DHA › Obstetrics And Gynecology');
    });

    test('changing a parent clears every child', () {
      // Both the subject list and the lesson list are fetched per exam, so
      // anything carried over from the previous exam may not exist under the
      // new one - and the server refuses the mismatch.
      const full = RecallScope(
          courseId: 1, courseTypeId: 2, chapterId: 3, lessonId: 4);

      final recoursed = full.withCourse(9);
      expect(recoursed.courseTypeId, isNull);
      expect(recoursed.chapterId, isNull);
      expect(recoursed.lessonId, isNull);

      final retyped = full.withCourseType(7);
      expect(retyped.courseId, 1);
      expect(retyped.chapterId, isNull);
      expect(retyped.lessonId, isNull);
    });

    test('a new subject clears the lesson, because lessons live in it', () {
      // The subject IS the chapter, and a lesson from the previous chapter is
      // refused: "That lesson belongs to a different chapter".
      const full = RecallScope(
          courseId: 1, courseTypeId: 2, chapterId: 3, lessonId: 4);

      expect(full.withChapter(9).lessonId, isNull);
      expect(full.withChapter(9).courseTypeId, 2);
      expect(full.withLesson(9).chapterId, 3);
    });
  });

  group('revision notes', () {
    test('the image is optional - text alone is a complete note', () {
      expect(const RapidRecallCard(note: 'Inferior MI').isEmpty, isFalse);
      expect(
          const RapidRecallCard(imageUrl: 'https://x/a.svg').isEmpty, isFalse);
    });

    test('only a note with neither an image nor text is empty', () {
      // An empty row is one the admin never used; saving drops it.
      expect(const RapidRecallCard().isEmpty, isTrue);
      // Whitespace is not content in either half.
      expect(const RapidRecallCard(imageUrl: '   ', note: '  ').isEmpty, isTrue);
    });

    test('a title and a description round-trip through the one note field', () {
      final note = RapidRecallCard.composeNote(
          'Pseudo gout', 'CPPD = Rhomboid + Positive + Knee.');
      final card = RapidRecallCard(note: note);

      expect(card.noteTitle, 'Pseudo gout');
      expect(card.noteBody, 'CPPD = Rhomboid + Positive + Knee.');
      // Plain text for anything that renders `note` as-is.
      expect(note, 'Pseudo gout\n\nCPPD = Rhomboid + Positive + Knee.');
    });

    test('a note written before titles existed is all description', () {
      const card = RapidRecallCard(note: 'CPPD = Rhomboid + Positive + Knee.');
      expect(card.noteTitle, '');
      expect(card.noteBody, 'CPPD = Rhomboid + Positive + Knee.');
    });

    test('paragraphs inside the description survive the split', () {
      // Only the FIRST blank line divides title from description.
      final note = RapidRecallCard.composeNote('Gout', 'First.\n\nSecond.');
      final card = RapidRecallCard(note: note);

      expect(card.noteTitle, 'Gout');
      expect(card.noteBody, 'First.\n\nSecond.');
    });

    test('either half alone is sent without a stray blank line', () {
      expect(RapidRecallCard.composeNote('Gout', ''), 'Gout');
      expect(RapidRecallCard.composeNote('', 'Just the answer.'),
          'Just the answer.');
      expect(RapidRecallCard.composeNote('  ', '  '), '');
    });

    test('an image-only note sends just the image', () {
      const card = RapidRecallCard(imageUrl: 'https://x/a.svg');
      expect(card.hasNote, isFalse);
      expect(card.toJson(), {'imageUrl': 'https://x/a.svg'});
    });

    test('the payload omits empty halves rather than sending blanks', () {
      expect(const RapidRecallCard(note: 'Anterior MI').toJson(),
          {'note': 'Anterior MI'});
      expect(const RapidRecallCard(imageUrl: 'https://x/a.svg').toJson(),
          {'imageUrl': 'https://x/a.svg'});
    });

    test('displayOrder is never sent - the array index is the order', () {
      final json = const RapidRecallCard(note: 'x').toJson();
      expect(json.containsKey('displayOrder'), isFalse);
      expect(json.containsKey('id'), isFalse);
    });
  });

  group('the write payload', () {
    test('sends the optional scope ids even when null, so they can be cleared',
        () {
      // Omitting the key would leave the old subject in place; the admin
      // widening a deck back to course-wide would silently not take.
      final payload = const RapidRecall(id: 1, title: 'T', courseId: 22)
          .toWritePayload();

      expect(payload['courseId'], 22);
      expect(payload.containsKey('courseTypeId'), isTrue);
      expect(payload['courseTypeId'], isNull);
      expect(payload.containsKey('chapterId'), isTrue);
      // subjectId is gone from the contract entirely.
      expect(payload.containsKey('subjectId'), isFalse);
      expect(payload.containsKey('lessonId'), isTrue);
    });

    test('lessonId round-trips', () {
      final payload =
          const RapidRecall(id: 1, title: 'T', courseId: 22, lessonId: 41)
              .toWritePayload();
      expect(payload['lessonId'], 41);
    });
  });

  test('a new deck is a draft until someone publishes it', () {
    final deck = RapidRecall.fromJson({'id': 3, 'title': 'T', 'courseId': 1});
    expect(deck.status, 'draft');
    expect(deck.isPublished, isFalse);
  });

  test('cardCount falls back to the array when the list endpoint omits it', () {
    final deck = RapidRecall.fromJson({
      'id': 4,
      'title': 'T',
      'courseId': 1,
      'cards': [
        {'note': 'a'},
        {'note': 'b'},
      ],
    });
    expect(deck.cardCount, 2);
  });
}
