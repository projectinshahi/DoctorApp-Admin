import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/const/responsive_const.dart';
import '../../core/theam/theam_dart.dart';
import '../../models/quiz_model.dart';
import '../../provider/quiz_health_provider.dart';
import '../../widget/quiz_preview_sheet.dart';
import '../../widget/shimmer_loading.dart';

/// Reports which quizzes cannot serve what they claim.
///
/// A quiz is a saved filter, not a container of questions, so it can be
/// perfectly valid and still be useless: unreachable because no lesson links
/// to it, or underfilled because its topic holds fewer questions than it asks
/// for. Neither shows up anywhere else in the panel.
///
/// This screen only reports. Fixing happens in the lesson and quiz editors -
/// there are deliberately no mutation buttons here.
class QuizHealthScreen extends StatefulWidget {
  const QuizHealthScreen({super.key});

  @override
  State<QuizHealthScreen> createState() => _QuizHealthScreenState();
}

class _QuizHealthScreenState extends State<QuizHealthScreen> {
  late final QuizHealthProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = QuizHealthProvider()..load();
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Consumer<QuizHealthProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.quizzes.isEmpty) {
            return const SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: ShimmerListSkeleton(rowCount: 4),
            );
          }

          if (provider.errorMessage != null) {
            return _ErrorState(message: provider.errorMessage!, onRetry: provider.load);
          }

          if (provider.quizzes.isEmpty) return const _NoQuizzesState();

          return RefreshIndicator(
            // Pool counts are computed live, so a refresh has to re-read them
            // rather than reuse anything from the last load.
            onRefresh: provider.load,
            color: LmsColors.primary,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              children: [
                _Header(provider: provider),
                const SizedBox(height: 18),
                ..._groups(provider),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _groups(QuizHealthProvider provider) {
    final orphaned = <Quiz>[];
    final underfilled = <Quiz>[];
    final healthy = <Quiz>[];

    for (final row in provider.quizzes) {
      final quiz = provider.quizFor(row.id);
      switch (provider.healthOf(quiz)) {
        case QuizHealth.orphaned:
          orphaned.add(quiz);
        case QuizHealth.underfilled:
          underfilled.add(quiz);
        case QuizHealth.healthy:
          healthy.add(quiz);
      }
    }

    return [
      if (orphaned.isNotEmpty)
        _Group(
          title: 'Not linked to a lesson',
          subtitle: 'These exist in the database but no student can reach them. '
              'Link one from a quiz-type lesson.',
          isWarning: true,
          quizzes: orphaned,
          provider: provider,
        ),
      if (underfilled.isNotEmpty)
        _Group(
          title: 'Serving fewer questions than they ask for',
          subtitle: 'The topic holds fewer active questions than the quiz requests. '
              'Import more, or lower the quiz\'s question count.',
          isWarning: true,
          quizzes: underfilled,
          provider: provider,
        ),
      if (healthy.isNotEmpty)
        _Group(
          title: 'Healthy',
          subtitle: null,
          isWarning: false,
          quizzes: healthy,
          provider: provider,
        ),
    ];
  }
}

class _Header extends StatelessWidget {
  final QuizHealthProvider provider;
  const _Header({required this.provider});

  @override
  Widget build(BuildContext context) {
    final orphaned = provider.countOf(QuizHealth.orphaned);
    final underfilled = provider.countOf(QuizHealth.underfilled);
    final total = provider.quizzes.length;
    final allHealthy = orphaned == 0 && underfilled == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Quizzes',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800, color: LmsColors.textDark)),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: LmsColors.primarySoft,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text('$total',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800, color: LmsColors.primary)),
            ),
            const Spacer(),
            if (!provider.isPoolComplete)
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.8, color: LmsColors.primary),
                  ),
                  SizedBox(width: 7),
                  Text('checking pools...',
                      style: TextStyle(fontSize: 11.5, color: LmsColors.textGrey)),
                ],
              ),
          ],
        ),
        const SizedBox(height: 12),

        // With nothing wrong, a warnings panel showing zeroes is just noise.
        if (allHealthy && provider.isPoolComplete)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: LmsColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: LmsColors.primary.withValues(alpha: 0.25)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 17, color: LmsColors.success),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Every quiz is linked to a lesson and can serve what it asks for.',
                    style: TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700, color: LmsColors.textDark),
                  ),
                ),
              ],
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (orphaned > 0)
                _SummaryTile(
                  count: orphaned,
                  label: orphaned == 1 ? 'unreachable quiz' : 'unreachable quizzes',
                  detail: 'no lesson links to it',
                  icon: Icons.link_off_rounded,
                ),
              if (underfilled > 0)
                _SummaryTile(
                  count: underfilled,
                  label: underfilled == 1 ? 'underfilled quiz' : 'underfilled quizzes',
                  detail: 'asks for more than it can serve',
                  icon: Icons.warning_amber_rounded,
                ),
            ],
          ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final int count;
  final String label;
  final String detail;
  final IconData icon;

  const _SummaryTile({
    required this.count,
    required this.label,
    required this.detail,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 210),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: LmsColors.errorBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LmsColors.errorBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: LmsColors.error),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$count $label',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800, color: LmsColors.error)),
              const SizedBox(height: 1),
              Text(detail,
                  style: const TextStyle(fontSize: 11, color: LmsColors.error)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool isWarning;
  final List<Quiz> quizzes;
  final QuizHealthProvider provider;

  const _Group({
    required this.title,
    required this.subtitle,
    required this.isWarning,
    required this.quizzes,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isWarning ? LmsColors.error : LmsColors.textDark)),
            const SizedBox(width: 8),
            Text('${quizzes.length}',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: LmsColors.textGrey)),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(subtitle!,
              style: const TextStyle(fontSize: 11.5, color: LmsColors.textGrey, height: 1.35)),
        ],
        const SizedBox(height: 10),
        ...quizzes.map((quiz) => _QuizRow(quiz: quiz, provider: provider)),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _QuizRow extends StatelessWidget {
  final Quiz quiz;
  final QuizHealthProvider provider;

  const _QuizRow({required this.quiz, required this.provider});

  @override
  Widget build(BuildContext context) {
    final isMobile = LmsResponsive.isMobile(context);
    final hasCounts = provider.hasPoolCounts(quiz.id);
    final isPoolLoading = provider.isPoolLoading(quiz.id);
    final isOrphan = !quiz.isTaken;
    final isBroken = isOrphan || (hasCounts && quiz.isUnderfilled);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LmsColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isBroken ? LmsColors.errorBorder : LmsColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(quiz.title,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: LmsColors.textDark)),
                    const SizedBox(height: 2),
                    Text(
                      '${quiz.subjectName ?? 'Subject ${quiz.subjectId}'} '
                      '› ${quiz.topicName ?? 'Topic ${quiz.topicId}'}',
                      style: const TextStyle(fontSize: 11.5, color: LmsColors.textGrey),
                    ),
                  ],
                ),
              ),
              if (!isMobile)
                TextButton.icon(
                  onPressed: () => showQuizPreviewSheet(context, quiz.id),
                  icon: const Icon(Icons.visibility_outlined, size: 15),
                  label: const Text('Preview',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 9),

          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (isOrphan)
                const _RowChip(
                  label: 'Not linked to a lesson',
                  icon: Icons.link_off_rounded,
                  isWarning: true,
                )
              else
                _QuietText('in ${quiz.linkedLessonTitle ?? 'a lesson'}'),
              if (quiz.examTag != null && quiz.examTag!.trim().isNotEmpty)
                _RowChip(label: quiz.examTag!.toUpperCase()),
              if (!quiz.isActive) _RowChip(label: quiz.status.toUpperCase(), isWarning: true),
            ],
          ),
          const SizedBox(height: 8),

          if (isPoolLoading)
            const _QuietText('checking how many questions it can serve...')
          else if (!hasCounts)
            // The detail call failed. The row is still valid; only the readout
            // is missing, so it says so rather than showing an error.
            const _QuietText('question counts unavailable')
          else ...[
            Text(
              quiz.questionCount == null
                  ? 'Serves all ${quiz.availableQuestions} matching questions'
                  : 'Serves ${quiz.servedQuestions} of ${quiz.availableQuestions} available',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: quiz.isUnderfilled ? LmsColors.error : LmsColors.textDark,
              ),
            ),
            if (quiz.isUnderfilled) ...[
              const SizedBox(height: 3),
              Text(
                'Asks for ${quiz.questionCount}, only ${quiz.availableQuestions} '
                'available',
                style: const TextStyle(fontSize: 11.5, color: LmsColors.error),
              ),
            ],
            if (quiz.availableQuestions == 0) ...[
              const SizedBox(height: 3),
              const Text('No active questions match this quiz at all.',
                  style: TextStyle(fontSize: 11.5, color: LmsColors.error)),
            ],
          ],
        ],
      ),
    );
  }
}

class _RowChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isWarning;

  const _RowChip({required this.label, this.icon, this.isWarning = false});

  @override
  Widget build(BuildContext context) {
    final color = isWarning ? LmsColors.error : LmsColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isWarning ? LmsColors.errorBg : LmsColors.primarySoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}

class _QuietText extends StatelessWidget {
  final String text;
  const _QuietText(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 11.5, color: LmsColors.textGrey));
}

class _NoQuizzesState extends StatelessWidget {
  const _NoQuizzesState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.assignment_outlined, size: 34, color: LmsColors.textGrey),
            const SizedBox(height: 12),
            const Text('No quizzes yet',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800, color: LmsColors.textDark)),
            const SizedBox(height: 6),
            const Text(
              'Quizzes are created from a quiz-type lesson: open a lesson, set its '
              'type to Quiz, pick a subject and topic, then use "New Quiz".',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: LmsColors.textGrey, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 30, color: LmsColors.error),
            const SizedBox(height: 10),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: LmsColors.error)),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
