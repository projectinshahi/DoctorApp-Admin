import 'package:flutter/material.dart';

import '../core/theam/theam_dart.dart';
import '../models/quiz_model.dart';

/// The quiz block on the lesson detail screen.
///
/// Render rules, in order:
///   quiz != null            -> the quiz card, with warnings if it can't serve
///   quiz == null, type quiz -> "no quiz linked" prompt
///   any other lesson type   -> nothing at all
///
/// The three warnings all fail silently at save time and only surface when a
/// student opens the lesson, so they are shown here while the admin is still
/// looking at it.
class LessonQuizSection extends StatelessWidget {
  final String lessonType; // raw API value: 'video' | 'text' | 'quiz'
  final Quiz? quiz;

  /// Subject/topic names by id, so the card can say "Internal Med" instead of
  /// "Subject 7". The quiz nested on a lesson carries the ids and the counters
  /// but not the display names - those ride along only on quiz LIST rows.
  final Map<int, String> subjectNames;
  final Map<int, String> topicNames;
  final VoidCallback onPreview;
  final VoidCallback onLink;
  final VoidCallback? onUnlink;

  const LessonQuizSection({
    super.key,
    required this.lessonType,
    required this.quiz,
    required this.onPreview,
    required this.onLink,
    this.onUnlink,
    this.subjectNames = const {},
    this.topicNames = const {},
  });

  @override
  Widget build(BuildContext context) {
    final q = quiz;
    if (q == null) {
      return lessonType == 'quiz'
          ? _QuizEmptyState(onLink: onLink)
          : const SizedBox.shrink();
    }
    return _QuizCard(
      quiz: q,
      onPreview: onPreview,
      onChange: onLink,
      onUnlink: onUnlink,
      subjectNames: subjectNames,
      topicNames: topicNames,
    );
  }
}

class _QuizEmptyState extends StatelessWidget {
  final VoidCallback onLink;
  const _QuizEmptyState({required this.onLink});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LmsColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LmsColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.quiz_outlined, size: 22, color: LmsColors.textGrey),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No quiz linked',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: LmsColors.textDark)),
                SizedBox(height: 2),
                Text('This lesson is a quiz but has nothing to serve yet.',
                    style: TextStyle(fontSize: 11.5, color: LmsColors.textGrey)),
              ],
            ),
          ),
          TextButton(
            onPressed: onLink,
            child: const Text('Link a quiz',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _QuizCard extends StatelessWidget {
  final Quiz quiz;
  final VoidCallback onPreview;
  final VoidCallback onChange;
  final VoidCallback? onUnlink;
  final Map<int, String> subjectNames;
  final Map<int, String> topicNames;

  const _QuizCard({
    required this.quiz,
    required this.onPreview,
    required this.onChange,
    this.onUnlink,
    this.subjectNames = const {},
    this.topicNames = const {},
  });

  @override
  Widget build(BuildContext context) {
    // Counters are only reported by the lesson and preview responses. When
    // they're absent everything reads 0, which must not be mistaken for
    // "no questions match".
    final hasCounters = quiz.availableQuestions > 0 || quiz.servedQuestions > 0;
    final broken = (hasCounters && quiz.isEmpty) || !quiz.isActive;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: broken ? LmsColors.errorBg : LmsColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: broken ? LmsColors.errorBorder : LmsColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.quiz_rounded, size: 18, color: LmsColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  quiz.title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: LmsColors.textDark),
                ),
              ),
              if (onUnlink != null)
                IconButton(
                  tooltip: 'Unlink quiz',
                  icon: const Icon(Icons.link_off_rounded, size: 18),
                  color: LmsColors.textGrey,
                  onPressed: onUnlink,
                ),
            ],
          ),
          const SizedBox(height: 10),

          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (quiz.examTag != null && quiz.examTag!.trim().isNotEmpty)
                _QuizChip(label: quiz.examTag!.toUpperCase()),
              // Server name first, then the resolved one, then the id - an id
              // is still better than nothing when the taxonomy hasn't loaded.
              _QuizChip(
                label: quiz.subjectName ??
                    subjectNames[quiz.subjectId] ??
                    'Subject ${quiz.subjectId}',
              ),
              _QuizChip(
                label: quiz.topicName ??
                    topicNames[quiz.topicId] ??
                    'Topic ${quiz.topicId}',
              ),
              if (!quiz.isActive) _QuizChip(label: quiz.status.toUpperCase()),
            ],
          ),
          const SizedBox(height: 10),

          Text(
            _servingLine(hasCounters),
            style: const TextStyle(fontSize: 12, color: LmsColors.textGrey),
          ),

          if (hasCounters && quiz.isEmpty)
            const _QuizWarning(
              text: 'No questions match this quiz. Students will see an empty quiz.',
              isError: true,
            ),
          if (hasCounters && !quiz.isEmpty && quiz.isUnderfilled)
            _QuizWarning(
              text: 'Only ${quiz.availableQuestions} question'
                  '${quiz.availableQuestions == 1 ? '' : 's'} available, '
                  'but this quiz asks for ${quiz.questionCount}.',
              isError: false,
            ),
          if (!quiz.isActive)
            const _QuizWarning(
              text: 'This quiz is inactive. The lesson will fail to load for students.',
              isError: true,
            ),

          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: onPreview,
                style: OutlinedButton.styleFrom(
                  foregroundColor: LmsColors.primary,
                  side: const BorderSide(color: LmsColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('Preview questions',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onChange,
                child: const Text('Change',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _servingLine(bool hasCounters) {
    if (!hasCounters) {
      return quiz.questionCount == null
          ? 'Serves every matching question'
          : 'Serves ${quiz.questionCount} question'
              '${quiz.questionCount == 1 ? '' : 's'} per attempt';
    }
    if (quiz.questionCount == null) {
      return 'Serving all ${quiz.availableQuestions} matching questions';
    }
    return 'Serving ${quiz.servedQuestions} of ${quiz.availableQuestions} available '
        '(asks for ${quiz.questionCount})';
  }
}

class _QuizWarning extends StatelessWidget {
  final String text;
  final bool isError;
  const _QuizWarning({required this.text, required this.isError});

  @override
  Widget build(BuildContext context) {
    final color = isError ? LmsColors.error : Colors.orange.shade800;
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isError ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
              size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 11.5, color: color)),
          ),
        ],
      ),
    );
  }
}

class _QuizChip extends StatelessWidget {
  final String label;
  const _QuizChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: LmsColors.primarySoft,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 10.5, fontWeight: FontWeight.w700, color: LmsColors.primary)),
    );
  }
}
