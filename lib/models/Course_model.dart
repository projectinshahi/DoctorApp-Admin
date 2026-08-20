class CourseTypeModel {
  final int? id;
  final String title;
  final String? description;
  final String status;
  final String accessType;
  final int? displayOrder;

  CourseTypeModel({
    this.id,
    required this.title,
    this.description,
    required this.status,
    required this.accessType,
    this.displayOrder,
  });

  factory CourseTypeModel.fromJson(Map<String, dynamic> json) {
    return CourseTypeModel(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      status: json['status'],
      accessType: json['accessType'],
      displayOrder: json['displayOrder'],
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'title': title,
      'status': status,
      'accessType': accessType,
    };
    if (description != null && description!.isNotEmpty) {
      map['description'] = description;
    }
    if (displayOrder != null) {
      map['displayOrder'] = displayOrder;
    }
    return map;
  }
}

class CourseModel {
  final int id;
  final String title;
  final String? description;
  final String? thumbnail;
  final String? classGrade;
  final String? difficulty;
  final String status;
  final String accessType;
  final int displayOrder;
  final String? createdAt;
  final String? updatedAt;
  final List<CourseTypeModel> courseTypes;

  CourseModel({
    required this.id,
    required this.title,
    this.description,
    this.thumbnail,
    this.classGrade,
    this.difficulty,
    required this.status,
    required this.accessType,
    required this.displayOrder,
    this.createdAt,
    this.updatedAt,
    this.courseTypes = const [],
  });

  factory CourseModel.fromJson(Map<String, dynamic> json) {
    return CourseModel(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      thumbnail: json['thumbnail'],
      classGrade: json['classGrade'],
      difficulty: json['difficulty'],
      status: json['status'],
      accessType: json['accessType'],
      displayOrder: json['displayOrder'] ?? 0,
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
      courseTypes: (json['courseTypes'] as List<dynamic>? ?? [])
          .map((e) => CourseTypeModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CreateCourseResponse {
  final CourseModel course;

  CreateCourseResponse({required this.course});

  factory CreateCourseResponse.fromJson(Map<String, dynamic> json) {
    return CreateCourseResponse(
      course: CourseModel.fromJson(json['course']),
    );
  }
}

