import '../services/lesson_services.dart'; // for LessonType / LessonAccessType enums

/// The single source of truth for the Lesson model across the whole app.
/// Do NOT define another `Lesson` class anywhere else (e.g. inside
/// course_details_model.dart) - having two classes with the same name
/// is exactly what causes "getter isn't defined" errors like this.
class Lesson {
  final int id;
  final int chapterId;
  final String title;
  final String? description;        // NEW - optional longer text about the lesson
  final String type;                // raw API value: 'video' | 'text' | 'quiz'
  final String? videoUrl;           // optional - uploaded video file URL (Cloudinary)
  final String? videoPublicId;      // Cloudinary public_id, needed to replace/delete the video
  final String? thumbnailUrl;       // NEW - preview image URL (Cloudinary)
  final String? thumbnailPublicId;  // NEW - Cloudinary public_id, needed to replace/delete the thumbnail
  final String? noteUrl;            // optional - uploaded PDF/DOC/DOCX file URL (Cloudinary)
  final String? notePublicId;       // Cloudinary public_id, needed to replace/delete the note
  final String? noteFileType;       // 'pdf' | 'doc' | 'docx', tells the UI which icon/viewer to use
  final String? content;            // quiz reference, only meaningful when type == 'quiz'
  final int displayOrder;
  final bool isFreePreview;
  final String accessType;          // raw API value: 'free' | 'premium'
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
    required this.displayOrder,
    required this.isFreePreview,
    required this.accessType,
    this.createdAt,
    this.updatedAt,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'] as int,
      chapterId: json['chapterId'] as int? ?? 0, // defensive: may be omitted in nested JSON
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
      'displayOrder': displayOrder,
      'isFreePreview': isFreePreview,
      'accessType': accessType,
    };
  }

  bool get hasVideo => videoUrl != null && videoUrl!.isNotEmpty;
  bool get hasThumbnail => thumbnailUrl != null && thumbnailUrl!.isNotEmpty;
  bool get hasNote => noteUrl != null && noteUrl!.isNotEmpty;
  bool get hasDescription => description != null && description!.trim().isNotEmpty;

  LessonType get typeEnum => LessonTypeX.fromApiValue(type);
  LessonAccessType get accessTypeEnum => LessonAccessTypeX.fromApiValue(accessType);
}