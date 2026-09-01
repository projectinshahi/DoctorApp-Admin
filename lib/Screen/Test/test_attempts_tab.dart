import 'package:flutter/material.dart';

import '../../core/theam/theam_dart.dart';
import '../../models/admin_test_model.dart';
import '../../models/test_results_model.dart';
import '../../services/admin_test_service.dart';
import '../../widget/shimmer_loading.dart';
import '../../widget/student_progress_widgets.dart' show formatStamp;
import 'test_results_screen.dart';

/// Everything students have attempted on this course, in one list.
///
/// Built by asking each test that reports attempts for its own attempts -
/// there is no course-wide attempts endpoint. Tests with attemptCount == 0 are
/// never called, so an untouched course costs no requests at all.
class TestAttemptsTab extends StatefulWidget {
  /// The tests already loaded by the list tab, so this does not refetch them.
  final List<AdminTest> tests;

  const TestAttemptsTab({super.key, required this.tests});

  @override
  State<TestAttemptsTab> createState() => _TestAttemptsTabState();
}

class _TestAttemptsTabState extends State<TestAttemptsTab> {
  final _service = AdminTestService();

  /// Attempts paired with the test they belong to.
  List<({AdminTest test, TestAttempt attempt})> _rows = const [];

  bool _isLoading = false;
  String? _error;

  List<AdminTest> get _attempted =>
      widget.tests.where((t) => t.attemptCount > 0).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(TestAttemptsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The course changed upstream, so the attempts belong to a different set
    // of tests now.
    if (oldWidget.tests != widget.tests) _load();
  }

  Future<void> _load() async {
    final tests = _attempted;
    if (tests.isEmpty) {
      setState(() {
        _rows = const [];
        _isLoading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final results = await Future.wait(
      tests.map((t) => _service.getAttempts(t.id)),
    );

    if (!mounted) return;

    final rows = <({AdminTest test, TestAttempt attempt})>[];
    String? firstError;

    for (var i = 0; i < tests.length; i++) {
      final result = results[i];
      if (result.isSuccess) {
        for (final attempt in result.attempts) {
          rows.add((test: tests[i], attempt: attempt));
        }
      } else {
        firstError ??= result.errorMessage;
      }
    }

    // Most recent first: an admin opening this is looking at what just
    // happened, not at the oldest attempt on record.
    rows.sort((a, b) {
      final left = a.attempt.submittedAt ?? a.attempt.startedAt;
      final right = b.attempt.submittedAt ?? b.attempt.startedAt;
      if (left == null && right == null) return 0;
      if (left == null) return 1;
      if (right == null) return -1;
      return right.compareTo(left);
    });

    setState(() {
      _isLoading = false;
      _rows = rows;
      // Only a total failure is an error - one test's attempts failing still
      // leaves the rest worth showing.
      _error = rows.isEmpty ? firstError : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const ShimmerListSkeleton(rowCount: 4, padding: EdgeInsets.zero);
    }

    if (_error != null) {
      final notDeployed = _error!.contains('404');
      return _Notice(
        icon: notDeployed
            ? Icons.cloud_off_rounded
            : Icons.error_outline_rounded,
        color: notDeployed ? const Color(0xFFB8860B) : LmsColors.error,
        text: notDeployed
            ? 'This server does not have the attempts endpoint yet — it is '
                'part of a build that has not been deployed.'
            : _error!,
        action: TextButton(onPressed: _load, child: const Text('Retry')),
      );
    }

    if (widget.tests.isEmpty) {
      return const _Notice(
        icon: Icons.assignment_outlined,
        text: 'No tests on this course yet, so nothing has been attempted.',
      );
    }

    if (_rows.isEmpty) {
      return const _Notice(
        icon: Icons.how_to_reg_outlined,
        text: 'No student has attempted a test on this course yet.',
      );
    }

    final live = _rows.where((r) => r.attempt.isLive).toList();
    final expired =
        _rows.where((r) => r.attempt.isExpired && !r.attempt.isSubmitted).toList();
    final done = _rows.where((r) => r.attempt.isSubmitted).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_rows.length} attempt${_rows.length == 1 ? '' : 's'} '
                  'across ${_attempted.length} test'
                  '${_attempted.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                      fontSize: 12.5, color: LmsColors.textGrey),
                ),
              ),
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Refresh', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (live.isNotEmpty) ...[
            _Label('Sitting now · ${live.length}'),
            const SizedBox(height: 8),
            for (final row in live) _AttemptCard(row: row),
            const SizedBox(height: 18),
          ],

          if (expired.isNotEmpty) ...[
            _Label('Out of time · ${expired.length}'),
            const SizedBox(height: 4),
            const Text(
              'Started, ran out of time, and not yet closed — the server '
              'closes one only when the student next opens it.',
              style: TextStyle(
                  fontSize: 11.5, height: 1.35, color: LmsColors.textGrey),
            ),
            const SizedBox(height: 8),
            for (final row in expired) _AttemptCard(row: row),
            const SizedBox(height: 18),
          ],

          if (done.isNotEmpty) ...[
            _Label('Submitted · ${done.length}'),
            const SizedBox(height: 8),
            for (final row in done) _AttemptCard(row: row),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _AttemptCard extends StatelessWidget {
  final ({AdminTest test, TestAttempt attempt}) row;

  const _AttemptCard({required this.row});

  ({String label, Color color}) get _badge {
    final a = row.attempt;
    if (a.isSubmitted) return (label: 'SUBMITTED', color: LmsColors.success);
    if (a.isExpired) return (label: 'OUT OF TIME', color: LmsColors.error);
    return (label: 'IN PROGRESS', color: const Color(0xFFB8860B));
  }

  @override
  Widget build(BuildContext context) {
    final attempt = row.attempt;
    final badge = _badge;
    final when = attempt.submittedAt ?? attempt.startedAt;

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(attempt.studentName,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      [
                        row.test.title,
                        if (when != null) formatStamp(when),
                      ].join(' · '),
                      style: const TextStyle(
                          fontSize: 11, color: LmsColors.textGrey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
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
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              if (attempt.correctCount != null || attempt.wrongCount != null)
                Expanded(
                  child: Text(
                    [
                      if (attempt.correctCount != null)
                        '${attempt.correctCount} correct',
                      if (attempt.wrongCount != null)
                        '${attempt.wrongCount} wrong',
                      if (attempt.skippedCount != null)
                        '${attempt.skippedCount} skipped',
                    ].join(' · '),
                    style: const TextStyle(
                        fontSize: 11, color: LmsColors.textGrey),
                  ),
                )
              else
                const Spacer(),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TestResultsScreen(test: row.test),
                  ),
                ),
                child: const Text('Open results',
                    style: TextStyle(fontSize: 12)),
              ),
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
