import 'dart:convert';
import 'lesson_detail_model.dart'; // LessonPlanSummary + shared plan parsers

CourseDetailsResponse courseDetailsResponseFromJson(String str) =>
    CourseDetailsResponse.fromJson(json.decode(str));

String courseDetailsResponseToJson(CourseDetailsResponse data) =>
    json.encode(data.toJson());

class CourseDetailsResponse {
  final CourseDetails course;

  CourseDetailsResponse({required this.course});

  factory CourseDetailsResponse.fromJson(Map<String, dynamic> json) =>
      CourseDetailsResponse(
        course: CourseDetails.fromJson(json["course"]),
      );

  Map<String, dynamic> toJson() => {
    "course": course.toJson(),
  };
}

class CourseDetails {
  final int id;
  final String title;
  final String description;
  final String? thumbnail;
  final String? classGrade;
  final String? difficulty;
  final String status;
  final String accessType;
  final int displayOrder;
  final dynamic createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final dynamic admin;
  final List<CourseType> courseTypes;
  final List<Chapter> chapters;
  final int chapterCount;
  final int lessonCount;

  CourseDetails({
    required this.id,
    required this.title,
    required this.description,
    this.thumbnail,
    this.classGrade,
    this.difficulty,
    required this.status,
    required this.accessType,
    required this.displayOrder,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.admin,
    required this.courseTypes,
    required this.chapters,
    required this.chapterCount,
    required this.lessonCount,
  });

  bool get hasCourseTypes => courseTypes.isNotEmpty;

  factory CourseDetails.fromJson(Map<String, dynamic> json) => CourseDetails(
    id: json["id"],
    title: json["title"] ?? '',
    description: json["description"] ?? '',
    thumbnail: json["thumbnail"],
    classGrade: json["classGrade"],
    difficulty: json["difficulty"],
    status: json["status"] ?? '',
    accessType: json["accessType"] ?? '',
    displayOrder: json["displayOrder"] ?? 0,
    createdBy: json["createdBy"],
    createdAt: DateTime.parse(json["createdAt"]),
    updatedAt: DateTime.parse(json["updatedAt"]),
    admin: json["admin"],
    courseTypes: json["courseTypes"] == null
        ? []
        : List<CourseType>.from(
      json["courseTypes"].map((x) => CourseType.fromJson(x)),
    ),
    chapters: json["chapters"] == null
        ? []
        : List<Chapter>.from(
      json["chapters"].map((x) => Chapter.fromJson(x)),
    ),
    chapterCount: json["chapterCount"] ?? 0,
    lessonCount: json["lessonCount"] ?? 0,
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "title": title,
    "description": description,
    "thumbnail": thumbnail,
    "classGrade": classGrade,
    "difficulty": difficulty,
    "status": status,
    "accessType": accessType,
    "displayOrder": displayOrder,
    "createdBy": createdBy,
    "createdAt": createdAt.toIso8601String(),
    "updatedAt": updatedAt.toIso8601String(),
    "admin": admin,
    "courseTypes": List<dynamic>.from(courseTypes.map((x) => x.toJson())),
    "chapters": List<dynamic>.from(chapters.map((x) => x.toJson())),
    "chapterCount": chapterCount,
    "lessonCount": lessonCount,
  };
}

class CourseType {
  final int id;
  final String title;
  final String? description;
  final String status;
  final String accessType;
  final int? displayOrder;
  final List<Chapter> chapters;

  CourseType({
    required this.id,
    required this.title,
    this.description,
    required this.status,
    required this.accessType,
    this.displayOrder,
    required this.chapters,
  });

  factory CourseType.fromJson(Map<String, dynamic> json) => CourseType(
    id: json["id"],
    title: json["title"] ?? '',
    description: json["description"],
    status: json["status"] ?? '',
    accessType: json["accessType"] ?? '',
    displayOrder: json["displayOrder"],
    chapters: json["chapters"] == null
        ? []
        : List<Chapter>.from(
      json["chapters"].map((x) => Chapter.fromJson(x)),
    ),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "title": title,
    "description": description,
    "status": status,
    "accessType": accessType,
    "displayOrder": displayOrder,
    "chapters": List<dynamic>.from(chapters.map((x) => x.toJson())),
  };
}

class Chapter {
  final int id;
  final String title;
  final int displayOrder;
  final List<Lesson> lessons;

  Chapter({
    required this.id,
    required this.title,
    required this.displayOrder,
    required this.lessons,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) => Chapter(
    id: json["id"],
    title: json["title"] ?? '',
    displayOrder: json["displayOrder"] ?? 0,
    lessons: json["lessons"] == null
        ? []
        : List<Lesson>.from(
      json["lessons"].map((x) => Lesson.fromJson(x)),
    ),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "title": title,
    "displayOrder": displayOrder,
    "lessons": List<dynamic>.from(lessons.map((x) => x.toJson())),
  };
}

class Lesson {
  final int id;
  final String title;
  final String type;
  final String? content;
  final int displayOrder;
  final bool isFreePreview;
  final String status; // NEW
  final String accessType; // NEW
  final int? planId; // NEW - first/legacy plan, kept for older payloads
  /// Every plan that unlocks this lesson. Empty on a premium lesson means
  /// "any active subscription".
  final List<LessonPlanSummary> plans; // NEW
  final Set<int> planIds; // NEW
  final String? videoUrl; // NEW - backend must include this in the lessons payload

  /// Whether the payload actually carried a videoUrl key at all.
  /// Lets us tell "no video uploaded" apart from "the API never told us",
  /// so the list never claims a video exists when it doesn't.
  final bool videoKnown; // NEW

  Lesson({
    required this.id,
    required this.title,
    required this.type,
    this.content,
    required this.displayOrder,
    required this.isFreePreview,
    required this.status, // NEW
    required this.accessType, // NEW
    this.planId, // NEW
    this.plans = const [], // NEW
    this.planIds = const {}, // NEW
    this.videoUrl, // NEW
    this.videoKnown = false, // NEW
  });

  /// null  -> the API didn't include videoUrl, so we make no claim
  /// true  -> a video is actually attached
  /// false -> definitively no video, even though the lesson may be type 'video'
  bool? get hasVideo =>
      !videoKnown ? null : (videoUrl != null && videoUrl!.isNotEmpty);

  factory Lesson.fromJson(Map<String, dynamic> json) => Lesson(
    id: json["id"],
    title: json["title"] ?? '',
    type: json["type"] ?? '',
    content: json["content"],
    displayOrder: json["displayOrder"] ?? 0,
    isFreePreview: json["isFreePreview"] ?? false,
    status: json["status"] ?? 'draft', // NEW
    accessType: json["accessType"] ?? 'free', // NEW
    planId: json["planId"], // NEW
    plans: parseLessonPlans(json), // NEW
    planIds: parseLessonPlanIds(json), // NEW
    videoUrl: json["videoUrl"], // NEW
    videoKnown: json.containsKey("videoUrl"), // NEW
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "title": title,
    "type": type,
    "content": content,
    "displayOrder": displayOrder,
    "isFreePreview": isFreePreview,
    "status": status, // NEW
    "accessType": accessType, // NEW
    "planId": planId, // NEW
    "planIds": planIds.toList(), // NEW
    "videoUrl": videoUrl, // NEW
  };
}