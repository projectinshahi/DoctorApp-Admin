import 'package:flutter/material.dart';

import '../../core/theam/theam_dart.dart';
import '../../models/student_progress_model.dart';
import '../../widget/student_progress_widgets.dart';

/// The breakdown behind one progress row.
///
/// Opened by tapping Lessons, Videos, Quizzes, Tests or the question bank on
/// the student detail screen. It shows the same percentage as the row that
/// opened it, every counter the API reported for that metric, and the items
/// themselves *where the API itemises them*.
///
/// It does not itemise what the API only counts. GET /admin/students/:id
/// returns per-lesson rows inside `chapters[]` and per-attempt rows in the two
/// history arrays, but videos, notes and question-bank questions arrive as
/// totals only - so those open to their counters and say plainly that there is
/// no per-item breakdown, rather than showing an empty list that reads as "the
/// student did nothing".
class StudentProgressDetailScreen extends StatelessWidget {
  final String title;
  final String studentName;
  final ProgressBlock block;

  /// Per-lesson rows, grouped by chapter. Only the Lessons metric has these.
  final List<ChapterProgress> chapters;

  /// Attempt history. Only the Quizzes and Tests metrics have these.
  final List<AttemptSummary> attempts;

  /// Why there are no items, when there are none to show.
  final String? noItemsNote;

  /// Set when [attempts] came from an array the API caps at 20.
  final bool historyIsCapped;

  const StudentProgressDetailScreen({
    super.key,
    required this.title,
    required this.studentName,
    required this.block,
    this.chapters = const [],
    this.attempts = const [],
    this.noItemsNote,
    this.historyIsCapped = false,
  });

  /// Lessons the API itemises, split by whether they are done.
  List<LessonProgress> get _completedLessons =>
      [for (final c in chapters) ...c.completedLessons];

  List<LessonProgress> get _pendingLessons =>
      [for (final c in chapters) ...c.pendingLessons];

  List<AttemptSummary> get _completedAttempts =>
      attempts.where((a) => !a.isInProgress).toList();

  List<AttemptSummary> get _openAttempts =>
      attempts.where((a) => a.isInProgress).toList();

  @override
  Widget build(BuildContext context) {
    final total = block['total'];
    final completed = block['completed'] ?? block['attempted'] ?? 0;
    final inProgress = block['inProgress'];
    final none = total != null && total == 0;

    // Not started is only shown when the API gave a total. Deriving it from a
    // missing denominator would be inventing a number.
    final notStarted = total == null
        ? null
        : (total - completed - (inProgress ?? 0)).clamp(0, total);

    final counters = block.values.keys
        .where((k) => k != 'percent' && k != 'total' && k != 'completed')
        .toList()
      ..sort();

    return Scaffold(
      backgroundColor: LmsColors.bg,
      appBar: AppBar(
        backgroundColor: LmsColors.bg,
        elevation: 0,
        foregroundColor: LmsColors.textDark,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 15.5, fontWeight: FontWeight.w800)),
            Text(studentName,
                style: const TextStyle(
                    fontSize: 11.5, color: LmsColors.textGrey),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // Ring, then the completed / in progress / not started split - the
          // three states this screen exists to separate.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 4),
            decoration: lmsCard,
            child: Column(
              children: [
                ProgressRing(
                  percent: none ? null : block['percent'],
                  color: LmsColors.primary,
                  diameter: 96,
                  stroke: 9,
                  overrideLabel: none ? '—' : null,
                ),
                const SizedBox(height: 12),
                Text(
                  none
                      ? 'None on this course'
                      : '$completed of ${total ?? completed} complete',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                if (!none) ...[
                  const Divider(height: 1, color: LmsColors.border),
                  StatusSplit(
                    completed: completed,
                    inProgress: inProgress,
                    notStarted: notStarted,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),

          if (chapters.isNotEmpty) ...[
            if (_pendingLessons.isNotEmpty) ...[
              _Label('In progress · ${_pendingLessons.length}'),
              const SizedBox(height: 8),
              for (final lesson in _pendingLessons)
                LessonItemRow(lesson: lesson, chapters: chapters),
              const SizedBox(height: 18),
            ],
            if (_completedLessons.isNotEmpty) ...[
              _Label('Completed · ${_completedLessons.length}'),
              const SizedBox(height: 8),
              for (final lesson in _completedLessons)
                LessonItemRow(lesson: lesson, chapters: chapters),
            ],
          ] else if (attempts.isNotEmpty) ...[
            if (_openAttempts.isNotEmpty) ...[
              _Label('In progress · ${_openAttempts.length}'),
              const SizedBox(height: 8),
              for (final attempt in _openAttempts) AttemptRow(attempt: attempt),
              const SizedBox(height: 18),
            ],
            if (_completedAttempts.isNotEmpty) ...[
              _Label('Completed · ${_completedAttempts.length}'),
              const SizedBox(height: 8),
              for (final attempt in _completedAttempts)
                AttemptRow(attempt: attempt),
            ],
            if (historyIsCapped) ...[
              const SizedBox(height: 10),
              const _Note(
                icon: Icons.more_horiz_rounded,
                color: LmsColors.textGrey,
                text: 'History is capped at 20 attempts. There may be older '
                    'attempts that this endpoint does not return.',
              ),
            ],
          ] else ...[
            if (counters.isNotEmpty) ...[
              const _Label('Reported counters'),
              const SizedBox(height: 8),
              Container(
                decoration: lmsCard,
                child: Column(
                  children: [
                    for (var i = 0; i < counters.length; i++) ...[
                      if (i > 0)
                        const Divider(height: 1, color: LmsColors.border),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(humanizeKey(counters[i]),
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      color: LmsColors.textDark)),
                            ),
                            Text('${block[counters[i]]}',
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            if (noItemsNote != null)
              _Note(
                icon: Icons.info_outline_rounded,
                color: LmsColors.textGrey,
                text: noItemsNote!,
              ),
          ],
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
  final IconData icon;
  final String text;
  final Color color;

  const _Note({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
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
                  style: TextStyle(fontSize: 12.5, height: 1.35, color: color)),
            ),
          ],
        ),
      );
}
