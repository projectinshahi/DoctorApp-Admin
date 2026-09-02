import 'package:flutter_test/flutter_test.dart';

import 'package:admin_drapp/models/quiz_model.dart';

/// The mode is what decides whether an order exists at all - dragging a filter
/// quiz would look like it worked and change nothing a student sees.
void main() {
  test('a manual quiz is reorderable', () {
    final set = QuizQuestionSet.fromJson({
      'quizId': 12,
      'mode': 'manual',
      'totalQuestions': 3,
      'questions': [
        {'id': 44, 'questionText': 'A', 'difficulty': 'medium', 'displayOrder': 0},
        {'id': 17, 'questionText': 'B', 'displayOrder': 1},
        {'id': 39, 'questionText': 'C', 'displayOrder': 2},
      ],
    });

    expect(set.isManual, isTrue);
    expect(set.questionIds, [44, 17, 39]);
    expect(set.questions.first.displayOrder, 0);
  });

  test('a filter quiz is not', () {
    final set = QuizQuestionSet.fromJson({
      'quizId': 13,
      'mode': 'filter',
      'totalQuestions': 0,
      'questions': [],
    });

    expect(set.isManual, isFalse);
    expect(set.questionIds, isEmpty);
  });

  test('an unknown or missing mode is treated as filter', () {
    // Erring towards filter hides the drag handles. The opposite error would
    // offer a gesture that silently does nothing.
    expect(QuizQuestionSet.fromJson({'quizId': 1}).isManual, isFalse);
    expect(
      QuizQuestionSet.fromJson({'quizId': 1, 'mode': 'MANUAL'}).isManual,
      isTrue,
    );
  });

  test('questionIds preserve list order, not id order', () {
    // The array IS the order - the server assigns displayOrder from the index.
    final set = QuizQuestionSet.fromJson({
      'quizId': 12,
      'mode': 'manual',
      'questions': [
        {'id': 39, 'questionText': 'C'},
        {'id': 8, 'questionText': 'A'},
        {'id': 21, 'questionText': 'B'},
      ],
    });

    expect(set.questionIds, [39, 8, 21]);
    expect(set.questionIds, isNot([8, 21, 39]));
  });

  test('a question with no text is still a question', () {
    final q = QuizSetQuestion.fromJson({'id': 5, 'questionText': ''});
    expect(q.id, 5);
    expect(q.questionText, '');
    expect(q.options, isEmpty);
  });

  test('the question image survives fromJson under any of its key spellings',
      () {
    // Dropping this field is what made an image-only question render as
    // "(image only)" over blank space.
    for (final key in ['questionImageUrl', 'question_image_url', 'imageUrl']) {
      final q = QuizSetQuestion.fromJson(
          {'id': 1, 'questionText': '', key: 'https://cdn/x.svg'});
      expect(q.questionImageUrl, 'https://cdn/x.svg', reason: key);
      expect(q.hasImage, isTrue, reason: key);
    }
  });

  test('no image is not an error - hasImage is false, nothing throws', () {
    expect(QuizSetQuestion.fromJson({'id': 2, 'questionText': 'q'}).hasImage,
        isFalse);
    expect(
        QuizSetQuestion.fromJson(
                {'id': 3, 'questionText': 'q', 'questionImageUrl': '   '})
            .hasImage,
        isFalse);
  });
}
