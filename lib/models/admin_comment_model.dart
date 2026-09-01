/// Models for comment moderation.
///
/// Note the mount: /admin/comments sits at the ROOT, like /admin/students and
/// /admin/me - not under /api/ where the course and test endpoints live.
library;

/// The tab counts.
///
/// This is the FULL set and does not change with the active filter. Binding
/// tabs to the returned list length instead would make every tab show the size
/// of whichever tab is open.
class CommentCounts {
  final int all;
  final int published;
  final int hidden;
  final int reported;

  const CommentCounts({
    this.all = 0,
    this.published = 0,
    this.hidden = 0,
    this.reported = 0,
  });

  int forStatus(String status) => switch (status) {
        'published' => published,
        'hidden' => hidden,
        'reported' => reported,
        _ => all,
      };

  factory CommentCounts.fromJson(Map<String, dynamic> json) => CommentCounts(
        all: (json['all'] as num?)?.toInt() ?? 0,
        published: (json['published'] as num?)?.toInt() ?? 0,
        hidden: (json['hidden'] as num?)?.toInt() ?? 0,
        reported: (json['reported'] as num?)?.toInt() ?? 0,
      );
}

class CommentUser {
  /// Not globally unique.
  ///
  /// Admins are not rows in `users`, so admin 1 and student 1 are different
  /// people. Never compare these ids to decide ownership - the server sends
  /// isMine, canReport and isInstructor already computed for that reason.
  final int? id;

  /// 'student' or 'admin'.
  final String? role;

  /// Nullable - fall back to the email, then to a placeholder.
  final String? name;

  /// Present for admins only.
  final String? email;

  final String? avatarUrl;

  const CommentUser({
    this.id,
    this.role,
    this.name,
    this.email,
    this.avatarUrl,
  });

  bool get isAdmin => role?.toLowerCase() == 'admin';

  String get displayName {
    final trimmed = name?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    final mail = email?.trim();
    if (mail != null && mail.isNotEmpty) return mail;
    return 'Unknown student';
  }

  String get initial =>
      displayName.trim().isEmpty ? '?' : displayName.trim()[0].toUpperCase();

  factory CommentUser.fromJson(Map<String, dynamic> json) => CommentUser(
        id: (json['id'] as num?)?.toInt(),
        role: json['role'] as String?,
        name: json['name'] as String?,
        email: json['email'] as String?,
        avatarUrl: json['avatarUrl'] as String?,
      );
}

/// Where a comment was written.
///
/// `course` is resolved server-side - a lesson reaches its course either
/// through its chapter or through the chapter's course type, and both columns
/// are in use. Never walk that chain here.
class CommentLesson {
  final int id;
  final String title;
  final String? type;
  final bool commentsEnabled;
  final String? chapterTitle;
  final int? courseId;
  final String? courseTitle;
  final String? courseTypeTitle;

  const CommentLesson({
    required this.id,
    required this.title,
    this.type,
    this.commentsEnabled = true,
    this.chapterTitle,
    this.courseId,
    this.courseTitle,
    this.courseTypeTitle,
  });

  /// "GP GULF LICENSING EXAM · Cardiology"
  String get whereLabel => [
        if (courseTitle != null) courseTitle!,
        if (courseTypeTitle != null) courseTypeTitle!,
        if (chapterTitle != null) chapterTitle!,
      ].join(' · ');

  factory CommentLesson.fromJson(Map<String, dynamic> json) {
    final chapter = json['chapter'];
    final course = json['course'];
    final courseType = json['courseType'];

    return CommentLesson(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: (json['title'] ?? 'Lesson') as String,
      type: json['type'] as String?,
      commentsEnabled: json['commentsEnabled'] as bool? ?? true,
      chapterTitle: chapter is Map ? chapter['title'] as String? : null,
      courseId: course is Map ? (course['id'] as num?)?.toInt() : null,
      courseTitle: course is Map ? course['title'] as String? : null,
      courseTypeTitle:
          courseType is Map ? courseType['title'] as String? : null,
    );
  }
}

/// One report filed against a comment.
class CommentReport {
  final int id;
  final String reason;
  final DateTime? createdAt;
  final DateTime? resolvedAt;
  final CommentUser? user;

  const CommentReport({
    required this.id,
    required this.reason,
    this.createdAt,
    this.resolvedAt,
    this.user,
  });

  bool get isOpen => resolvedAt == null;

  factory CommentReport.fromJson(Map<String, dynamic> json) => CommentReport(
        id: (json['id'] as num?)?.toInt() ?? 0,
        reason: (json['reason'] ?? 'No reason given') as String,
        createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}'),
        resolvedAt: DateTime.tryParse('${json['resolvedAt'] ?? ''}'),
        user: json['user'] is Map<String, dynamic>
            ? CommentUser.fromJson(json['user'] as Map<String, dynamic>)
            : null,
      );
}

class AdminComment {
  final int id;
  final int? parentId;
  final bool isReply;
  final int replyCount;
  final String body;

