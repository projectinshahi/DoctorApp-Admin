import 'package:flutter_test/flutter_test.dart';

import 'package:admin_drapp/models/course_details_model.dart' as tree;
import 'package:admin_drapp/models/lesson_detail_model.dart';
import 'package:admin_drapp/models/lesson_model.dart';

void main() {
  group('a lesson holds several videos', () {
    test('reads the list in order and keeps what the save has to resend', () {
      final lesson = Lesson.fromJson({
        'id': 1,
        'chapterId': 2,
        'title': 'Cardiology',
        'type': 'video',
        'videoUrl': 'https://cdn/one.mp4',
        'displayOrder': 0,
        'isFreePreview': false,
        'accessType': 'free',
        'status': 'published',
        'videos': [
          {
            'id': 7,
            'title': 'Part 1',
            'videoUrl': 'https://cdn/one.mp4',
            'videoPublicId': 'lesson_videos/abc',
            'durationSeconds': 610,
            'displayOrder': 0,
          },
          {'id': 8, 'videoUrl': 'https://cdn/two.mp4', 'displayOrder': 1},
        ],
      });

      expect(lesson.videoCount, 2);
      expect(lesson.videos.map((v) => v.videoUrl),
          ['https://cdn/one.mp4', 'https://cdn/two.mp4']);
      expect(lesson.videos.first.videoPublicId, 'lesson_videos/abc');
      // A row with no name is no name, not an empty string to send back.
      expect(lesson.videos.last.title, isNull);

      // What goes back up: no displayOrder — the array's order is the order.
      expect(lesson.videos.first.toJson(), {
        'videoUrl': 'https://cdn/one.mp4',
        'title': 'Part 1',
        'videoPublicId': 'lesson_videos/abc',
        'durationSeconds': 610,
      });
      expect(lesson.videos.last.toJson(), {'videoUrl': 'https://cdn/two.mp4'});
    });

    test('a response from before the feature still shows its one video', () {
      final lesson = Lesson.fromJson({
        'id': 1,
        'chapterId': 2,
        'title': 'Old lesson',
        'type': 'video',
        'videoUrl': 'https://cdn/legacy.mp4',
        'videoPublicId': 'lesson_videos/legacy',
        'displayOrder': 0,
        'isFreePreview': false,
        'accessType': 'free',
        'status': 'published',
      });

      expect(lesson.videoCount, 1, reason: 'videoUrl is promoted to row 1');
      expect(lesson.videos.single.videoPublicId, 'lesson_videos/legacy');
      expect(lesson.hasVideo, isTrue);
    });

    test('no video anywhere is an empty list, not a row with a blank link', () {
      final lesson = Lesson.fromJson({
        'id': 1,
        'chapterId': 2,
        'title': 'Quiz only',
        'type': 'quiz',
        'quizId': 12,
        'videoUrl': null,
        'displayOrder': 0,
        'isFreePreview': false,
        'accessType': 'free',
        'status': 'published',
      });

      expect(lesson.videos, isEmpty);
      expect(lesson.hasVideo, isFalse);
      expect(lesson.hasQuiz, isTrue);
    });
  });

  group('a lesson holds its quiz and its decks too', () {
    test('a video lesson can carry both', () {
      final detail = LessonDetail.fromJson({
        'id': 1,
        'chapterId': 2,
        'title': 'Cardiology',
        'type': 'video',
        'quizId': 12,
        'videos': [
          {'videoUrl': 'https://cdn/one.mp4'},
          {'videoUrl': 'https://cdn/two.mp4'},
        ],
        'rapidRecalls': [
          {'id': 3, 'title': 'ECG patterns', 'status': 'published'},
        ],
        'displayOrder': 0,
        'isFreePreview': false,
        'accessType': 'free',
        'status': 'published',
      });

      expect(detail.videoCount, 2);
      expect(detail.hasQuiz, isTrue, reason: 'no longer tied to type == quiz');
      expect(detail.deckCount, 1);
      expect(detail.rapidRecalls.single.title, 'ECG patterns');
    });
  });

  group('the video length label', () {
    String? label(int? seconds) =>
        LessonVideo(videoUrl: 'x', durationSeconds: seconds).lengthLabel;

    expectLabel(int seconds, String want) =>
        test('$seconds s reads as $want', () => expect(label(seconds), want));

    expectLabel(610, '10:10');
    expectLabel(45, '0:45');
    expectLabel(9103, '2:31:43');

    test('a pasted link the server never measured says nothing', () {
      expect(label(null), isNull);
      expect(label(0), isNull);
    });
  });

  group('the course tree counts what is in a lesson', () {
    test('reads the counts the server sends', () {
      final lesson = tree.Lesson.fromJson({
        'id': 1,
        'title': 'Cardiology',
        'type': 'video',
        'displayOrder': 0,
        'isFreePreview': false,
        'status': 'published',
        'accessType': 'free',
        'videoUrl': 'https://cdn/one.mp4',
        'quizId': 12,
        '_count': {'videos': 3, 'rapidRecalls': 1},
      });

      expect(lesson.videoCount, 3);
      expect(lesson.deckCount, 1);
      expect(lesson.hasQuiz, isTrue);
      expect(lesson.hasVideo, isTrue);
    });

    test('an older server with no counts still draws the row right', () {
      final withVideo = tree.Lesson.fromJson({
        'id': 1,
        'title': 'Cardiology',
        'type': 'video',
        'displayOrder': 0,
        'isFreePreview': false,
        'status': 'published',
        'accessType': 'free',
        'videoUrl': 'https://cdn/one.mp4',
      });
      expect(withVideo.videoCount, 1);
      expect(withVideo.deckCount, 0);

      // The one case the row must not guess at: the key never arrived.
      final unknown = tree.Lesson.fromJson({
        'id': 2,
        'title': 'Unknown',
        'type': 'video',
        'displayOrder': 0,
        'isFreePreview': false,
        'status': 'published',
        'accessType': 'free',
      });
      expect(unknown.videoCount, 0);
      expect(unknown.hasVideo, isNull);
    });
  });
}
