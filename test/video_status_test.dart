import 'package:flutter_test/flutter_test.dart';

import 'package:admin_drapp/models/lesson_detail_model.dart';
import 'package:admin_drapp/widget/video_status_switch.dart';

void main() {
  group('a video is draft or published', () {
    test('published unless the server says draft', () {
      expect(
        LessonVideo.fromJson({'videoUrl': 'https://cdn/one.mp4'}).isPublished,
        isTrue,
      );
      expect(
        LessonVideo.fromJson({
          'videoUrl': 'https://cdn/one.mp4',
          'status': 'draft',
        }).isPublished,
        isFalse,
      );
    });

    test('every saved row carries its status, so the list is replace-all', () {
      final draft = LessonVideo.fromJson({
        'videoUrl': 'https://cdn/one.mp4',
        'status': 'DRAFT',
      });

      expect(draft.toJson()['status'], 'draft');
      expect(
        LessonVideo.fromJson({'videoUrl': 'https://cdn/two.mp4'})
            .toJson()['status'],
        'published',
      );
    });

    test('a new row follows the lesson it is added to', () {
      expect(VideoStatusSwitch.defaultPublished(lessonPublished: false),
          isFalse);
      expect(
          VideoStatusSwitch.defaultPublished(lessonPublished: true), isTrue);
    });
  });
}
