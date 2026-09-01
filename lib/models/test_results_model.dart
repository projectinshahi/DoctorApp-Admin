/// Results models for the Test module.
///
/// Attempts and leaderboard are deliberately separate types, not one list
/// filtered two ways: the leaderboard holds one row per student (their best
/// attempt) and the attempts list holds every attempt including retakes.
/// Merging them would hide retakes on a screen that exists to show them.
library;

/// One attempt, as the attempts list reports it.
class TestAttempt {
  final int id;
  final int? studentId;
  final String studentName;
  final String? studentEmail;

  final num? score;
  final num? maxScore;
  final int? correctCount;
  final int? wrongCount;
  final int? skippedCount;

  /// How long they actually took, which is not the duration allowed.
  final int? timeTakenSeconds;

  /// 'in_progress' | 'submitted' | 'expired' | ...
  final String? status;

  final DateTime? startedAt;
  final DateTime? submittedAt;

  /// Seconds left, when the server reports it on a live attempt.
  final int? remainingSeconds;

  const TestAttempt({
    required this.id,
    this.studentId,
    required this.studentName,
    this.studentEmail,
    this.score,
    this.maxScore,
    this.correctCount,
    this.wrongCount,
    this.skippedCount,
    this.timeTakenSeconds,
    this.status,
    this.startedAt,
    this.submittedAt,
    this.remainingSeconds,
  });

  bool get isSubmitted => _status == 'submitted' || submittedAt != null;

  /// An out-of-time attempt. The server only closes one when the student next
  /// touches it, so a paper can sit "in progress" long after its clock ran
  /// out - counting those as live reports a room full of candidates who left
  /// hours ago.
  bool get isExpired =>
      _status == 'expired' || (remainingSeconds != null && remainingSeconds! <= 0);

  /// Genuinely live: started, not submitted, not out of time.
  bool get isLive => !isSubmitted && !isExpired;

  String get _status => (status ?? '').toLowerCase().replaceAll('-', '_');

  String? get scoreLabel {
    if (score == null) return null;
    final s = _trim(score!);
    return maxScore == null ? s : '$s / ${_trim(maxScore!)}';
  }

  int? get percent {
    final s = score, m = maxScore;
    if (s == null || m == null || m == 0) return null;
    return ((s / m) * 100).round();
  }

  static String _trim(num value) =>
      value % 1 == 0 ? '${value.toInt()}' : '$value';

  static String _nameFrom(Map<String, dynamic> json) {
    final student = json['student'];
    if (student is Map) {
      final name = (student['name'] ?? '').toString().trim();
      if (name.isNotEmpty) return name;
      final email = (student['email'] ?? '').toString().trim();
      if (email.isNotEmpty) return email;
    }
    final flat = (json['studentName'] ?? json['name'] ?? '').toString().trim();
    if (flat.isNotEmpty) return flat;
    final email = (json['studentEmail'] ?? json['email'] ?? '').toString().trim();
    return email.isNotEmpty ? email : 'Unknown student';
  }

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

  factory TestAttempt.fromJson(Map<String, dynamic> json) {
    final student = json['student'];
    return TestAttempt(
      id: (json['id'] as num?)?.toInt() ?? 0,
      studentId: (json['studentId'] as num?)?.toInt() ??
          (student is Map ? (student['id'] as num?)?.toInt() : null),
      studentName: _nameFrom(json),
      studentEmail: (json['studentEmail'] ??
              (student is Map ? student['email'] : null)) as String?,
      score: _num(json, const ['score', 'totalScore', 'marksObtained']),
      maxScore: _num(json, const ['maxScore', 'totalMarks', 'maxMarks', 'total']),
      correctCount: _num(json, const ['correctCount', 'correct'])?.toInt(),
      wrongCount: _num(json, const ['wrongCount', 'wrong', 'incorrect'])?.toInt(),
      skippedCount:
          _num(json, const ['skippedCount', 'unansweredCount', 'skipped'])
              ?.toInt(),
      timeTakenSeconds:
          _num(json, const ['timeTakenSeconds', 'timeTaken'])?.toInt(),
      status: (json['status'] ?? json['state'])?.toString(),
      startedAt: DateTime.tryParse('${json['startedAt'] ?? json['createdAt'] ?? ''}'),
      submittedAt: DateTime.tryParse('${json['submittedAt'] ?? ''}'),
      remainingSeconds:
          _num(json, const ['remainingSeconds', 'secondsRemaining'])?.toInt(),
    );
  }
}

/// One row of the leaderboard: a student's best attempt, and nothing else.
class LeaderboardRow {
  /// The server's rank, never a row index.
  ///
  /// Ties share a rank and the next one skips - 1, 2, 2, 4 - so numbering the
  /// rows would quietly disagree with what the students themselves see.
  final int rank;

  final int? studentId;
  final String studentName;
  final String? email;
  final num? score;
  final num? maxScore;
  final int? attemptCount;
  final int? timeTakenSeconds;
  final DateTime? achievedAt;

  const LeaderboardRow({
    required this.rank,
    this.studentId,
    required this.studentName,
    this.email,
    this.score,
    this.maxScore,
    this.attemptCount,
    this.timeTakenSeconds,
    this.achievedAt,
  });

  String? get scoreLabel {
    if (score == null) return null;
    final s = TestAttempt._trim(score!);
    return maxScore == null ? s : '$s / ${TestAttempt._trim(maxScore!)}';
  }

