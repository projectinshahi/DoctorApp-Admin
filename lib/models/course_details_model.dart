import 'lesson_detail_model.dart'; // LessonPlanSummary + shared plan parsers

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

  /// The quiz this lesson serves, when the payload says. Parsed defensively:
  /// the course-details response may or may not nest it, and a lesson row
  /// showing nothing is better than one that guesses.
  final int? quizId;
  final String? quizSubjectName;
  final String? quizTopicName;

  /// Whether the payload actually carried a videoUrl key at all.
  /// Lets us tell "no video uploaded" apart from "the API never told us",
  /// so the list never claims a video exists when it doesn't.
  final bool videoKnown; // NEW

  /// How many videos and Rapid Recall decks the lesson holds. The tree sends
  /// the counts rather than the rows — the row draws "3 videos · 1 deck" and
  /// never the videos themselves.
  final int videoCount;
  final int deckCount;

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
    this.videoCount = 0,
    this.deckCount = 0,
    this.quizId,
    this.quizSubjectName,
    this.quizTopicName,
  });

  /// "Internal Med · Cardiology", or just whichever half arrived.
  String? get quizTaxonomyLabel {
    final parts = [quizSubjectName, quizTopicName]
        .whereType<String>()
        .where((p) => p.trim().isNotEmpty)
        .toList();
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// null  -> the API didn't include videoUrl, so we make no claim
  /// true  -> a video is actually attached
  /// false -> definitively no video, even though the lesson may be type 'video'
  bool? get hasVideo => videoCount > 0
      ? true
      : (!videoKnown ? null : (videoUrl != null && videoUrl!.isNotEmpty));

  bool get hasQuiz => quizId != null;

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
    // A response from before the counts existed falls back to the single
    // videoUrl, so an old server still draws the row right.
    videoCount: _count(json, "videos") ??
        ((json["videoUrl"] as String?)?.trim().isNotEmpty == true ? 1 : 0),
    deckCount: _count(json, "rapidRecalls") ?? 0,
    quizId: (json["quizId"] as num?)?.toInt(),
    quizSubjectName: _nestedName(json["quiz"], "subject"),
    quizTopicName: _nestedName(json["quiz"], "topic"),
  );

  /// One number out of Prisma's `_count` block, or null when the server did
  /// not send one.
  static int? _count(Map<String, dynamic> json, String key) {
    final counts = json["_count"];
    if (counts is! Map) return null;
    return (counts[key] as num?)?.toInt();
  }

  /// Reads quiz.subject.name / quiz.topic.name without assuming either level
  /// is present - every hop is optional in this payload.
  static String? _nestedName(dynamic quiz, String key) {
    if (quiz is! Map) return null;
    final nested = quiz[key];
    if (nested is Map) return nested['name'] as String?;
    return null;
  }

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