/// A named quiz built from the Question Bank, linked to a lesson by id.
///
/// A quiz belongs to one Subject + Topic (the same taxonomy the Question Bank
/// uses) and optionally carries an exam tag. `questionCount` is what the quiz
/// asks for; `activeQuestionPool` is how many active questions actually match
/// it - the two differ when the pool is too thin, which is exactly what the
/// admin needs to see before attaching it to a lesson.
library;

class Quiz {
  final int id;
  final String title;
  final int subjectId;
  final int topicId;
  final String? examTag;

  /// How many questions this quiz serves per attempt.
  final int questionCount;

  /// How many active questions are available to draw from. Null when the API
  /// didn't report it - "unknown", not "zero".
  final int? activeQuestionPool;

  const Quiz({
    required this.id,
    required this.title,
    required this.subjectId,
    required this.topicId,
    this.examTag,
    this.questionCount = 0,
    this.activeQuestionPool,
  });

  /// True when the quiz wants more questions than the bank can currently
  /// supply. Worth surfacing in the picker rather than at attempt time.
  bool get isUnderfilled =>
      activeQuestionPool != null && activeQuestionPool! < questionCount;

  factory Quiz.fromJson(Map<String, dynamic> json) => Quiz(
        id: json['id'] as int,
        title: (json['title'] ?? '') as String,
        subjectId: (json['subjectId'] as num?)?.toInt() ?? 0,
        topicId: (json['topicId'] as num?)?.toInt() ?? 0,
        examTag: json['examTag'] as String?,
        questionCount: (json['questionCount'] as num?)?.toInt() ?? 0,
        activeQuestionPool: (json['activeQuestionPool'] as num?)?.toInt(),
      );

  /// The create body. Subject/topic/tag come from whatever the admin already
  /// picked in the lesson sheet's filters.
  Map<String, dynamic> toPayload() => {
        'title': title,
        'subjectId': subjectId,
        'topicId': topicId,
        'examTag': examTag,
        'questionCount': questionCount,
      };
}

/// Reads a quiz list out of whichever envelope the API uses.
List<Quiz> parseQuizzes(dynamic decoded) {
  if (decoded is List) {
    return decoded.whereType<Map<String, dynamic>>().map(Quiz.fromJson).toList();
  }
  if (decoded is Map) {
    for (final key in const ['quizzes', 'data', 'items']) {
      final value = decoded[key];
      if (value is List) {
        return value.whereType<Map<String, dynamic>>().map(Quiz.fromJson).toList();
      }
    }
  }
  return const [];
}

/// Distinct exam tags across a set of quizzes, sorted.
///
/// There's no endpoint that lists exam tags, so the picker derives them from
/// the quizzes already loaded for the chosen subject + topic.
List<String> examTagsOf(List<Quiz> quizzes) {
  final tags = quizzes
      .map((q) => q.examTag)
      .whereType<String>()
      .where((t) => t.trim().isNotEmpty)
      .toSet()
      .toList()
    ..sort();
  return tags;
}
