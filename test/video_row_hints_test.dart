import 'package:flutter_test/flutter_test.dart';

import 'package:admin_drapp/models/course_details_model.dart' as tree;
import 'package:admin_drapp/models/lesson_detail_model.dart';
import 'package:admin_drapp/widget/video_row_fields.dart';

void main() {
  group('a view count is the server\'s, never the panel\'s', () {
    test('read from the lesson, and zero when the server says nothing', () {
      expect(
        LessonVideo.fromJson({
          'videoUrl': 'https://cdn/one.mp4',
          'viewCount': 18400,
        }).viewCount,
        18400,
      );
      expect(
        LessonVideo.fromJson({'videoUrl': 'https://cdn/one.mp4'}).viewCount,
        0,
      );
    });

    test('never sent back on a save', () {
      final video = LessonVideo.fromJson({
        'videoUrl': 'https://cdn/one.mp4',
        'viewCount': 18400,
      });

      expect(video.toJson().containsKey('viewCount'), isFalse);
    });
  });

  group('the warning about changing a link', () {
    final saved = LessonVideo.fromJson({
      'videoUrl': 'https://cdn/one.mp4',
      'viewCount': 18400,
    });

    test('names what is lost once the link differs', () {
      expect(
        videoLinkChangeWarning(
          savedUrl: saved.videoUrl,
          currentUrl: 'https://cdn/two.mp4',
          viewCount: saved.viewCount,
        ),
        contains('18.4k views'),
      );
    });

    test('silent while the link is unchanged, spaces and all', () {
      expect(
        videoLinkChangeWarning(
          savedUrl: saved.videoUrl,
          currentUrl: '  https://cdn/one.mp4 ',
          viewCount: saved.viewCount,
        ),
        isNull,
      );
    });

    test('silent with nothing to lose - no views, or a brand new row', () {
      expect(
        videoLinkChangeWarning(
          savedUrl: saved.videoUrl,
          currentUrl: 'https://cdn/two.mp4',
          viewCount: 0,
        ),
        isNull,
      );
      expect(
        videoLinkChangeWarning(
          savedUrl: null,
          currentUrl: 'https://cdn/two.mp4',
          viewCount: 9,
        ),
        isNull,
      );
    });
  });

  group('a title that outgrows the app\'s two lines', () {
    test('quiet up to 60 characters, warns past it', () {
      expect(videoTitleWarning('a' * 60), isNull);
      expect(videoTitleWarning('a' * 61), 'Students see 2 lines.');
    });
  });

  group('the tree row explains why the app counts fewer videos', () {
    test('counts drafts when every row says whether it is published', () {
      final lesson = tree.Lesson.fromJson({
        'id': 1,
        'title': 'Pituitary Gland',
        'type': 'video',
        'videos': [
          {'videoUrl': 'https://cdn/one.mp4', 'status': 'published'},
          {'videoUrl': 'https://cdn/two.mp4', 'status': 'draft'},
        ],
      });

      expect(lesson.videoCount, 2);
      expect(lesson.draftVideoCount, 1);
    });

    test('a row that says nothing is published, as the server has it', () {
      final lesson = tree.Lesson.fromJson({
        'id': 1,
        'title': 'Pituitary Gland',
        'type': 'video',
        'videos': [
          {'videoUrl': 'https://cdn/one.mp4'},
          {'videoUrl': 'https://cdn/two.mp4', 'status': 'draft'},
        ],
      });

      expect(lesson.draftVideoCount, 1);
    });

    test('claims nothing when the tree sent counts only', () {
      final lesson = tree.Lesson.fromJson({
        'id': 1,
        'title': 'Pituitary Gland',
        'type': 'video',
        '_count': {'videos': 3},
      });

      expect(lesson.draftVideoCount, isNull);
    });
  });
}
