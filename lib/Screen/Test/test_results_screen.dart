import 'package:flutter/material.dart';

import 'questions_tab.dart';

import '../../core/theam/theam_dart.dart';
import '../../models/admin_test_model.dart';
import '../../models/test_results_model.dart';
import '../../services/admin_test_service.dart';
import '../../widget/shimmer_loading.dart';
import '../../widget/student_progress_widgets.dart' show formatStamp;

/// One test, in full: its questions and its results.
///
/// Attempts and leaderboard are separate tabs on purpose. The leaderboard
/// holds one row per student - their best attempt - while the attempts list
/// holds every attempt including retakes. Merging them into one filtered list
/// would hide retakes on the screen that exists to show them.
class TestResultsScreen extends StatefulWidget {
  final AdminTest test;

  const TestResultsScreen({super.key, required this.test});

  @override
  State<TestResultsScreen> createState() => _TestResultsScreenState();
}

class _TestResultsScreenState extends State<TestResultsScreen>
    with SingleTickerProviderStateMixin {
  final _service = AdminTestService();
  late final TabController _tabs = TabController(length: 3, vsync: this);

  List<TestAttempt>? _attempts;
  List<LeaderboardRow>? _leaderboard;
  LeaderboardStats _stats = const LeaderboardStats();

  bool _isLoading = false;

  // One message per tab. A single shared error would hide which of the three
  // calls actually failed - and the server's own wording ("the server does
  // not have this endpoint (404)") is the difference between "wait for the
  // deploy" and "something is broken".
  String? _attemptsError;
  String? _boardError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _attemptsError = null;
      _boardError = null;
    });

    final id = widget.test.id;
    final results = await Future.wait([
      _service.getAttempts(id),
      _service.getLeaderboard(id),
    ]);

    if (!mounted) return;

    final attempts = results[0] as TestAttemptListResult;
    final board = results[1] as LeaderboardResult;

    setState(() {
      _isLoading = false;

      // Each tab keeps its own outcome, so one endpoint being absent leaves
      // the other two working instead of blanking the screen.
      _attempts = attempts.isSuccess ? attempts.attempts : null;
      _attemptsError = attempts.isSuccess ? null : attempts.errorMessage;

      _leaderboard = board.isSuccess ? board.rows : null;
      _stats = board.isSuccess ? board.stats : const LeaderboardStats();
      _boardError = board.isSuccess ? null : board.errorMessage;

    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: LmsColors.textDark,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(widget.test.title,
                style: const TextStyle(
                    fontSize: 15.5, fontWeight: FontWeight.w800),
                overflow: TextOverflow.ellipsis),
            Text('${widget.test.attemptCount} attempt'
                '${widget.test.attemptCount == 1 ? '' : 's'}',
                style: const TextStyle(
                    fontSize: 11.5, color: LmsColors.textGrey)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _load,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Reload',
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: LmsColors.primary,
          unselectedLabelColor: LmsColors.textGrey,
          indicatorColor: LmsColors.primary,
          labelStyle:
              const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
          tabs: const [
            Tab(text: 'QUESTIONS'),
            Tab(text: 'ATTEMPTS'),
            Tab(text: 'LEADERBOARD'),
          ],
        ),
      ),
      body: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: ShimmerListSkeleton(rowCount: 5, padding: EdgeInsets.zero),
            )
          : TabBarView(
              controller: _tabs,
              children: [
                QuestionsTab(test: widget.test),
                _attemptsTab(),
                _leaderboardTab(),
              ],
            ),
    );
  }

  // ── Leaderboard ──────────────────────────────────────────────────

  Widget _leaderboardTab() {
    final rows = _leaderboard;
    if (rows == null) return _failure(_boardError, 'leaderboard');
    if (rows.isEmpty) {
      return _pad(const _Notice(
        icon: Icons.leaderboard_outlined,
        text: 'Nobody has completed this test yet.',
      ));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        const _Note(
          'One row per student — their best attempt, ranked the same way the '
          'students see it. Retakes are on the Attempts tab.',
        ),
        const SizedBox(height: 14),
        if (!_stats.isEmpty) ...[
          _StatsStrip(stats: _stats),
          const SizedBox(height: 16),
        ],
        for (final row in rows) _LeaderboardTile(row: row),
      ],
    );
  }

  // ── Attempts ─────────────────────────────────────────────────────

  Widget _attemptsTab() {
    final attempts = _attempts;
    if (attempts == null) return _failure(_attemptsError, 'attempts');
    if (attempts.isEmpty) {
      return _pad(const _Notice(
        icon: Icons.history_rounded,
        text: 'No attempts on this test yet.',
      ));
    }

    final live = attempts.where((a) => a.isLive).toList();
    final expired = attempts.where((a) => a.isExpired && !a.isSubmitted).toList();
    final done = attempts.where((a) => a.isSubmitted).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        const _Note(
          'Every attempt, retakes included. The leaderboard shows only each '
          'student\'s best.',
        ),
        const SizedBox(height: 14),
        if (live.isNotEmpty) ...[
          _Label('In progress · ${live.length}'),
          const SizedBox(height: 8),
          for (final a in live) _AttemptTile(attempt: a),
          const SizedBox(height: 18),
        ],
        if (expired.isNotEmpty) ...[
          _Label('Out of time · ${expired.length}'),
          const SizedBox(height: 4),
          const _Note(
            'Started, ran out of time, and not yet closed — the server closes '
            'one only when the student next opens it.',
          ),
          const SizedBox(height: 8),
          for (final a in expired) _AttemptTile(attempt: a),
          const SizedBox(height: 18),
        ],
        if (done.isNotEmpty) ...[
          _Label('Submitted · ${done.length}'),
          const SizedBox(height: 8),
          for (final a in done) _AttemptTile(attempt: a),
        ],
      ],
    );
  }

  Widget _pad(Widget child) =>
      Padding(padding: const EdgeInsets.all(20), child: child);

  /// The failed tab, showing the server's own words.
  ///
  /// A 404 is called out separately: it means the endpoint is not deployed
  /// yet, which is a different action for the admin than a request that
  /// failed. Replacing it with "could not be loaded" hides the one detail
  /// that says what to do next.
  /// [what] is a bare noun - "leaderboard", not "the leaderboard" - because
  /// the sentence supplies its own article.
  Widget _failure(String? message, String what) {
    final notDeployed = (message ?? '').contains('404');

    return _pad(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Notice(
            icon: notDeployed
                ? Icons.cloud_off_rounded
                : Icons.error_outline_rounded,
            color: notDeployed ? const Color(0xFFB8860B) : LmsColors.error,
            text: notDeployed
                ? 'This server does not have the $what endpoint yet — it is '
                    'part of a build that has not been deployed. Nothing is '
                    'wrong with this test.'
                : message ?? 'Could not load $what.',
            action: TextButton(onPressed: _load, child: const Text('Retry')),
          ),
          if (notDeployed && message != null) ...[
            const SizedBox(height: 10),
            Text(message,
                style: const TextStyle(
                    fontSize: 11.5, color: LmsColors.textGrey)),
          ],
        ],
      ),
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  final LeaderboardRow row;

  const _LeaderboardTile({required this.row});

  Color get _rankColor => switch (row.rank) {
        1 => const Color(0xFFB8860B),
        2 => const Color(0xFF8A8A96),
        3 => const Color(0xFFA9714B),
        _ => LmsColors.textGrey,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: LmsColors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: LmsColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text('#${row.rank}',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _rankColor)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.studentName,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
                if (row.attemptCount != null || row.achievedAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (row.attemptCount != null)
                        '${row.attemptCount} attempt'
                            '${row.attemptCount == 1 ? '' : 's'}',
                      if (row.achievedAt != null) formatStamp(row.achievedAt!),
                    ].join(' · '),
                    style: const TextStyle(
                        fontSize: 11, color: LmsColors.textGrey),
                  ),
                ],
              ],
            ),
          ),
          if (row.scoreLabel != null)
            Text(row.scoreLabel!,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _AttemptTile extends StatelessWidget {
  final TestAttempt attempt;

  const _AttemptTile({required this.attempt});

  ({String label, Color color}) get _badge {
    if (attempt.isSubmitted) {
      return (label: 'SUBMITTED', color: LmsColors.success);
    }
    if (attempt.isExpired) {
      return (label: 'OUT OF TIME', color: LmsColors.error);
    }
    return (label: 'IN PROGRESS', color: const Color(0xFFB8860B));
  }

  @override
  Widget build(BuildContext context) {
    final badge = _badge;
    final percent = attempt.percent;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: LmsColors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: LmsColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(attempt.studentName,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badge.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(badge.label,
                    style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: badge.color)),
              ),
              if (attempt.scoreLabel != null) ...[
                const SizedBox(width: 10),
                Text(attempt.scoreLabel!,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w800)),
              ],
              if (percent != null) ...[
                const SizedBox(width: 6),
                Text('$percent%',
                    style: const TextStyle(
                        fontSize: 11.5, color: LmsColors.textGrey)),
              ],
            ],
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              if (attempt.correctCount != null)
                _Meta(Icons.check_circle_outline_rounded,
                    '${attempt.correctCount} correct'),
              if (attempt.wrongCount != null)
                _Meta(Icons.cancel_outlined, '${attempt.wrongCount} wrong'),
              if (attempt.skippedCount != null)
                _Meta(Icons.remove_circle_outline_rounded,
                    '${attempt.skippedCount} skipped'),
              if (attempt.startedAt != null)
                _Meta(Icons.play_arrow_rounded,
                    'Started ${formatStamp(attempt.startedAt!)}'),
              if (attempt.submittedAt != null)
                _Meta(Icons.done_all_rounded,
                    'Submitted ${formatStamp(attempt.submittedAt!)}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.7,
          color: LmsColors.textGrey,
        ),
      );
}

