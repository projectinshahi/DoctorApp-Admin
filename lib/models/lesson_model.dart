import '../services/lesson_services.dart';
import 'lesson_detail_model.dart'; // LessonPlanSummary + shared plan parsers // for LessonType / LessonAccessType / LessonStatus enums

/// The single source of truth for the Lesson model across the whole app.
class Lesson {
  final int id;
  final int chapterId;
  final String title;
  final String? description;
  final String type;                // raw API value: 'video' | 'text' | 'quiz'
  final String? videoUrl;
  final String? videoPublicId;
  final String? thumbnailUrl;
  final String? thumbnailPublicId;
  final String? noteUrl;
  final String? notePublicId;
  final String? noteFileType;
  final String? content;            // quiz reference

  /// Optional, and for filtering only: it does not change what a student
  /// sees. A quiz lesson with none borrows its quiz's subject server-side.
  final int? subjectId;
  final int displayOrder;
  final bool isFreePreview;
  final String accessType;          // raw API value: 'free' | 'premium'
  final String status;              // raw API value: 'draft' | 'published' | 'archived'
  final int? planId;                // NEW - first/legacy plan id
  final List<LessonPlanSummary> plans; // NEW - every plan that unlocks it
  final Set<int> planIds;           // NEW - empty means any active subscription
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Lesson({
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
    this.subjectId,
    required this.displayOrder,
    required this.isFreePreview,
    required this.accessType,
    required this.status,
    this.planId,
    this.plans = const [],
    this.planIds = const {},
    this.createdAt,
    this.updatedAt,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
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
      subjectId: (json['subjectId'] as num?)?.toInt(),
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
      isFreePreview: json['isFreePreview'] as bool? ?? false,
      accessType: json['accessType'] as String? ?? 'free',
      status: json['status'] as String? ?? 'draft',
      planId: json['planId'] as int?,
      plans: parseLessonPlans(json),
      planIds: parseLessonPlanIds(json),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chapterId': chapterId,
      'title': title,
      'description': description,
      'type': type,
      'videoUrl': videoUrl,
      'videoPublicId': videoPublicId,
      'thumbnailUrl': thumbnailUrl,
      'thumbnailPublicId': thumbnailPublicId,
      'noteUrl': noteUrl,
      'notePublicId': notePublicId,
      'noteFileType': noteFileType,
      'content': content,
      'subjectId': subjectId,
      'displayOrder': displayOrder,
      'isFreePreview': isFreePreview,
      'accessType': accessType,
      'status': status,
      'planId': planId,
      'planIds': planIds.toList(),
    };
  }

  bool get hasVideo => videoUrl != null && videoUrl!.isNotEmpty;
  bool get hasThumbnail => thumbnailUrl != null && thumbnailUrl!.isNotEmpty;
  bool get hasNote => noteUrl != null && noteUrl!.isNotEmpty;
  bool get hasDescription => description != null && description!.trim().isNotEmpty;

  LessonType get typeEnum => LessonTypeX.fromApiValue(type);
  LessonAccessType get accessTypeEnum => LessonAccessTypeX.fromApiValue(accessType);
  LessonStatus get statusEnum => LessonStatusX.fromApiValue(status);
}