/// Question bank models: Subject -> Topic -> Question (-> QuestionOption).
///
/// A separate tree from Course -> CourseType -> Chapter -> Lesson: subjects
/// aren't scoped to a course, which is why the Question Bank is its own
/// top-level nav destination.
library;

// ── Enums ───────────────────────────────────────────────────────────
// Same apiValue / fromApiValue extension pattern as LessonTypeX and
// LessonStatusX in lesson_services.dart.

enum Difficulty { easy, medium, hard }

extension DifficultyX on Difficulty {
  String get apiValue => name;

  String get label => switch (this) {
        Difficulty.easy => 'Easy',
        Difficulty.medium => 'Medium',
        Difficulty.hard => 'Hard',
      };

  static Difficulty fromApiValue(String? value) {
    return Difficulty.values.firstWhere(
      (d) => d.apiValue == value,
      orElse: () => Difficulty.medium,
    );
  }
}

enum QuestionStatus { active, inactive }

extension QuestionStatusX on QuestionStatus {
  String get apiValue => name;

  String get label => this == QuestionStatus.active ? 'Active' : 'Inactive';

  static QuestionStatus fromApiValue(String? value) {
    return QuestionStatus.values.firstWhere(
      (s) => s.apiValue == value,
      orElse: () => QuestionStatus.active,
    );
  }
}

// ── Subject / Topic ─────────────────────────────────────────────────

class Subject {
  final int id;
  final String name;
  final bool isActive;
  final int displayOrder;

  const Subject({
    required this.id,
    required this.name,
    this.isActive = true,
    this.displayOrder = 0,
  });

  /// Tolerates the abbreviated `{ id, name }` shape the API nests on a
  /// question, where isActive/displayOrder simply aren't sent.
  factory Subject.fromJson(Map<String, dynamic> json) => Subject(
        id: json['id'] as int,
        name: (json['name'] ?? '') as String,
        isActive: json['isActive'] as bool? ?? true,
        displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'isActive': isActive,
        'displayOrder': displayOrder,
      };
}

class Topic {
  final int id;
  final int subjectId;
  final String name;
  final bool isActive;
  final int displayOrder;

  const Topic({
    required this.id,
    required this.subjectId,
    required this.name,
    this.isActive = true,
    this.displayOrder = 0,
  });

  factory Topic.fromJson(Map<String, dynamic> json) => Topic(
        id: json['id'] as int,
        subjectId: (json['subjectId'] as num?)?.toInt() ?? 0,
        name: (json['name'] ?? '') as String,
        isActive: json['isActive'] as bool? ?? true,
        displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'isActive': isActive,
        'displayOrder': displayOrder,
      };
}

// ── Option ──────────────────────────────────────────────────────────

class QuestionOption {
  /// Null for a row the admin just added and hasn't saved yet.
  final int? id;
  final String optionText;

  /// A plain URL string - options have no upload flow.
  final String? optionImageUrl;
  final bool isCorrect;
  final int displayOrder;

  const QuestionOption({
    this.id,
    required this.optionText,
    this.optionImageUrl,
    required this.isCorrect,
    this.displayOrder = 0,
  });

  factory QuestionOption.fromJson(Map<String, dynamic> json) => QuestionOption(
        id: (json['id'] as num?)?.toInt(),
        optionText: (json['optionText'] ?? '') as String,
        optionImageUrl: json['optionImageUrl'] as String?,
        isCorrect: json['isCorrect'] as bool? ?? false,
        displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
      );

  /// Server-owned ids stay server-side; displayOrder travels because the
  /// sheet lets the admin reorder options.
  Map<String, dynamic> toPayload() => {
        'optionText': optionText,
        'optionImageUrl': optionImageUrl,
        'isCorrect': isCorrect,
        'displayOrder': displayOrder,
      };
}

// ── Tag ─────────────────────────────────────────────────────────────

class QuestionTag {
  final int id;
  final String name;

  const QuestionTag({required this.id, required this.name});

  factory QuestionTag.fromJson(Map<String, dynamic> json) => QuestionTag(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: (json['name'] ?? '') as String,
      );
}

// ── Question ────────────────────────────────────────────────────────

class Question {
  final int id;
  final int subjectId;
  final int topicId;
  final String questionText;

  /// Plain URL string, no picker and no multipart upload.
  final String? questionImageUrl;

  final Difficulty difficulty;
  final num marksCorrect;
  final num marksIncorrect;
  final String? explanation;
  final QuestionStatus status;

  /// Nested on the response as `{ id, name }`.
  final Subject? subject;
  final Topic? topic;

  final List<QuestionOption> options;

  final List<QuestionTag> tags;
  final List<int> tagIds;

  /// The editable form of the tags - what the create/update payload sends.
  final List<String> tagNames;

  final int? correctOptionId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Question({
    required this.id,
    required this.subjectId,
    required this.topicId,
    required this.questionText,
    this.questionImageUrl,
    required this.difficulty,
    required this.marksCorrect,
    required this.marksIncorrect,
    this.explanation,
    required this.status,
    this.subject,
    this.topic,
    this.options = const [],
    this.tags = const [],
    this.tagIds = const [],
    this.tagNames = const [],
    this.correctOptionId,
    this.createdAt,
    this.updatedAt,
  });

  String? get subjectName => subject?.name;
  String? get topicName => topic?.name;