  factory LeaderboardRow.fromJson(Map<String, dynamic> json, int fallbackRank) =>
      LeaderboardRow(
        rank: (json['rank'] as num?)?.toInt() ?? fallbackRank,
        studentId: (json['studentId'] as num?)?.toInt() ??
            (json['student'] is Map
                ? (json['student']['id'] as num?)?.toInt()
                : null),
        studentName: TestAttempt._nameFrom(json),
        score: TestAttempt._num(json, const ['score', 'bestScore', 'totalScore']),
        maxScore:
            TestAttempt._num(json, const ['maxScore', 'totalMarks', 'maxMarks']),
        email: (json['email'] ??
            (json['student'] is Map ? json['student']['email'] : null)) as String?,
        attemptCount:
            TestAttempt._num(json, const ['attemptCount', 'attempts'])?.toInt(),
        timeTakenSeconds:
            TestAttempt._num(json, const ['timeTakenSeconds', 'fastestSeconds'])
                ?.toInt(),
        achievedAt: DateTime.tryParse(
            '${json['achievedAt'] ?? json['submittedAt'] ?? ''}'),
      );
}

/// The spread across the whole leaderboard.
///
/// `median` sits beside `average` because one abandoned zero drags a mean to a
/// score no student actually sat.
class LeaderboardStats {
  final num? highest;
  final num? lowest;
  final num? average;
  final num? median;
  final int? fastestSeconds;

  const LeaderboardStats({
    this.highest,
    this.lowest,
    this.average,
    this.median,
    this.fastestSeconds,
  });

  bool get isEmpty =>
      highest == null && lowest == null && average == null && median == null;

  factory LeaderboardStats.fromJson(Map<String, dynamic> json) =>
      LeaderboardStats(
        highest: json['highest'] as num?,
        lowest: json['lowest'] as num?,
        average: json['average'] as num?,
        median: json['median'] as num?,
        fastestSeconds: (json['fastestSeconds'] as num?)?.toInt(),
      );
}

/// One live attempt, in the shape /test-attempts/in-progress returns.
class InProgressAttempt {
  final int attemptId;

  final int? studentId;
  final String studentName;
  final String? studentEmail;
  final String? avatarUrl;

  final int? testId;
  final String testName;
  final int? totalQuestions;
  final int? durationMinutes;

  final DateTime? startedAt;
  final DateTime? deadlineAt;

  /// Seconds left as of the response. Ticked down locally between refetches.
  final int secondsRemaining;

  /// THE field that decides the row. An attempt whose time is up is only
  /// closed when the student next touches it, so this list holds two
  /// different things: someone writing, and someone who walked away.
  final bool expired;

  final int answeredCount;
  final int remainingCount;

  const InProgressAttempt({
    required this.attemptId,
    this.studentId,
    required this.studentName,
    this.studentEmail,
    this.avatarUrl,
    this.testId,
    required this.testName,
    this.totalQuestions,
    this.durationMinutes,
    this.startedAt,
    this.deadlineAt,
    this.secondsRemaining = 0,
    this.expired = false,
    this.answeredCount = 0,
    this.remainingCount = 0,
  });

  /// Fraction answered, for the progress bar. Null when the total is unknown -
  /// a bar with an invented denominator is worse than no bar.
  double? get answeredFraction {
    final total = totalQuestions;
    if (total == null || total == 0) return null;
    return (answeredCount / total).clamp(0.0, 1.0);
  }

  /// Seconds left, recomputed from the deadline so the clock stays honest
  /// across a long gap between refetches.
  int remainingAt(DateTime now) {
    final deadline = deadlineAt;
    if (deadline == null) return secondsRemaining;
    return deadline.difference(now).inSeconds.clamp(0, 1 << 30);
  }

  /// "25:24". Hours appear only when there are any.
  static String clock(int seconds) {
    if (seconds <= 0) return '00:00';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  factory InProgressAttempt.fromJson(Map<String, dynamic> json) {
    final student = json['student'];
    final test = json['test'];

    return InProgressAttempt(
      attemptId: (json['attemptId'] ?? json['id']) is num
          ? ((json['attemptId'] ?? json['id']) as num).toInt()
          : 0,
      studentId: student is Map ? (student['id'] as num?)?.toInt() : null,
      studentName: student is Map
          ? ((student['name'] ?? student['email'] ?? 'Unknown student')
              .toString())
          : 'Unknown student',
      studentEmail: student is Map ? student['email'] as String? : null,
      avatarUrl: student is Map ? student['avatarUrl'] as String? : null,
      testId: test is Map ? (test['id'] as num?)?.toInt() : null,
      testName: test is Map
          ? ((test['name'] ?? test['title'] ?? 'Test').toString())
          : 'Test',
      totalQuestions:
          test is Map ? (test['totalQuestions'] as num?)?.toInt() : null,
      durationMinutes:
          test is Map ? (test['durationMinutes'] as num?)?.toInt() : null,
      startedAt: DateTime.tryParse('${json['startedAt'] ?? ''}'),
      deadlineAt: DateTime.tryParse('${json['deadlineAt'] ?? ''}'),
      secondsRemaining: (json['secondsRemaining'] as num?)?.toInt() ?? 0,
      expired: json['expired'] as bool? ?? false,
      answeredCount: (json['answeredCount'] as num?)?.toInt() ?? 0,
      remainingCount: (json['remainingCount'] as num?)?.toInt() ?? 0,
    );
  }
}
