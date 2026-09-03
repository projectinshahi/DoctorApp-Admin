/// Progress reported by GET /admin/students/:id.
///
/// Note the mount: /admin/students/:id sits at the ROOT, not under /api like
/// the test and course endpoints. AdminStudentService already points at
/// ApiConstant.root for this reason.
///
/// Every number here is the server's own. Totals are NOT recomputed from the
/// chapter rollups, because drafts are excluded from the API's denominators
/// and counting chapters[].lessons would silently add them back - reporting a
/// student as behind on work that was never published to them.
library;

/// One block of counters, held as a map rather than as seven bespoke classes.
///
/// The blocks genuinely differ - lessons carry `remaining`, videos carry
/// `inProgress`, qbank carries `accuracy` - and a field the backend adds later
/// arrives here without a model change.
class ProgressBlock {
  final Map<String, num> values;

  const ProgressBlock(this.values);

  static const empty = ProgressBlock({});

  factory ProgressBlock.fromJson(dynamic raw) {
    if (raw is! Map) return empty;
    return ProgressBlock({
      for (final entry in raw.entries)
        if (entry.value is num) '${entry.key}': entry.value as num,
    });
  }

  bool get isEmpty => values.isEmpty;

  /// Missing is null, not zero: "no videos on this course" and "0 of 3 videos
  /// watched" are different facts and must not render the same.
  int? operator [](String key) => values[key]?.toInt();

  num? raw(String key) => values[key];
}

/// One chapter's rollup, with its lessons when the API includes them.
class ChapterProgress {
  final int id;
  final String title;
  final int total;
  final int completed;
  final int percent;
  final List<LessonProgress> lessons;

  const ChapterProgress({
    required this.id,
    required this.title,
    required this.total,
    required this.completed,
    required this.percent,
    this.lessons = const [],
  });

  List<LessonProgress> get completedLessons =>
      lessons.where((l) => l.completed).toList();

  List<LessonProgress> get pendingLessons =>
      lessons.where((l) => !l.completed).toList();

  factory ChapterProgress.fromJson(Map<String, dynamic> json) {
    final rawLessons = json['lessons'];
    return ChapterProgress(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: (json['title'] ?? json['name'] ?? 'Untitled chapter') as String,
      total: (json['total'] as num?)?.toInt() ?? 0,
      completed: (json['completed'] as num?)?.toInt() ?? 0,
      percent: (json['percent'] as num?)?.toInt() ?? 0,
      lessons: rawLessons is List
          ? rawLessons
              .whereType<Map<String, dynamic>>()
              .map(LessonProgress.fromJson)
              .toList()
          : const [],
    );
  }
}

class LessonProgress {
  final int id;
  final String title;
  final bool completed;

  /// False once the student's subscription lapsed. Completed-and-locked is a
  /// real state, not a contradiction: they finished the lesson, then lost
  /// access to it.
  final bool visibleToStudent;

  const LessonProgress({
    required this.id,
    required this.title,
    required this.completed,
    required this.visibleToStudent,
  });

  bool get isCompletedButLocked => completed && !visibleToStudent;

  factory LessonProgress.fromJson(Map<String, dynamic> json) => LessonProgress(
        id: (json['id'] as num?)?.toInt() ?? 0,
        title: (json['title'] ?? json['name'] ?? 'Untitled lesson') as String,
        completed: json['completed'] as bool? ?? false,
        visibleToStudent: json['visibleToStudent'] as bool? ?? true,
      );
}

/// Where a student placed on a test's leaderboard.
///
/// Null while the attempt is still running, and identical across a student's
/// retakes of the same paper - a leaderboard ranks students, not attempts.
class AttemptLeaderboard {
  final int? rank;
  final int? totalParticipants;
  final num? bestScore;

  const AttemptLeaderboard({
    this.rank,
    this.totalParticipants,
    this.bestScore,
  });

  bool get isEmpty => rank == null && bestScore == null;

  /// "3rd of 24". The ordinal reads faster than "rank 3" in a list.
  String? get placeLabel {
    final r = rank;
    if (r == null) return null;
    final total = totalParticipants;
    return total == null ? _ordinal(r) : '${_ordinal(r)} of $total';
  }

  static String _ordinal(int n) {
    // 11th, 12th, 13th are the exceptions the naive rule gets wrong.
    if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
    return switch (n % 10) {
      1 => '${n}st',
      2 => '${n}nd',
      3 => '${n}rd',
      _ => '${n}th',
    };
  }