  /// A duplicate comes back inactive with "(Copy)" appended and needs a human
  /// to look at it. Both signals must hold, so an ordinary deactivated
  /// question isn't mislabelled as an unreviewed copy.
  bool get isUnreviewedCopy =>
      status == QuestionStatus.inactive && questionText.contains('(Copy)');

  factory Question.fromJson(Map<String, dynamic> json) {
    final options = parseEnvelopeList(json['options'], const [])
        .map(QuestionOption.fromJson)
        .toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    return Question(
      id: json['id'] as int,
      subjectId: (json['subjectId'] as num?)?.toInt() ?? 0,
      topicId: (json['topicId'] as num?)?.toInt() ?? 0,
      questionText: (json['questionText'] ?? '') as String,
      questionImageUrl: json['questionImageUrl'] as String?,
      difficulty: DifficultyX.fromApiValue(json['difficulty'] as String?),
      marksCorrect: json['marksCorrect'] as num? ?? 1,
      marksIncorrect: json['marksIncorrect'] as num? ?? 0,
      explanation: json['explanation'] as String?,
      status: QuestionStatusX.fromApiValue(json['status'] as String?),
      subject: json['subject'] is Map<String, dynamic>
          ? Subject.fromJson(json['subject'] as Map<String, dynamic>)
          : null,
      topic: json['topic'] is Map<String, dynamic>
          ? Topic.fromJson(json['topic'] as Map<String, dynamic>)
          : null,
      options: options,
      tags: parseEnvelopeList(json['tags'], const []).map(QuestionTag.fromJson).toList(),
      tagIds: _readIntList(json['tagIds']),
      tagNames: _readTagNames(json),
      correctOptionId: (json['correctOptionId'] as num?)?.toInt(),
      createdAt: _readDate(json['createdAt']),
      updatedAt: _readDate(json['updatedAt']),
    );
  }

  /// Exactly the create/update body. `status` is deliberately absent - it
  /// moves through PATCH /questions/:id/status, which is the only endpoint
  /// documented to change it.
  Map<String, dynamic> toPayload() => {
        'subjectId': subjectId,
        'topicId': topicId,
        'questionText': questionText,
        'questionImageUrl': questionImageUrl,
        'difficulty': difficulty.apiValue,
        'marksCorrect': marksCorrect,
        'marksIncorrect': marksIncorrect,
        'explanation': explanation,
        'tags': tagNames,
        'options': options.map((o) => o.toPayload()).toList(),
      };
}

// ── Parsing helpers ─────────────────────────────────────────────────

/// Tag names, whichever way the API sends them: an explicit `tagNames`, a
/// `tags` array of objects, or `tags` as plain strings.
List<String> _readTagNames(Map<String, dynamic> json) {
  final named = json['tagNames'];
  if (named is List) return named.map((e) => e.toString()).toList();

  final tags = json['tags'];
  if (tags is List) {
    return tags
        .map((e) => e is Map ? (e['name'] ?? '').toString() : e.toString())
        .where((t) => t.isNotEmpty)
        .toList();
  }
  return const [];
}

List<int> _readIntList(dynamic value) =>
    value is List ? value.whereType<num>().map((e) => e.toInt()).toList() : const [];

DateTime? _readDate(dynamic value) =>
    value is String ? DateTime.tryParse(value) : null;

/// Reads a list out of whichever envelope the API used: `{key: [...]}` under
/// any of [keys], or a bare top-level list. Shared by every list parser here
/// so none of them hard-codes a single response shape.
List<Map<String, dynamic>> parseEnvelopeList(dynamic decoded, List<String> keys) {
  if (decoded is List) return decoded.whereType<Map<String, dynamic>>().toList();
  if (decoded is Map) {
    for (final key in keys) {
      final value = decoded[key];
      if (value is List) return value.whereType<Map<String, dynamic>>().toList();
    }
  }
  return const [];
}

List<Subject> parseSubjects(dynamic decoded) =>
    parseEnvelopeList(decoded, const ['subjects', 'data', 'items'])
        .map(Subject.fromJson)
        .toList();

List<Topic> parseTopics(dynamic decoded) =>
    parseEnvelopeList(decoded, const ['topics', 'data', 'items'])
        .map(Topic.fromJson)
        .toList();

/// One page of questions plus whatever pagination the API reported.
class QuestionPage {
  final List<Question> questions;
  final int total;
  final int page;
  final int limit;

  const QuestionPage({
    required this.questions,
    required this.total,
    required this.page,
    required this.limit,
  });

  int get totalPages => limit <= 0 ? 1 : (total / limit).ceil().clamp(1, 1 << 30);

  /// Reads the list from `questions` / `data` / `items`, and the counters
  /// from the root or a nested `meta` / `pagination`, so the exact envelope
  /// shape doesn't matter.
  factory QuestionPage.fromJson(dynamic decoded, {required int fallbackLimit}) {
    final rows = parseEnvelopeList(decoded, const ['questions', 'data', 'items'])
        .map(Question.fromJson)
        .toList();

    final Map meta = decoded is Map
        ? (decoded['meta'] is Map
            ? decoded['meta'] as Map
            : decoded['pagination'] is Map
                ? decoded['pagination'] as Map
                : decoded)
        : const {};

    int read(String key, int fallback) {
      final value = meta[key] ?? (decoded is Map ? decoded[key] : null);
      return value is num ? value.toInt() : fallback;
    }

    return QuestionPage(
      questions: rows,
      total: read('total', rows.length),
      page: read('page', 1),
      limit: read('limit', fallbackLimit),
    );
  }
}
