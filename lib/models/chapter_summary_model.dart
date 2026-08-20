import 'lesson_model.dart';

/// A chapter ("syllabus" in the UI) as returned by
/// GET /api/course-types/:courseTypeId/chapters.
///
/// The endpoint nests each chapter's lessons already, ordered by
/// displayOrder, so one call per course type is enough - there is no second
/// request per chapter.
///
/// Note a chapter can hang off either a course type or a course directly
/// (both ids are nullable server-side). These routes only cover the
/// course-type side, so a chapter created straight under a course won't
/// appear here.
class ChapterSummary {
  final int id;
  final int? courseTypeId;
  final int? courseId;
  final String title;
  final int displayOrder;
  final List<Lesson> lessons;

  const ChapterSummary({
    required this.id,
    this.courseTypeId,
    this.courseId,
    required this.title,
    required this.displayOrder,
    this.lessons = const [],
  });

  int get lessonCount => lessons.length;

  factory ChapterSummary.fromJson(Map<String, dynamic> json) {
    final raw = json['lessons'];
    final lessons = raw is List
        ? (raw
            .whereType<Map<String, dynamic>>()
            .map(Lesson.fromJson)
            .toList()
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder)))
        : <Lesson>[];

    return ChapterSummary(
      id: json['id'] as int,
      courseTypeId: (json['courseTypeId'] as num?)?.toInt(),
      courseId: (json['courseId'] as num?)?.toInt(),
      title: (json['title'] ?? '') as String,
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
      lessons: lessons,
    );
  }
}

/// Reads the chapter list out of whichever envelope the API uses, sorted by
/// displayOrder. The server already sorts; this keeps the order correct even
/// if a caller hands us an unsorted array.
List<ChapterSummary> parseChapterSummaries(dynamic decoded) {
  List<Map<String, dynamic>> rows = const [];

  if (decoded is List) {
    rows = decoded.whereType<Map<String, dynamic>>().toList();
  } else if (decoded is Map) {
    for (final key in const ['chapters', 'data', 'items']) {
      final value = decoded[key];
      if (value is List) {
        rows = value.whereType<Map<String, dynamic>>().toList();
        break;
      }
    }
  }

  return rows.map(ChapterSummary.fromJson).toList()
    ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
}