  static AttemptLeaderboard? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final board = AttemptLeaderboard(
      rank: (raw['rank'] as num?)?.toInt(),
      totalParticipants: (raw['totalParticipants'] as num?)?.toInt(),
      bestScore: raw['bestScore'] as num?,
    );
    return board.isEmpty ? null : board;
  }
}

/// One row of quiz or test history.
class AttemptSummary {
  final int id;
  final String title;
  final num? score;
  final num? total;

  /// The server's percentage when it sends one, otherwise derived from
  /// [score] and [total] - see [percent].
  final int? reportedPercent;

  final String? status;
  final DateTime? at;

  /// Only on test attempts, and only once the attempt has finished.
  final AttemptLeaderboard? leaderboard;

  const AttemptSummary({
    required this.id,
    required this.title,
    this.score,
    this.total,
    this.reportedPercent,
    this.status,
    this.at,
    this.leaderboard,
  });

  /// Percentage for this attempt.
  ///
  /// Derived from score/total when the API omits `percent`, which it does on
  /// these arrays - a row that has a score but no percent should still show
  /// one rather than silently rendering as a bare title.
  int? get percent {
    if (reportedPercent != null) return reportedPercent;
    final s = score, t = total;
    if (s == null || t == null || t == 0) return null;
    return ((s / t) * 100).round();
  }

  /// "7 / 10", or just "7" when the API did not send a denominator.
  String? get scoreLabel {
    if (score == null) return null;
    final s = _trim(score!);
    return total == null ? s : '$s / ${_trim(total!)}';
  }

  static String _trim(num value) =>
      value % 1 == 0 ? '${value.toInt()}' : '$value';

  /// Whether the student is still in the middle of this attempt.
  ///
  /// Derived from `status` because the API does not send a boolean. An unknown
  /// status counts as finished: a submitted attempt wrongly listed as "in
  /// progress" is worse than the reverse, since it suggests work the student
  /// still owes.
  bool get isInProgress {
    final s = status?.toLowerCase().replaceAll('_', ' ').trim();
    if (s == null || s.isEmpty) return false;
    return s.contains('progress') ||
        s == 'started' ||
        s == 'pending' ||
        s == 'ongoing' ||
        s == 'incomplete';
  }

  /// Reads the first key present. These arrays are not documented field by
  /// field, so each value is looked for under every name this backend uses
  /// for it elsewhere rather than one guessed spelling.
  static num? _num(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is num) return value;
      if (value is String) {
        final parsed = num.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  factory AttemptSummary.fromJson(Map<String, dynamic> json) {
    // A nested quiz/test object carries the title on some responses.
    final nested = json['quiz'] ?? json['test'];
    final nestedTitle = nested is Map
        ? (nested['title'] ?? nested['name'])?.toString()
        : null;

    return AttemptSummary(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: (json['quizTitle'] ??
              json['testTitle'] ??
              json['title'] ??
              json['name'] ??
              nestedTitle ??
              'Attempt')
          .toString(),
      score: _num(json, const [
        'score',
        'marksObtained',
        'obtainedMarks',
        'totalMarks',
        'correctAnswers',
        'correctCount',
        'correct',
      ]),
      total: _num(json, const [
        'total',
        'totalQuestions',
        'maxScore',
        'maxMarks',
        'questionCount',
        'totalCount',
      ]),
      reportedPercent:
          _num(json, const ['percent', 'percentage', 'scorePercent'])?.round(),
      status: (json['status'] ?? json['state'])?.toString(),
      at: DateTime.tryParse(
          '${json['attemptedAt'] ?? json['submittedAt'] ?? json['completedAt'] ?? json['createdAt'] ?? ''}'),
      leaderboard: AttemptLeaderboard.fromJson(json['leaderboard']),
    );
  }
}

class StudentProgress {
  final ProgressBlock lessons;
  final ProgressBlock videos;
  final ProgressBlock notes;
  final ProgressBlock quizzes;
  final ProgressBlock qbank;
  final ProgressBlock tests;
  final ProgressBlock bookmarks;
  final DateTime? lastActivityAt;

  const StudentProgress({
    this.lessons = ProgressBlock.empty,
    this.videos = ProgressBlock.empty,
    this.notes = ProgressBlock.empty,
    this.quizzes = ProgressBlock.empty,
    this.qbank = ProgressBlock.empty,
    this.tests = ProgressBlock.empty,
    this.bookmarks = ProgressBlock.empty,
    this.lastActivityAt,
  });

  bool get hasAnyActivity => lastActivityAt != null;

  /// Every metric that has a completion percentage, in display order.
  List<({String label, ProgressBlock block})> get completionMetrics => [
        (label: 'Lessons', block: lessons),
        (label: 'Videos', block: videos),
        (label: 'Notes', block: notes),
        (label: 'Quizzes', block: quizzes),
      ];

