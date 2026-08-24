import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/const/sheet_sources.dart';
import '../core/theam/theam_dart.dart';
import '../models/sheet_row_model.dart';
import '../services/sheet_csv_service.dart';

/// What the admin picked: a spreadsheet tab, and the first [questions.length]
/// active rows from it.
///
/// No database ids anywhere - this is the sheet's own content, which is the
/// point: the quiz is assembled from the source rather than from whatever the
/// importer last managed to write.
class SheetQuizSelection {
  final String subject;
  final String topic;
  final List<SheetQuestion> questions;

  const SheetQuizSelection({
    required this.subject,
    required this.topic,
    required this.questions,
  });

  String get tab => '$subject - $topic';

  /// Stored on the lesson's `content` field, which is already writable on both
  /// create and update - so the detail screen can rebuild this selection with
  /// no new endpoint.
  ///
  /// Only the filter travels: subject, topic and how many rows to take. The
  /// rows themselves are re-read from the sheet, so an edit in Google shows up
  /// on the lesson without re-saving it.
  String toContent() => jsonEncode({
        'source': _contentMarker,
        'subject': subject,
        'topic': topic,
        'questionCount': questions.length,
      });

  Map<String, dynamic> toPayload() => {
        'source': 'google-sheet',
        'sheetTab': tab,
        'subject': subject,
        'topic': topic,
        'questionCount': questions.length,
        'questions': [
          for (final q in questions)
            {
              'questionText': q.questionText,
              'difficulty': q.difficulty,
              'marksCorrect': q.marksCorrect,
              'marksIncorrect': q.marksIncorrect,
              'options': q.options,
              'correctOption': q.correctOption,
              'correctAnswer': q.correctAnswer,
              'explanation': q.explanation,
              'tags': q.tags,
            },
        ],
      };
}

/// Marks a `content` string as one of ours. A lesson saved before this flow
/// existed holds free text there, which must not be parsed as a quiz.
const String _contentMarker = 'google-sheet';

/// The filter a quiz lesson stored, read back off `content`.
///
/// Returns null for anything that isn't ours - legacy free text, empty, or
/// malformed - so the caller can fall back rather than showing an error.
class SheetQuizRef {
  final String subject;
  final String topic;
  final int questionCount;

  const SheetQuizRef({
    required this.subject,
    required this.topic,
    required this.questionCount,
  });

  String get tab => '$subject - $topic';

