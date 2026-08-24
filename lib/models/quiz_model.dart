/// A named quiz: a saved *filter* over the Question Bank (subject + topic +
/// optional exam tag), not a copy of questions. Questions are authored
/// elsewhere and imported; this app never writes them.
///
/// The same shape comes back from three places, so one tolerant parser covers
/// all of them:
///   GET /api/quizzes            -> list rows, with nested subject/topic/lesson
///   GET /api/lessons/:id        -> under `quiz`, with the live pool counters
///   GET /api/quizzes/:id/preview -> under `quiz`
library;

class Quiz {
  final int id;
  final String title;
  final int subjectId;
  final int topicId;
  final String? examTag;

  /// How many questions this quiz serves per attempt.
  /// Null means "serve every question that matches".
  final int? questionCount;

  final String status; // active | inactive

  /// How many questions the filter matches right now. Only the lesson and
  /// preview responses report these; 0 elsewhere.
  final int availableQuestions;
  final int servedQuestions;

  /// Server-reported when present, computed otherwise: the quiz asks for more
  /// questions than the bank can supply.
  final bool isUnderfilled;

  /// Display names, present on list rows only.
  final String? subjectName;
  final String? topicName;

  /// Set when this quiz already serves another lesson. A quiz can only be
  /// linked once - the backend 400s on a second link, so the picker has to
  /// disable these rows rather than let the save fail.
  final int? linkedLessonId;
  final String? linkedLessonTitle;

  const Quiz({
    required this.id,
    required this.title,
    required this.subjectId,
    required this.topicId,
    this.examTag,
    this.questionCount,
    this.status = 'active',
    this.availableQuestions = 0,
    this.servedQuestions = 0,
    this.isUnderfilled = false,
    this.subjectName,
    this.topicName,
    this.linkedLessonId,
    this.linkedLessonTitle,
  });

  bool get isActive => status == 'active';

  /// Already serving another lesson.
  bool get isTaken => linkedLessonId != null;

  /// Nothing matches the filter - students would get an empty quiz.
  /// Only meaningful once the counters have been reported.
  bool get isEmpty => availableQuestions == 0;

  factory Quiz.fromJson(Map<String, dynamic> json) {
    final subject = json['subject'] as Map<String, dynamic>?;
    final topic = json['topic'] as Map<String, dynamic>?;
    final lesson = json['lesson'] as Map<String, dynamic>?;

    final count = (json['questionCount'] as num?)?.toInt();
    final available = (json['availableQuestions'] as num?)?.toInt() ?? 0;

    return Quiz(
      id: json['id'] as int,
      title: (json['title'] ?? '') as String,
      subjectId: (json['subjectId'] as num?)?.toInt() ?? 0,
      topicId: (json['topicId'] as num?)?.toInt() ?? 0,
      examTag: json['examTag'] as String?,
      questionCount: count,
      status: (json['status'] ?? 'active') as String,
      availableQuestions: available,
      servedQuestions: (json['servedQuestions'] as num?)?.toInt() ?? 0,
      // Trust the server when it says; fall back to the counters. Never
      // "underfilled" when the pool is simply unreported (both would be 0).
      isUnderfilled: json['isUnderfilled'] as bool? ??
          (count != null && available > 0 && available < count),
      subjectName: subject?['name'] as String?,
      topicName: topic?['name'] as String?,
      linkedLessonId: (lesson?['id'] as num?)?.toInt(),
      linkedLessonTitle: lesson?['title'] as String?,
    );
  }

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

/// One option of a quiz question.
class QuizOption {
  final int id;
  final String optionText;
  final String? optionImageUrl;
  final int displayOrder;

  /// Populated by the admin preview only - the student-facing serve strips it.
  /// Treat null as "unknown", never as "wrong".
  final bool? isCorrect;

  const QuizOption({
    required this.id,
    required this.optionText,
    required this.displayOrder,
    this.optionImageUrl,
    this.isCorrect,
  });

  factory QuizOption.fromJson(Map<String, dynamic> json) => QuizOption(
        id: json['id'] as int,
        optionText: (json['optionText'] ?? '') as String,
        optionImageUrl: json['optionImageUrl'] as String?,
        displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
        isCorrect: json['isCorrect'] as bool?,
      );
}

class QuizQuestion {
  final int id;
  final String questionText;
  final String? questionImageUrl;
  final String difficulty; // easy | medium | hard
  final double marksCorrect;
  final double marksIncorrect;
  final String? explanation;
  final int? correctOptionId;
  final List<String> tagNames;
  final List<QuizOption> options;

  const QuizQuestion({
    required this.id,
    required this.questionText,
    required this.difficulty,
    required this.marksCorrect,
    required this.marksIncorrect,
    required this.options,
    this.questionImageUrl,
    this.explanation,
    this.correctOptionId,
    this.tagNames = const [],
  });

  /// "+2 / -0.5", or just "+2" when there is no negative marking.
  String get marksLabel {
    final correct = '+${_trim(marksCorrect)}';
    if (marksIncorrect == 0) return correct;
    return '$correct / ${_trim(marksIncorrect)}';
  }

  static String _trim(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toString();

  factory QuizQuestion.fromJson(Map<String, dynamic> json) => QuizQuestion(
        id: json['id'] as int,
        questionText: (json['questionText'] ?? '') as String,
        questionImageUrl: json['questionImageUrl'] as String?,
        difficulty: (json['difficulty'] ?? 'easy') as String,
        marksCorrect: (json['marksCorrect'] as num?)?.toDouble() ?? 0,
        marksIncorrect: (json['marksIncorrect'] as num?)?.toDouble() ?? 0,
        explanation: json['explanation'] as String?,
        correctOptionId: (json['correctOptionId'] as num?)?.toInt(),
        tagNames: ((json['tagNames'] ?? const []) as List).map((t) => t.toString()).toList(),
        options: ((json['options'] ?? const []) as List)
            .whereType<Map<String, dynamic>>()
            .map(QuizOption.fromJson)
            .toList()
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder)),
      );
}

/// Response of GET /api/quizzes/:id/preview - the same questions a student
/// would be served, but WITH the answer key. Admin-only.
class QuizPreview {
  final Quiz quiz;
  final int availableQuestions;
  final bool isUnderfilled;
  final int totalQuestions;
  final double totalMarks;
  final List<QuizQuestion> questions;

  const QuizPreview({
    required this.quiz,
    required this.availableQuestions,
    required this.isUnderfilled,
    required this.totalQuestions,
    required this.totalMarks,
    required this.questions,
  });

  factory QuizPreview.fromJson(Map<String, dynamic> json) => QuizPreview(
        quiz: Quiz.fromJson((json['quiz'] ?? const <String, dynamic>{}) as Map<String, dynamic>),
        availableQuestions: (json['availableQuestions'] as num?)?.toInt() ?? 0,
        isUnderfilled: json['isUnderfilled'] as bool? ?? false,
        totalQuestions: (json['totalQuestions'] as num?)?.toInt() ?? 0,
        totalMarks: (json['totalMarks'] as num?)?.toDouble() ?? 0,
        questions: ((json['questions'] ?? const []) as List)
            .whereType<Map<String, dynamic>>()
            .map(QuizQuestion.fromJson)
            .toList(),
      );
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
  return quizzes
      .map((q) => q.examTag)
      .whereType<String>()
      .where((t) => t.trim().isNotEmpty)
      .toSet()
      .toList()
    ..sort();
}
