class CourseType {
  final int id;
  final String title;
  final String? description;
  final String status;
  final String accessType;
  final int? displayOrder;

  CourseType({
    required this.id,
    required this.title,
    this.description,
    required this.status,
    required this.accessType,
    this.displayOrder,
  });

  factory CourseType.fromJson(Map<String, dynamic> json) {
    return CourseType(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      status: json['status'],
      accessType: json['accessType'],
      displayOrder: json['displayOrder'],
    );
  }
}

class CourseListGetModel {
  final int id;
  final String title;
  final String? description;
  final String? thumbnail;
  final List<CourseType> courseTypes; // NEW — replaces subjects
  final String status;
  final String accessType;
  final int displayOrder;
  final int lessonCount;
  final int enrolledCount;

  CourseListGetModel({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnail,
    required this.courseTypes,
    required this.status,
    required this.accessType,
    required this.displayOrder,
    required this.lessonCount,
    required this.enrolledCount,
  });

  factory CourseListGetModel.fromJson(Map<String, dynamic> json) {
    return CourseListGetModel(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      thumbnail: json['thumbnail'],
      courseTypes: (json['courseTypes'] as List<dynamic>? ?? [])
          .map((c) => CourseType.fromJson(c))
          .toList(),
      status: json['status'],
      accessType: json['accessType'],
      displayOrder: json['displayOrder'] ?? 0,
      lessonCount: json['lessonCount'] ?? 0,
      enrolledCount: json['enrolledCount'] ?? 0,
    );
  }
}