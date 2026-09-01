import 'package:flutter_test/flutter_test.dart';

import 'package:admin_drapp/models/admin_comment_model.dart';

/// The rules that decide whether this screen is any good: what counts as
/// needing review, and where the tab numbers come from.
void main() {
  final live = AdminComment.fromJson({
    'id': 1,
    'parentId': null,
    'isReply': false,
    'replyCount': 2,
    'body': 'Great explanation of the ECG axis — thanks!',
    'status': 'published',
    'createdAt': '2026-09-01T09:00:00.000Z',
    'user': {'id': 30, 'name': 'Keerthana Bineesh', 'email': 'k@example.com'},
    'lesson': {
      'id': 37,
      'title': 'Cardiology',
      'type': 'video',
      'commentsEnabled': true,
      'chapter': {'id': 17, 'title': 'Cardiology'},
      'course': {'id': 22, 'title': 'GP GULF LICENSING EXAM'},
      'courseType': null,
    },
    'reportCount': 1,
    'openReportCount': 1,
    'needsReview': true,
    'reports': [
      {'id': 1, 'reason': 'Off topic', 'createdAt': '2026-09-01T10:00:00.000Z',
       'resolvedAt': null, 'user': {'id': 31, 'name': 'Theertha bineesh14'}},
    ],
  });

  test('reads the live payload', () {
    expect(live.replyCount, 2);
    expect(live.user!.displayName, 'Keerthana Bineesh');
    expect(live.lesson!.title, 'Cardiology');
    // course is resolved server-side; never walked from chapter here.
    expect(live.lesson!.whereLabel, 'GP GULF LICENSING EXAM · Cardiology');
    expect(live.openReports.single.reason, 'Off topic');
  });

  group('needsReview', () {
    AdminComment build({required String status, required int open}) =>
        AdminComment.fromJson({
          'id': 2,
          'body': 'x',
          'status': status,
          'openReportCount': open,
        });

    test('is reported AND still visible', () {
      expect(build(status: 'published', open: 1).needsReview, isTrue);
    });

    test('a hidden comment is out of the queue', () {
      // Hiding agrees with the reports, which is what empties the queue.
      expect(build(status: 'hidden', open: 1).needsReview, isFalse);
    });

    test('no open reports is not review', () {
      expect(build(status: 'published', open: 0).needsReview, isFalse);
    });
  });

  group('counts drive the tabs', () {
    const counts =
        CommentCounts(all: 3, published: 3, hidden: 0, reported: 1);

    test('each tab reads its own number', () {
      expect(counts.forStatus('all'), 3);
      expect(counts.forStatus('published'), 3);
      expect(counts.forStatus('hidden'), 0);
      expect(counts.forStatus('reported'), 1);
    });

    test('counts are independent of any filtered list', () {
      // The reported tab shows 1 even while the list holds all 3 - binding to
      // comments.length would make every tab show the open tab's size.
      expect(counts.reported, isNot(counts.all));
    });
  });

  test('a missing name falls back to the email, then a placeholder', () {
    expect(const CommentUser(name: '  ', email: 'a@b.com').displayName,
        'a@b.com');
    expect(const CommentUser().displayName, 'Unknown student');
    expect(const CommentUser(name: 'Asha').initial, 'A');
  });

  test('a reply knows its parent even without the flag', () {
    final reply = AdminComment.fromJson(
        {'id': 9, 'body': 'x', 'status': 'published', 'parentId': 1});
    expect(reply.isReply, isTrue);
    expect(reply.parentId, 1);
  });

  group('instructor replies', () {
    final thread = CommentThread.fromJson({
      'focusCommentId': 12,
      'threadRootId': 11,
      'thread': {
        'id': 11,
        'body': 'I have a doubt can you please solve this',
        'status': 'published',
        'author': {'id': 30, 'name': 'Keerthana Bineesh', 'role': 'student'},
        'canReport': true,
        'replies': [
          {
            'id': 12,
            'parentId': 11,
            'body': 'Here is the explanation.',
            'status': 'published',
            'isInstructor': true,
            'isMine': true,
            'canReport': false,
            'author': {'id': 1, 'name': 'Super Admin', 'role': 'admin'},
          },
        ],
      },
    });

    test('carries the focus row and the whole tree', () {
      expect(thread.focusCommentId, 12);
      expect(thread.threadRootId, 11);
      expect(thread.root!.body, startsWith('I have a doubt'));
      expect(thread.replies.length, 1);
    });

    test('the tutor reply is flagged, not inferred from the id', () {
      // Admin 1 and student 1 are different people - ids come from different
      // tables, so ownership is never decided by comparing them.
      final reply = thread.replies.single;
      expect(reply.isInstructor, isTrue);
      expect(reply.user!.isAdmin, isTrue);
      expect(reply.isMine, isTrue);
    });

    test('an instructor reply cannot be reported', () {
      expect(thread.replies.single.canReport, isFalse);
      expect(thread.root!.canReport, isTrue);
    });

    test('only an admin\'s own comment is editable', () {
      expect(thread.replies.single.canEditBody, isTrue);
      // Rewriting a student's words is worse than anything they could write.
      expect(thread.root!.canEditBody, isFalse);
    });

    test('a hidden comment cannot be replied to', () {
      final hidden = AdminComment.fromJson(
          {'id': 5, 'body': 'x', 'status': 'hidden'});
      expect(hidden.canReply, isFalse);
      expect(thread.root!.canReply, isTrue);
    });
  });

  test('a resolved report is not an open one', () {
    final c = AdminComment.fromJson({
      'id': 4,
      'body': 'x',
      'status': 'published',
      'reportCount': 2,
      'openReportCount': 0,
      'reports': [
        {'id': 1, 'reason': 'Spam', 'resolvedAt': '2026-09-01T11:00:00.000Z'},
        {'id': 2, 'reason': 'Rude', 'resolvedAt': null},
      ],
    });

    expect(c.reports.length, 2);
    expect(c.openReports.length, 1);
    expect(c.needsReview, isFalse); // the server said zero open
  });
}
