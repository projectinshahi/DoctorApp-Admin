import '../services/lesson_services.dart';

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
  final String? content; // quiz reference, only meaningful when type == 'quiz'
  final int displayOrder;
  final bool isFreePreview;
  final String accessType; // raw API value: 'free' | 'premium'
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
    required this.displayOrder,
    required this.isFreePreview,
    required this.accessType,
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
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
      isFreePreview: json['isFreePreview'] as bool? ?? false,
      accessType: json['accessType'] as String? ?? 'free',
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

  LessonType get typeEnum => LessonTypeX.fromApiValue(type);
  LessonAccessType get accessTypeEnum => LessonAccessTypeX.fromApiValue(accessType);
}