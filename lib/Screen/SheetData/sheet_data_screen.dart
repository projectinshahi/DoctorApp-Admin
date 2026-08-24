import 'package:flutter/material.dart';

import '../../core/const/sheet_sources.dart';
import '../../core/theam/theam_dart.dart';
import '../../models/sheet_row_model.dart';
import '../../services/sheet_csv_service.dart';
import '../../widget/shimmer_loading.dart';

/// What the spreadsheet actually says, read straight from the published CSV.
///
/// Deliberately bypasses the API. Everywhere else in this panel shows what the
/// import produced; this shows the source, so the two can be compared when they
/// disagree - which is the question that keeps coming up.
class SheetDataScreen extends StatelessWidget {
  const SheetDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final subjects = SheetSources.tabs
        .map((tab) => SheetSubject(name: tab, url: SheetSources.csvUrlFor(tab)))
        .toList();

    return Scaffold(
      backgroundColor: LmsColors.bg,
      appBar: AppBar(
        backgroundColor: LmsColors.surface,
        foregroundColor: LmsColors.textDark,
        elevation: 0,
        title: const Text('Google Sheet data',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      ),
      body: subjects.isEmpty
          ? const _NoSources()
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: subjects.length,
              separatorBuilder: (_, _) => const Divider(height: 1, color: LmsColors.border),
              itemBuilder: (context, index) {
                final subject = subjects[index];
                return ListTile(
                  leading: const Icon(Icons.table_chart_outlined, color: LmsColors.primary),
                  title: Text(subject.name,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: const Text('Google Sheet tab',
                      style: TextStyle(fontSize: 11.5, color: LmsColors.textGrey)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SheetQuestionsScreen(subject: subject)),
                  ),
                );
              },
            ),
    );
  }
}

/// Every row of one sheet tab, exactly as the spreadsheet has it.
class SheetQuestionsScreen extends StatefulWidget {
  final SheetSubject subject;

  const SheetQuestionsScreen({super.key, required this.subject});

  @override
  State<SheetQuestionsScreen> createState() => _SheetQuestionsScreenState();
}

class _SheetQuestionsScreenState extends State<SheetQuestionsScreen> {
  final _service = SheetCsvService();

  // Built once, not inline in build(): FutureBuilder re-runs whatever future it
  // is handed, so building it in build() re-downloads on every rebuild.
  late Future<List<SheetQuestion>> _future = _service.fetchQuestions(widget.subject.url);

  void _retry() {
    // Block body, not an arrow: `setState(() => _future = ...)` returns the
    // assigned Future, and setState asserts when its callback returns one.
    setState(() {
      _future = _service.fetchQuestions(widget.subject.url);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LmsColors.bg,
      appBar: AppBar(
        backgroundColor: LmsColors.surface,
        foregroundColor: LmsColors.textDark,
        elevation: 0,
        title: Text(widget.subject.name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ),
      body: FutureBuilder<List<SheetQuestion>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: ShimmerListSkeleton(rowCount: 4),
            );
          }

          if (snapshot.hasError) {
            return _SheetError(message: snapshot.error.toString(), onRetry: _retry);
          }

          final rows = snapshot.data ?? const <SheetQuestion>[];
          if (rows.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text('That tab has no question rows yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: LmsColors.textGrey)),
              ),
            );
          }

          final active = rows.where((r) => r.isActive).length;

          return Column(
            children: [
              Container(
                width: double.infinity,
                color: LmsColors.surface,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Text(
                  '${rows.length} row${rows.length == 1 ? '' : 's'} in the sheet  ·  '
                  '$active active, ${rows.length - active} inactive',
                  style: const TextStyle(fontSize: 12, color: LmsColors.textGrey),
                ),
              ),
              const Divider(height: 1, color: LmsColors.border),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: rows.length,
                  itemBuilder: (_, index) =>
                      _SheetRowCard(question: rows[index], number: index + 1),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SheetRowCard extends StatelessWidget {
  final SheetQuestion question;
  final int number;

  const _SheetRowCard({required this.question, required this.number});

  @override
  Widget build(BuildContext context) {
    final isActive = question.isActive;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$number.',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800, color: LmsColors.textGrey)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(question.questionText,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: LmsColors.textDark)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          ...List.generate(question.options.length, (index) {
            final correct = question.isCorrect(index);
            return Padding(
              padding: const EdgeInsets.only(left: 18, bottom: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    correct ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    size: 13,
                    color: correct ? LmsColors.success : LmsColors.textGrey,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      question.options[index],
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: correct ? FontWeight.w700 : FontWeight.w500,
                        color: correct ? LmsColors.success : LmsColors.textDark,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          // A row whose correct_option points past its options has no answer at
          // all. Saying so beats silently marking nothing.
          if (question.correctIndex == null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 18),
              child: Text(
                'correct_option is "${question.correctOption}" but this row has '
                '${question.options.length} option'
                '${question.options.length == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 11, color: LmsColors.error),
              ),
            ),
          ],

          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 18),
            child: Wrap(
              spacing: 5,
              runSpacing: 4,
              children: [
                if (question.difficulty.isNotEmpty)
                  _Tag(label: question.difficulty.toUpperCase()),
                _Tag(
                  label: question.status.toUpperCase(),
                  color: isActive ? LmsColors.success : LmsColors.error,
                ),
                ...question.tags.map((t) => _Tag(label: t)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color? color;
  const _Tag({required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final tint = color ?? LmsColors.textGrey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: LmsColors.bg,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: tint.withValues(alpha: 0.35)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: tint)),
    );
  }
}

class _NoSources extends StatelessWidget {
  const _NoSources();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Text(
          'No sheet tabs configured yet.\n\n'
          'Add tab titles to SheetSources.tabs in '
          'lib/core/const/sheet_sources.dart.',
          textAlign: TextAlign.center,
          style: TextStyle(color: LmsColors.textGrey, height: 1.4),
        ),
      ),
    );
  }
}

class _SheetError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _SheetError({required this.message, required this.onRetry});

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
            const SizedBox(height: 14),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