  factory StudentProgress.fromJson(Map<String, dynamic> json) => StudentProgress(
        lessons: ProgressBlock.fromJson(json['lessons']),
        videos: ProgressBlock.fromJson(json['videos']),
        notes: ProgressBlock.fromJson(json['notes']),
        quizzes: ProgressBlock.fromJson(json['quizzes']),
        qbank: ProgressBlock.fromJson(json['qbank']),
        tests: ProgressBlock.fromJson(json['tests']),
        bookmarks: ProgressBlock.fromJson(json['bookmarks']),
        lastActivityAt: DateTime.tryParse('${json['lastActivityAt'] ?? ''}'),
      );
}

/// The whole payload of GET /admin/students/:id.
class StudentDetail {
  final StudentProgress progress;
  final List<ChapterProgress> chapters;

  /// Capped at 20 by the API, with no "load more". Never presented as the
  /// student's complete history - see [historyIsCapped].
  final List<AttemptSummary> recentQuizAttempts;
  final List<AttemptSummary> recentTestAttempts;

  /// The session block. [lastSeenAt] is what the single-device rule compares
  /// against, so it is the field that answers "why can't I log in?" - without
  /// it an admin can only guess whether a student is genuinely stuck.
  final bool isLoggedIn;
  final String? currentDeviceId;
  final DateTime? lastLoginAt;
  final DateTime? lastSeenAt;

  /// The account status as the detail endpoint reports it. Null when this
  /// payload does not carry one, in which case the row the screen was opened
  /// from stays authoritative.
  final String? status;

  const StudentDetail({
    required this.progress,
    this.chapters = const [],
    this.recentQuizAttempts = const [],
    this.recentTestAttempts = const [],
    this.isLoggedIn = false,
    this.currentDeviceId,
    this.lastLoginAt,
    this.lastSeenAt,
    this.status,
  });

  /// The API caps each history array at 20. A full array means there is very
  /// likely more behind it, which needs a paginated endpoint rather than an
  /// assumption.
  static const historyCap = 20;

  bool get historyIsCapped =>
      recentQuizAttempts.length >= historyCap ||
      recentTestAttempts.length >= historyCap;

  factory StudentDetail.fromJson(Map<String, dynamic> json) {
    // The student object may be nested under `data`/`student` or sit at the
    // top level; progress hangs off whichever holds it.
    final root = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json['student'] is Map<String, dynamic>
            ? json['student'] as Map<String, dynamic>
            : json;

    Map<String, dynamic>? mapOf(String key) {
      final value = root[key] ?? json[key];
      return value is Map<String, dynamic> ? value : null;
    }

    // The arrays sometimes hang off `progress` rather than beside it.
    final progress = mapOf('progress');

    /// Takes the first key that holds a list. These arrays are not documented
    /// name by name, so each is looked for under every spelling this backend
    /// uses rather than one guessed key - a miss here renders as an empty
    /// section, which reads as "the student did nothing".
    List<T> listOf<T>(List<String> keys, T Function(Map<String, dynamic>) parse) {
      for (final key in keys) {
        final value = root[key] ?? json[key] ?? progress?[key];
        if (value is List) {
          return value.whereType<Map<String, dynamic>>().map(parse).toList();
        }
      }
      return <T>[];
    }

    // The session fields sit beside the student, not inside progress.
    DateTime? stamp(String key) =>
        DateTime.tryParse('${root[key] ?? json[key] ?? ''}');

    return StudentDetail(
      isLoggedIn: (root['isLoggedIn'] ?? json['isLoggedIn']) == true,
      currentDeviceId:
          (root['currentDeviceId'] ?? json['currentDeviceId']) as String?,
      lastLoginAt: stamp('lastLoginAt'),
      lastSeenAt: stamp('lastSeenAt'),
      status: (root['status'] ?? json['status']) as String?,
      progress: StudentProgress.fromJson(progress ?? const {}),
      chapters: listOf(
        const ['chapters', 'chapterProgress', 'courseProgress', 'syllabus'],
        ChapterProgress.fromJson,
      ),
      recentQuizAttempts: listOf(
        const [
          'recentQuizAttempts',
          'quizAttempts',
          'recentQuizzes',
          'quiz_attempts',
        ],
        AttemptSummary.fromJson,
      ),
      recentTestAttempts: listOf(
        const [
          'recentTestAttempts',
          'testAttempts',
          'recentTests',
          'test_attempts',
        ],
        AttemptSummary.fromJson,
      ),
    );
  }
}
