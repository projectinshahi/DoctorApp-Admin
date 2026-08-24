import '../services/lesson_services.dart';
import 'quiz_model.dart';

/// Minimal parent-chapter info, only present when the lesson was fetched
/// with ?includeChapter=true.
class LessonChapterSummary {
  final int id;
  final String title;
  final int? courseId;
  final int? courseTypeId;

  const LessonChapterSummary({
    required this.id,
    required this.title,
    this.courseId,
    this.courseTypeId,
  });

  factory LessonChapterSummary.fromJson(Map<String, dynamic> json) {
    return LessonChapterSummary(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      courseId: json['courseId'] as int?,
      courseTypeId: json['courseTypeId'] as int?,
    );
  }
}

/// The plan the API nests on a lesson (LESSON_SELECT.plan). Enough to render
/// the subscription card without a second round-trip to /courses/x/plans.
class LessonPlanSummary {
  final int id;
  final String title;
  final double price;
  final int durationDays;
  final bool isActive;

  const LessonPlanSummary({
    required this.id,
    required this.title,
    required this.price,
    required this.durationDays,
    required this.isActive,
  });

  factory LessonPlanSummary.fromJson(Map<String, dynamic> json) {
    return LessonPlanSummary(
      id: json['id'] as int,
      title: json['title'] as String? ?? 'Plan #${json['id']}',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      durationDays: (json['durationDays'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}

/// Reads the plans attached to a lesson out of any lesson payload.
///
/// Three shapes are accepted so the app works before and after the backend
/// gains many-to-many plans:
///   `plans: [{...}]`  - the multi-plan shape (preferred)
///   `plan:  {...}`    - the single nested plan the API sends today
///   `planId: 3`       - id only, no nested object (list endpoints)
List<LessonPlanSummary> parseLessonPlans(Map<String, dynamic> json) {
  final raw = json['plans'];
  if (raw is List) {
    return raw.whereType<Map<String, dynamic>>().map(LessonPlanSummary.fromJson).toList();
  }
  final one = json['plan'];
  if (one is Map<String, dynamic>) return [LessonPlanSummary.fromJson(one)];
  return const [];
}

/// Every plan id that unlocks a lesson. Empty on a premium lesson means
/// "any active subscription for the course".
Set<int> parseLessonPlanIds(Map<String, dynamic> json) {
  final ids = json['planIds'];
  if (ids is List) return ids.whereType<num>().map((e) => e.toInt()).toSet();
  final fromObjects = parseLessonPlans(json).map((p) => p.id).toSet();
  if (fromObjects.isNotEmpty) return fromObjects;
  final single = json['planId'];
  return single is num ? {single.toInt()} : <int>{};
}

/// Full lesson detail - matches the backend's LESSON_SELECT exactly:
/// video (url + publicId), thumbnail (url + publicId), notes (url +
/// publicId + fileType), quiz content, and access settings. Used for
/// both the chapter's lesson list and the single-lesson detail screen.
class LessonDetail {
  final int id;
  final int chapterId;
  final String title;
  final String? description;
  final String type; // raw API value: 'video' | 'text' | 'quiz'
  final String? videoUrl;
  final String? videoPublicId;
  final String? thumbnailUrl;
  final String? thumbnailPublicId;
  final String? noteUrl;
  final String? notePublicId;
  final String? noteFileType; // 'pdf' | 'doc' | 'docx'
  /// Legacy free-text quiz reference. Superseded by [quizId]; kept so old
  /// lessons can still show what they used to point at. Never written back.
  final String? content;

  /// The linked Quiz, set only when type == 'quiz'.
  final int? quizId;

  /// The linked quiz itself, nested by GET /api/lessons/:id. Null on every
  /// non-quiz lesson, and on a quiz lesson with nothing linked yet - so it
  /// carries the live pool counters without a second request.
  final Quiz? quiz;
  final int displayOrder;
  final bool isFreePreview;
  final String accessType; // raw API value: 'free' | 'premium'
  final String status; // raw API value: 'draft' | 'published' | 'archived'
  final int? planId; // specific plan required when accessType == 'premium'

  /// Every plan that unlocks this lesson. The API sends a single nested
  /// `plan` today; `plans: [...]` is read first so a future many-to-many
  /// backend needs no client change.
  final List<LessonPlanSummary> plans;

  /// Ids of every plan that unlocks this lesson. Empty on a premium lesson
  /// means "any active subscription".
  final Set<int> planIds;

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final LessonChapterSummary? chapter; // only present with includeChapter=true

  const LessonDetail({
    required this.id,
    required this.chapterId,
    required this.title,
    this.description,
    required this.type,
    this.videoUrl,
    this.videoPublicId,
    this.thumbnailUrl,
    this.thumbnailPublicId,
    this.noteUrl,
    this.notePublicId,
    this.noteFileType,
    this.content,
    this.quizId,
    this.quiz,
    required this.displayOrder,
    required this.isFreePreview,
    required this.accessType,
    required this.status,
    this.planId,
    this.plans = const [],
    this.planIds = const {},
    this.createdAt,
    this.updatedAt,
    this.chapter,
  });

  factory LessonDetail.fromJson(Map<String, dynamic> json) {
    return LessonDetail(
      id: json['id'] as int,
      chapterId: json['chapterId'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      type: json['type'] as String? ?? 'text',
      videoUrl: json['videoUrl'] as String?,
      videoPublicId: json['videoPublicId'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      thumbnailPublicId: json['thumbnailPublicId'] as String?,
      noteUrl: json['noteUrl'] as String?,
      notePublicId: json['notePublicId'] as String?,
      noteFileType: json['noteFileType'] as String?,
      content: json['content'] as String?,
      quizId: (json['quizId'] as num?)?.toInt(),
      quiz: json['quiz'] is Map<String, dynamic>
          ? Quiz.fromJson(json['quiz'] as Map<String, dynamic>)
          : null,
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
      isFreePreview: json['isFreePreview'] as bool? ?? false,
      accessType: json['accessType'] as String? ?? 'free',
      status: json['status'] as String? ?? 'draft',
      planId: json['planId'] as int?,
      plans: parseLessonPlans(json),
      planIds: parseLessonPlanIds(json),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'] as String) : null,
      chapter: json['chapter'] != null
          ? LessonChapterSummary.fromJson(json['chapter'] as Map<String, dynamic>)
          : null,
    );
  }

  bool get hasVideo => videoUrl != null && videoUrl!.isNotEmpty;
  bool get hasNote => noteUrl != null && noteUrl!.isNotEmpty;
  bool get hasThumbnail => thumbnailUrl != null && thumbnailUrl!.isNotEmpty;

  /// Kept as the old name so existing call sites keep reading.
  Set<int> get requiredPlanIds => planIds;

  LessonType get typeEnum => LessonTypeX.fromApiValue(type);
  LessonAccessType get accessTypeEnum => LessonAccessTypeX.fromApiValue(accessType);
  LessonStatus get statusEnum => LessonStatusX.fromApiValue(status);
}