  /// 'published' or 'hidden'. There is no 'reported' status in the database -
  /// a report is something that happened TO a comment, not a state it is in,
  /// because a reported comment stays visible until someone acts on it.
  final String status;

  final DateTime? createdAt;
  final DateTime? editedAt;

  final CommentUser? user;
  final CommentLesson? lesson;

  final int reportCount;
  final int openReportCount;
  final bool needsReview;
  final List<CommentReport> reports;

  /// Written by a tutor, not a student. The answer the thread was opened for.
  final bool isInstructor;

  /// Whether the signed-in admin wrote it. Server-computed - see [CommentUser.id].
  final bool isMine;

  /// False on instructor replies: the report queue is for student-to-student
  /// trouble, and a Report button on the tutor is noise.
  final bool canReport;

  /// Replies, when a thread was loaded for this comment.
  final List<AdminComment> replies;

  const AdminComment({
    required this.id,
    this.parentId,
    this.isReply = false,
    this.replyCount = 0,
    required this.body,
    required this.status,
    this.createdAt,
    this.editedAt,
    this.user,
    this.lesson,
    this.reportCount = 0,
    this.openReportCount = 0,
    this.needsReview = false,
    this.reports = const [],
    this.isInstructor = false,
    this.isMine = false,
    this.canReport = true,
    this.replies = const [],
  });

  /// An admin may fix their own wording, never a student's.
  ///
  /// Putting words in someone's mouth is worse than any comment they could
  /// leave, so the server refuses it with a 403 and the button is hidden here
  /// rather than offered and then denied.
  bool get canEditBody => isMine;

  /// A visible reply under an invisible comment reads as a reply to nothing,
  /// so the server refuses it with a 409.
  bool get canReply => !isHidden;

  bool get isHidden => status.toLowerCase() == 'hidden';
  bool get isEdited => editedAt != null;

  List<CommentReport> get openReports =>
      reports.where((r) => r.isOpen).toList();

  factory AdminComment.fromJson(Map<String, dynamic> json) {
    final rawReports = json['reports'];
    final status = (json['status'] ?? 'published') as String;
    final openReports = (json['openReportCount'] as num?)?.toInt() ?? 0;

    return AdminComment(
      id: (json['id'] as num?)?.toInt() ?? 0,
      parentId: (json['parentId'] as num?)?.toInt(),
      isReply: json['isReply'] as bool? ?? json['parentId'] != null,
      replyCount: (json['replyCount'] as num?)?.toInt() ?? 0,
      body: (json['body'] ?? '') as String,
      status: status,
      createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}'),
      editedAt: DateTime.tryParse('${json['editedAt'] ?? ''}'),
      // 'author' on the reply and thread responses, 'user' on the list.
      user: json['author'] is Map<String, dynamic>
          ? CommentUser.fromJson(json['author'] as Map<String, dynamic>)
          : json['user'] is Map<String, dynamic>
              ? CommentUser.fromJson(json['user'] as Map<String, dynamic>)
              : null,
      lesson: json['lesson'] is Map<String, dynamic>
          ? CommentLesson.fromJson(json['lesson'] as Map<String, dynamic>)
          : null,
      reportCount: (json['reportCount'] as num?)?.toInt() ?? 0,
      openReportCount: openReports,
      // Derived the same way the server does, so a response without the flag
      // still marks the row that needs a moderator.
      needsReview: json['needsReview'] as bool? ??
          (openReports > 0 && status.toLowerCase() == 'published'),
      reports: rawReports is List
          ? rawReports
              .whereType<Map<String, dynamic>>()
              .map(CommentReport.fromJson)
              .toList()
          : const [],
      isInstructor: json['isInstructor'] as bool? ?? false,
      isMine: json['isMine'] as bool? ?? false,
      // Defaults to true so a payload without the flag still offers the
      // action; the server has the final say either way.
      canReport: json['canReport'] as bool? ?? true,
      replies: json['replies'] is List
          ? (json['replies'] as List)
              .whereType<Map<String, dynamic>>()
              .map(AdminComment.fromJson)
              .toList()
          : const [],
    );
  }
}

/// The whole conversation, from GET /admin/comments/:id.
///
/// Any id in the thread returns the same tree - opening a reply and getting a
/// fragment would be useless.
class CommentThread {
  /// The row to scroll to and highlight.
  final int? focusCommentId;

  final int? threadRootId;

  /// The opening comment, with its replies attached.
  final AdminComment? root;

  const CommentThread({this.focusCommentId, this.threadRootId, this.root});

  List<AdminComment> get replies => root?.replies ?? const [];

  factory CommentThread.fromJson(Map<String, dynamic> json) {
    final thread = json['thread'];
    return CommentThread(
      focusCommentId: (json['focusCommentId'] as num?)?.toInt(),
      threadRootId: (json['threadRootId'] as num?)?.toInt(),
      root: thread is Map<String, dynamic>
          ? AdminComment.fromJson(thread)
          : null,
    );
  }
}
