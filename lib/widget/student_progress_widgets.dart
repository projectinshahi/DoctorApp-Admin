import 'package:flutter/material.dart';

import '../core/theam/theam_dart.dart';
import '../models/student_progress_model.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// The one card look shared by every surface on the student screens.
///
/// Defined once so a row on the summary and the same row on its breakdown
/// screen cannot drift apart in radius, border or lift.
final BoxDecoration lmsCard = BoxDecoration(
  color: LmsColors.surface,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: LmsColors.border),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.03),
      blurRadius: 10,
      offset: const Offset(0, 3),
    ),
  ],
);

String formatStamp(DateTime value) {
  final d = value.toLocal();
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${_months[d.month - 1]} ${d.year}, '
      '$hour:$minute ${d.hour < 12 ? 'AM' : 'PM'}';
}

/// "4 minutes ago". Relative, because the question this answers is "is this
/// student active right now?" - and an absolute clock time makes the reader do
/// the subtraction.
///
/// Falls back to the absolute stamp past a week, where "23 days ago" stops
/// being easier to read than the date.
String relativeStamp(DateTime value) {
  final diff = DateTime.now().difference(value.toLocal());

  if (diff.isNegative) return 'just now';
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
  }
  if (diff.inHours < 24) {
    return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
  }
  if (diff.inDays < 7) {
    return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  }
  return formatStamp(value);
}

/// "inProgress" -> "In progress". Used so a counter the backend adds later
/// still reads as a label without a model change.
String humanizeKey(String key) {
  final spaced = key.replaceAllMapped(
    RegExp(r'(?<=[a-z0-9])([A-Z])'),
    (m) => ' ${m[1]!.toLowerCase()}',
  );
  return spaced.isEmpty ? spaced : spaced[0].toUpperCase() + spaced.substring(1);
}

/// A lesson line inside a chapter.
///
/// `completed: true` with `visibleToStudent: false` is not a contradiction -
/// the student finished the lesson and then lost access when their
/// subscription lapsed - so it renders as completed AND locked, not as an
/// error and not as incomplete.
class LessonProgressRow extends StatelessWidget {
  final LessonProgress lesson;

  const LessonProgressRow({super.key, required this.lesson});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            lesson.completed
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked,
            size: 14,
            color: lesson.completed ? LmsColors.success : LmsColors.textGrey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(lesson.title,
                style: const TextStyle(fontSize: 12, height: 1.3)),
          ),
          if (!lesson.visibleToStudent) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: lesson.isCompletedButLocked
                  ? 'Finished, then access lapsed'
                  : 'Not available to this student',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: LmsColors.textGrey.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline_rounded,
                        size: 10, color: LmsColors.textGrey),
                    SizedBox(width: 3),
                    Text('LOCKED',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: LmsColors.textGrey)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AttemptRow extends StatelessWidget {
  final AttemptSummary attempt;

  const AttemptRow({super.key, required this.attempt});

  @override
  Widget build(BuildContext context) {
    final score = attempt.scoreLabel;
    final percent = attempt.percent;
    final when = attempt.at;

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: lmsCard,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(attempt.title,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
                if (when != null || attempt.status != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (attempt.status != null) attempt.status!,
                      if (when != null) formatStamp(when),
                    ].join(' · '),
                    style: const TextStyle(
                        fontSize: 11, color: LmsColors.textGrey),
                  ),
                ],
                // Absent while the attempt is still running, so its absence
                // is information rather than a gap.
                if (attempt.leaderboard != null) ...[
                  const SizedBox(height: 6),
                  LeaderboardChip(board: attempt.leaderboard!),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          // The percentage leads, with the raw score under it. `percent` is
          // derived from score/total when the API omits it, so an attempt that
          // has a score always shows one.
          if (percent != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$percent%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: percent >= 50 ? LmsColors.success : LmsColors.error,
                    )),
                if (score != null) ...[
                  const SizedBox(height: 2),
                  Text(score,
                      style: const TextStyle(
                          fontSize: 11, color: LmsColors.textGrey)),
                ],
              ],
            )
          else if (score != null)
            Text(score,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w800))
          else
            // Said outright: an unscored attempt is a fact about the attempt,
            // not a blank space that reads as a broken row.
            const Text('Not scored',
                style: TextStyle(fontSize: 11, color: LmsColors.textGrey)),
        ],
      ),
    );
  }
}

/// A percentage as a ring rather than a bar.
///
/// Sized by [diameter] and never stretched: it lives inside a Wrap on the
/// student screen, where an unbounded height would throw at layout time.
class ProgressRing extends StatelessWidget {
  final int? percent;
  final Color color;
  final double diameter;
  final double stroke;

  /// Shown in the middle instead of the percentage. Used for "—" when the
  /// course has none of this kind at all.
  final String? overrideLabel;

  const ProgressRing({
    super.key,
    required this.percent,
    required this.color,
    this.diameter = 62,
    this.stroke = 6,
    this.overrideLabel,
  });