  static SheetQuizRef? fromContent(String? content) {
    if (content == null || content.trim().isEmpty) return null;

    final Object? decoded;
    try {
      decoded = jsonDecode(content);
    } on FormatException {
      return null; // legacy free-text reference
    }
    if (decoded is! Map || decoded['source'] != _contentMarker) return null;

    final subject = decoded['subject'];
    final topic = decoded['topic'];
    if (subject is! String || topic is! String) return null;

    return SheetQuizRef(
      subject: subject,
      topic: topic,
      questionCount: (decoded['questionCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Builds a quiz out of the question-bank spreadsheet.
///
/// Subject and topic are two dropdowns over the same tab list, so picking a
/// subject narrows the topics to the tabs that actually exist. Nothing here
/// touches the backend - the rows are read from Google as CSV.
class SheetQuizPicker extends StatefulWidget {
  /// Fires on every change, with null whenever the selection is incomplete
  /// (no tab chosen, or the tab has no usable rows).
  final ValueChanged<SheetQuizSelection?> onChanged;

  /// Set by the parent when Save was pressed with nothing selected.
  final String? validationError;

  const SheetQuizPicker({
    super.key,
    required this.onChanged,
    this.validationError,
  });

  @override
  State<SheetQuizPicker> createState() => _SheetQuizPickerState();
}

class _SheetQuizPickerState extends State<SheetQuizPicker> {
  final _service = SheetCsvService();

  String? _subject;
  String? _topic;

  /// Active rows only - an inactive row is one the sheet has retired, and
  /// serving it would contradict the sheet.
  List<SheetQuestion> _pool = [];
  int _inactiveCount = 0;

  /// How many of [_pool] go into the quiz. Always 1.._pool.length once loaded.
  int _count = 0;

  bool _isLoading = false;
  String? _loadError;

  List<SheetQuestion> get _selected => _pool.take(_count).toList();

  void _emit() => widget.onChanged(
        _subject != null && _topic != null && _count > 0
            ? SheetQuizSelection(
                subject: _subject!,
                topic: _topic!,
                questions: _selected,
              )
            : null,
      );

  Future<void> _onSubjectChanged(String? subject) async {
    if (subject == _subject) return;
    setState(() {
      _subject = subject;
      _topic = null;
      _pool = [];
      _inactiveCount = 0;
      _count = 0;
      _loadError = null;
    });
    _emit();
  }

  Future<void> _onTopicChanged(String? topic) async {
    if (topic == _topic) return;
    setState(() => _topic = topic);
    await _load();
  }

  Future<void> _load() async {
    final tab = SheetSources.tabFor(_subject, _topic);
    if (tab == null) return;

    setState(() {
      _isLoading = true;
      _loadError = null;
      _pool = [];
      _inactiveCount = 0;
      _count = 0;
    });
    _emit();

    try {
      final rows = await _service.fetchQuestions(SheetSources.csvUrlFor(tab));
      if (!mounted) return;
      final active = rows.where((q) => q.isActive).toList();
      setState(() {
        _isLoading = false;
        _pool = active;
        _inactiveCount = rows.length - active.length;
        // Default to the whole tab: trimming is the admin's call, and a quiz
        // that silently used 10 of 40 rows would be a surprise.
        _count = active.length;
      });
    } on SheetCsvException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = e.message;
      });
    }
    _emit();
  }

  void _setCount(int value) {
    final clamped = value.clamp(1, _pool.length);
    if (clamped == _count) return;
    setState(() => _count = clamped);
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final topics = SheetSources.topicsFor(_subject);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label('Quiz from Google Sheet'),
        const SizedBox(height: 4),
        const Text(
          'Questions are read live from the question-bank spreadsheet. '
          'No import needed - what the sheet says is what the quiz gets.',
          style: TextStyle(fontSize: 12, color: LmsColors.textGrey),
        ),
        const SizedBox(height: 12),

        _dropdown<String>(
          value: _subject,
          hint: 'Select subject',
          icon: Icons.menu_book_outlined,
          items: SheetSources.subjects,
          onChanged: _onSubjectChanged,
        ),
        const SizedBox(height: 10),

        _dropdown<String>(
          value: _topic,
          hint: _subject == null ? 'Topic (pick a subject first)' : 'Select topic',
          icon: Icons.topic_outlined,
          items: topics,
          onChanged: _subject == null ? null : _onTopicChanged,
        ),

        if (_isLoading) ...[
          const SizedBox(height: 14),
          const Row(
            children: [
              SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10),
              Text('Reading the sheet...',
                  style: TextStyle(fontSize: 12.5, color: LmsColors.textGrey)),
            ],
          ),
        ],

        if (_loadError != null) ...[
          const SizedBox(height: 12),
          _Banner(
            color: LmsColors.error,
            background: LmsColors.errorBg,
            border: LmsColors.errorBorder,
            icon: Icons.error_outline_rounded,
            text: _loadError!,
            action: TextButton(
              onPressed: _load,
              child: const Text('Retry', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],

        if (!_isLoading && _loadError == null && _topic != null) ...[
          const SizedBox(height: 14),
          if (_pool.isEmpty)
            const _Banner(
              color: LmsColors.error,
              background: LmsColors.errorBg,
              border: LmsColors.errorBorder,
              icon: Icons.report_problem_outlined,
              text: 'This tab has no active questions, so a quiz here would '
                  'serve nothing.',
            )
          else ...[
            _countPicker(),
            const SizedBox(height: 14),
            Text(
              'Showing the $_count question${_count == 1 ? '' : 's'} this quiz '
              'will use'
              '${_inactiveCount > 0 ? '  -  $_inactiveCount inactive row${_inactiveCount == 1 ? '' : 's'} skipped' : ''}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: LmsColors.textGrey,
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _selected.length; i++) ...[
              SheetQuestionCard(index: i, question: _selected[i]),
              const SizedBox(height: 10),
            ],
          ],
        ],

        if (widget.validationError != null) ...[
          const SizedBox(height: 8),
          Text(widget.validationError!,
              style: const TextStyle(fontSize: 12, color: LmsColors.error)),
        ],
      ],
    );
  }

  /// Number of questions. A slider alone can't be typed into and a text field
  /// alone gives no sense of the range, so it's both against the same value.
  Widget _countPicker() {
    final max = _pool.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      decoration: BoxDecoration(
        color: LmsColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LmsColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tag_rounded, size: 16, color: LmsColors.textGrey),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Questions in this quiz',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: _count > 1 ? () => _setCount(_count - 1) : null,
                icon: const Icon(Icons.remove_circle_outline, size: 20),
              ),
              SizedBox(
                width: 34,
                child: Text(
                  '$_count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: _count < max ? () => _setCount(_count + 1) : null,
                icon: const Icon(Icons.add_circle_outline, size: 20),
              ),
              Text('of $max',
                  style: const TextStyle(
                      fontSize: 12, color: LmsColors.textGrey)),
            ],
          ),
          // A one-row tab has nothing to slide between, and Slider asserts
          // when min == max.
          if (max > 1)
            Slider(
              value: _count.toDouble().clamp(1, max.toDouble()),
              min: 1,
              max: max.toDouble(),
              divisions: max - 1,
              label: '$_count',
              onChanged: (v) => _setCount(v.round()),
            ),
        ],
      ),
    );
  }

  Widget _dropdown<T>({
    required T? value,
    required String hint,
    required IconData icon,
    required List<T> items,
    required ValueChanged<T?>? onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: LmsColors.textGrey, fontSize: 13.5),
        prefixIcon: Icon(icon, size: 18, color: LmsColors.textGrey),
        filled: true,
        fillColor: LmsColors.bg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: LmsColors.border),
        ),
      ),
      items: [
        for (final item in items)
          DropdownMenuItem<T>(
            value: item,
            child: Text('$item',
                style: const TextStyle(fontSize: 13.5), overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

/// One sheet row, rendered whole: text, scoring, every option with the correct
/// one marked, and the explanation.
class SheetQuestionCard extends StatelessWidget {
  final int index;
  final SheetQuestion question;

  const SheetQuestionCard({
    super.key,
    required this.index,
    required this.question,
  });

  @override
  Widget build(BuildContext context) {
    final correct = question.correctIndex;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LmsColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LmsColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: LmsColors.primarySoft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('${index + 1}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: LmsColors.primary)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(question.questionText,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        height: 1.35)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (question.difficulty.isNotEmpty)
                _Tag(question.difficulty, LmsColors.textGrey),
              if (question.marksCorrect.isNotEmpty)
                _Tag('+${question.marksCorrect} correct', LmsColors.success),
              if (question.marksIncorrect.isNotEmpty)
                _Tag('${question.marksIncorrect} wrong', LmsColors.error),
              for (final tag in question.tags) _Tag(tag, LmsColors.primary),
            ],
          ),
          const SizedBox(height: 10),

          for (var i = 0; i < question.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    question.isCorrect(i)
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked,
                    size: 15,
                    color: question.isCorrect(i)
                        ? LmsColors.success
                        : LmsColors.textGrey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${String.fromCharCode(65 + i)}. ${question.options[i]}',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.3,
                        fontWeight: question.isCorrect(i)
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: question.isCorrect(i)
                            ? LmsColors.success
                            : LmsColors.textDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // correct_option pointing outside the option list means the sheet
          // row is wrong - say so rather than silently marking nothing.
          if (correct == null) ...[
            const SizedBox(height: 6),
            Text(
              'correct_option is ${question.correctOption}, but this row has '
              '${question.options.length} options - no answer key.',
              style: const TextStyle(fontSize: 11.5, color: LmsColors.error),
            ),
          ],

          if (question.explanation.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: LmsColors.bg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                question.explanation,
                style: const TextStyle(
                    fontSize: 12, height: 1.4, color: LmsColors.textGrey),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;

  const _Tag(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _Banner extends StatelessWidget {
  final Color color;
  final Color background;
  final Color border;
  final IconData icon;
  final String text;
  final Widget? action;

  const _Banner({
    required this.color,
    required this.background,
    required this.border,
    required this.icon,
    required this.text,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
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
          if (action != null) action!,
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w800, color: LmsColors.textDark));
  }
}
