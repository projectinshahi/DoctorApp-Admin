/// Response of GET /api/courses/:id/course-types.
///
/// A deliberately thin view of a course: exam types plus a chapter count,
/// and nothing nested. It exists because the full admin tree endpoint
/// (/api/courses/:id) reads lessons, and can fail independently of this one.
///
/// Two things it does NOT give you, both of which matter to the caller:
///   * only `status: published` exam types - drafts are absent, not empty
///   * no chapters and no lessons, only a per-type chapter count
library;

class CourseTypeSummary {
  final int id;
  final String title;
  final String? description;
  final String accessType;
  final int displayOrder;
  final int chapterCount;

  const CourseTypeSummary({
    required this.id,
    required this.title,
    this.description,
    required this.accessType,
    required this.displayOrder,
    required this.chapterCount,
  });

  factory CourseTypeSummary.fromJson(Map<String, dynamic> json) => CourseTypeSummary(
        id: json['id'] as int,
        title: (json['title'] ?? '') as String,
        description: json['description'] as String?,
        accessType: (json['accessType'] ?? 'free') as String,
        displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
        chapterCount: (json['chapterCount'] as num?)?.toInt() ?? 0,
      );
}

class CourseTypesResponse {
  final int courseId;
  final String courseTitle;
  final List<CourseTypeSummary> courseTypes;

  const CourseTypesResponse({
    required this.courseId,
    required this.courseTitle,
    required this.courseTypes,
  });

  factory CourseTypesResponse.fromJson(Map<String, dynamic> json) {
    final course = json['course'];
    final rawTypes = json['courseTypes'];

    return CourseTypesResponse(
      courseId: course is Map ? ((course['id'] as num?)?.toInt() ?? 0) : 0,
      courseTitle: course is Map ? ((course['title'] ?? '') as String) : '',
      courseTypes: rawTypes is List
          ? rawTypes
              .whereType<Map<String, dynamic>>()
              .map(CourseTypeSummary.fromJson)
              .toList()
          : const [],
    );
  }
}