  @override
  Widget build(BuildContext context) {
    final value = percent == null ? 0.0 : percent!.clamp(0, 100) / 100;

    return SizedBox(
      width: diameter,
      height: diameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: stroke,
              strokeCap: StrokeCap.round,
              backgroundColor: LmsColors.border,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Text(
            overrideLabel ?? (percent == null ? '—' : '$percent%'),
            style: TextStyle(
              fontSize: diameter * 0.26,
              fontWeight: FontWeight.w800,
              color: overrideLabel != null ? LmsColors.textGrey : color,
            ),
          ),
        ],
      ),
    );
  }
}

/// One completion metric as a ring tile.
class ProgressRingTile extends StatelessWidget {
  final String label;
  final ProgressBlock block;
  final Color color;
  final VoidCallback? onTap;
  final double width;

  const ProgressRingTile({
    super.key,
    required this.label,
    required this.block,
    required this.color,
    required this.width,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final total = block['total'];
    final done = block['completed'] ?? 0;
    final inProgress = block['inProgress'];

    // A total of 0 is not 0% - "no videos on this course" and "watched none of
    // the 3 videos" are different facts about the student.
    final none = total == null || total == 0;

    final card = Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: lmsCard,
      child: Column(
        children: [
          ProgressRing(
            percent: none ? null : (block['percent'] ?? 0),
            color: color,
            overrideLabel: none ? '—' : null,
          ),
          const SizedBox(height: 12),
          Text(label,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(
            none ? 'None on this course' : '$done of $total done',
            style: const TextStyle(fontSize: 11.5, color: LmsColors.textGrey),
            textAlign: TextAlign.center,
          ),
          if (!none && (inProgress ?? 0) > 0) ...[
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFB8860B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text('$inProgress in progress',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFB8860B))),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: card,
    );
  }
}

/// Completed / In progress / Not started, as three counts side by side.
class StatusSplit extends StatelessWidget {
  final int completed;
  final int? inProgress;

  /// Null when the API did not report a total, so "not started" cannot be
  /// derived without inventing a denominator.
  final int? notStarted;

  const StatusSplit({
    super.key,
    required this.completed,
    this.inProgress,
    this.notStarted,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cell('Completed', completed, LmsColors.success),
          if (inProgress != null) ...[
            const VerticalDivider(width: 1, color: LmsColors.border),
            _cell('In progress', inProgress!, const Color(0xFFB8860B)),
          ],
          if (notStarted != null) ...[
            const VerticalDivider(width: 1, color: LmsColors.border),
            _cell('Not started', notStarted!, LmsColors.textGrey),
          ],
        ],
      ),
    );
  }

  Widget _cell(String label, int value, Color color) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Text('$value',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: color)),
              const SizedBox(height: 2),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: LmsColors.textGrey)),
            ],
          ),
        ),
      );
}

/// A lesson row that also names the chapter it came from, for the lists
/// that mix chapters together.
///
/// Same visual weight as [AttemptRow] so lessons and quiz attempts read as
/// one list of the student's work rather than two unrelated designs.
class LessonItemRow extends StatelessWidget {
  final LessonProgress lesson;
  final List<ChapterProgress> chapters;

  const LessonItemRow({
    super.key,
    required this.lesson,
    this.chapters = const [],
  });

  String? get _chapterTitle {
    for (final c in chapters) {
      if (c.lessons.any((l) => l.id == lesson.id)) return c.title;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final chapter = _chapterTitle;

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: lmsCard,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            lesson.completed
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked,
            size: 16,
            color: lesson.completed ? LmsColors.success : LmsColors.textGrey,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lesson.title,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700)),
                if (chapter != null) ...[
                  const SizedBox(height: 2),
                  Text(chapter,
                      style: const TextStyle(
                          fontSize: 11, color: LmsColors.textGrey)),
                ],
              ],
            ),
          ),
          if (!lesson.visibleToStudent) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: lesson.isCompletedButLocked
                  ? 'Finished, then access lapsed'
                  : 'Not available to this student',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: LmsColors.textGrey.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('LOCKED',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: LmsColors.textGrey)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Where this student placed on the test's leaderboard.
///
/// The same figure for every retake of the same paper - a leaderboard ranks
/// students, not attempts - so it is shown once per row rather than implied to
/// be the rank of this particular sitting.
class LeaderboardChip extends StatelessWidget {
  final AttemptLeaderboard board;

  const LeaderboardChip({super.key, required this.board});

  /// Top three earn the highlight; everyone else stays neutral so the colour
  /// still means something.
  Color get _color {
    final rank = board.rank;
    if (rank == null) return LmsColors.textGrey;
    return switch (rank) {
      1 => const Color(0xFFB8860B),
      2 => const Color(0xFF8A8A96),
      3 => const Color(0xFFA9714B),
      _ => LmsColors.primary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final place = board.placeLabel;
    final best = board.bestScore;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            board.rank == 1
                ? Icons.emoji_events_rounded
                : Icons.leaderboard_outlined,
            size: 12,
            color: _color,
          ),
          const SizedBox(width: 6),
          Text(
            [
              if (place != null) place,
              if (best != null)
                'best ${best % 1 == 0 ? best.toInt() : best}',
            ].join(' · '),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: _color,
            ),
          ),
        ],
      ),
    );
  }
}