class _Note extends StatelessWidget {
  final String text;
  const _Note(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            fontSize: 11.5, height: 1.35, color: LmsColors.textGrey),
      );
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Meta(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: LmsColors.textGrey),
          const SizedBox(width: 5),
          Text(text,
              style:
                  const TextStyle(fontSize: 11, color: LmsColors.textGrey)),
        ],
      );
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final Widget? action;

  const _Notice({
    required this.icon,
    required this.text,
    this.color = LmsColors.primary,
    this.action,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style:
                      TextStyle(fontSize: 12.5, height: 1.35, color: color)),
            ),
            if (action != null) action!,
          ],
        ),
      );
}

/// The spread across the leaderboard.
///
/// Median sits next to average deliberately: one abandoned zero drags a mean
/// to a score no student actually sat.
class _StatsStrip extends StatelessWidget {
  final LeaderboardStats stats;

  const _StatsStrip({required this.stats});

  static String _n(num? value) {
    if (value == null) return '—';
    return value % 1 == 0 ? '${value.toInt()}' : value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final cells = <({String label, String value})>[
      (label: 'Highest', value: _n(stats.highest)),
      (label: 'Lowest', value: _n(stats.lowest)),
      (label: 'Average', value: _n(stats.average)),
      (label: 'Median', value: _n(stats.median)),
      if (stats.fastestSeconds != null)
        (label: 'Fastest', value: '${stats.fastestSeconds}s'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: LmsColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LmsColors.border),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < cells.length; i++) ...[
              if (i > 0)
                const VerticalDivider(width: 1, color: LmsColors.border),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Column(
                    children: [
                      Text(cells[i].value,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(cells[i].label,
                          style: const TextStyle(
                              fontSize: 10.5, color: LmsColors.textGrey)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

