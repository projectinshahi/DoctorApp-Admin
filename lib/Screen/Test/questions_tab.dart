import 'package:flutter/material.dart';

import '../../core/theam/theam_dart.dart';
import '../../models/admin_test_model.dart';
import '../../services/admin_test_service.dart';
import '../../widget/question_image_view.dart';
import '../../widget/shimmer_loading.dart';
import 'question_form_sheet.dart';

/// Fix the paper the CSV built.
///
/// A typo in question 87 of a 200-row import should not mean re-uploading the
/// file, so questions are editable one at a time here.
///
/// Sections are derived, not stored: a part of the paper exists exactly when
/// questions carry its name. There is no section CRUD, and renaming a part
/// means editing `section` on its questions.
class QuestionsTab extends StatefulWidget {
  final AdminTest test;

  const QuestionsTab({super.key, required this.test});

  @override
  State<QuestionsTab> createState() => _QuestionsTabState();
}

class _QuestionsTabState extends State<QuestionsTab> {
  final _service = AdminTestService();

  TestPreview? _preview;
  bool _isLoading = false;
  String? _error;

  /// Kept live from the POST/DELETE responses so the counter does not need a
  /// refetch to move.
  int? _questionCount;
  bool? _readyToPublish;

  bool get _isLocked => widget.test.isLocked;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await _service.preview(widget.test.id);
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.isSuccess) {
        _preview = result.preview;
        _questionCount = result.preview?.questions.length;
        _readyToPublish = result.preview?.test?.readyToPublish;
      } else {
        _error = result.errorMessage;
      }
    });
  }

  Future<void> _openForm({TestPreviewQuestion? question}) async {
    final preview = _preview;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => QuestionFormSheet(
        testId: widget.test.id,
        existing: question,
        knownSections: preview?.sectionNames ?? const [],
        // Appending lands after the last question; the server rejects
        // anything above lastOrder + 1.
        nextOrder: (preview?.questions.length ?? 0) + 1,
      ),
    );

    if (saved == true) {
      await _load();
    }
  }

  Future<void> _confirmDelete(TestPreviewQuestion question, int number) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete question $number?'),
        content: const Text(
          'The gap closes and every question after it moves up one, so the '
          'paper stays numbered 1 to n.',
          style: TextStyle(fontSize: 13.5, height: 1.45),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: LmsColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final result = await _service.deleteQuestion(widget.test.id, question.id);
    if (!mounted) return;

    if (result.isSuccess) {
      setState(() {
        _questionCount = result.questionCount ?? _questionCount;
        _readyToPublish = result.readyToPublish ?? _readyToPublish;
      });
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'That did not work'),
          backgroundColor: LmsColors.error,
        ),
      );
    }
  }

  /// Moving a question swaps it with whatever holds the target slot - that is
  /// what the server does, and what dragging a row means.
  Future<void> _move(TestPreviewQuestion question, int targetOrder) async {
    final result = await _service.updateQuestion(
      widget.test.id,
      question.id,
      {'questionOrder': targetOrder},
    );
    if (!mounted) return;

    if (result.isSuccess) {
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Could not reorder'),
          backgroundColor: LmsColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final questions = preview?.questions ?? const <TestPreviewQuestion>[];
    final count = _questionCount ?? questions.length;

    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: ShimmerListSkeleton(rowCount: 5, padding: EdgeInsets.zero),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: _Notice(
          icon: Icons.error_outline_rounded,
          color: LmsColors.error,
          text: _error!,
          action: TextButton(onPressed: _load, child: const Text('Retry')),
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: LmsColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '$count of ${widget.test.totalQuestions} questions'
                  '${_readyToPublish == true ? ' · ready to publish' : ''}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _readyToPublish == true
                        ? LmsColors.success
                        : LmsColors.textGrey,
                  ),
                ),
              ),
              // Every control here is hidden on a locked paper - the server
              // refuses all three writes with a 409 once students have sat it.
              if (!_isLocked)
                FilledButton.icon(
                  onPressed: () => _openForm(),
                  style: FilledButton.styleFrom(
                    backgroundColor: LmsColors.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Add question',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        ),
        Expanded(child: _body(preview, questions)),
      ],
    );
  }

  Widget _body(TestPreview? preview, List<TestPreviewQuestion> questions) {
    final sections = preview?.sections ?? const <TestSection>[];
    final broken = sections.where((s) => !s.contiguous).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        // Locked is read from the test, not discovered on save: the server
        // refuses every write with a 409 once students have sat the paper.
        if (_isLocked) ...[
          const _Notice(
            icon: Icons.lock_outline_rounded,
            color: LmsColors.textGrey,
            text: 'Students have already sat this test, so its questions can '
                'no longer be changed.',
          ),
          const SizedBox(height: 16),
        ],

        // Half-labelled: some questions sit outside every part, which is
        // invisible until a student sees the paper.
        if (preview?.isPartlySectioned ?? false) ...[
          _Notice(
            icon: Icons.report_problem_outlined,
            color: const Color(0xFFB8860B),
            text: '${preview!.unsectionedCount} question'
                '${preview.unsectionedCount == 1 ? '' : 's'} '
                '${preview.unsectionedCount == 1 ? 'has' : 'have'} no section '
                'while the rest are grouped into parts. '
                '${preview.unsectionedCount == 1 ? 'It' : 'They'} will render '
                'outside every part.',
          ),
          const SizedBox(height: 16),
        ],

        if (broken.isNotEmpty) ...[
          _Notice(
            icon: Icons.shuffle_rounded,
            color: const Color(0xFFB8860B),
            text: broken.length == 1
                ? '"${broken.first.name}" is not consecutive — the paper runs '
                    'into another part and back again. Usually a reorder that '
                    'went wrong.'
                : '${broken.length} sections are not consecutive — their '
                    'questions are interleaved with other parts.',
          ),
          const SizedBox(height: 16),
        ],

        if (questions.isEmpty)
          const _Notice(
            icon: Icons.quiz_outlined,
            text: 'No questions yet. Upload a CSV, or add them one at a time.',
          )
        else
          ..._grouped(questions, sections),
      ],
    );
  }

  /// Questions under their section headers, in paper order.
  ///
  /// Grouped by walking the list rather than by section metadata, so a
  /// non-contiguous part shows up honestly as two blocks instead of being
  /// silently tidied into one.
  List<Widget> _grouped(
    List<TestPreviewQuestion> questions,
    List<TestSection> sections,
  ) {
    final widgets = <Widget>[];
    String? currentSection;
    var isFirst = true;

    for (var i = 0; i < questions.length; i++) {
      final question = questions[i];
      final section = question.section;

      if (isFirst || section != currentSection) {
        currentSection = section;
        isFirst = false;

        final meta = sections.where((s) => s.name == section).firstOrNull;
        widgets
          ..add(SizedBox(height: widgets.isEmpty ? 0 : 18))
          ..add(_SectionHeader(
            name: section ?? 'No section',
            questionCount: meta?.questionCount,
            contiguous: meta?.contiguous ?? true,
            isUnsectioned: section == null,
          ))
          ..add(const SizedBox(height: 10));
      }

      widgets
        ..add(_QuestionCard(
          question: question,
          number: i + 1,
          locked: _isLocked,
          canMoveUp: i > 0,
          canMoveDown: i < questions.length - 1,
          onEdit: () => _openForm(question: question),
          onDelete: () => _confirmDelete(question, i + 1),
          onMoveUp: () => _move(question, i),
          onMoveDown: () => _move(question, i + 2),
        ))
        ..add(const SizedBox(height: 9));
    }

    return widgets;
  }
}

class _SectionHeader extends StatelessWidget {
  final String name;
  final int? questionCount;
  final bool contiguous;
  final bool isUnsectioned;

  const _SectionHeader({
    required this.name,
    this.questionCount,
    required this.contiguous,
    required this.isUnsectioned,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          isUnsectioned ? Icons.horizontal_rule_rounded : Icons.folder_outlined,
          size: 15,
          color: LmsColors.textGrey,
        ),
        const SizedBox(width: 8),
        Text(
          name.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: LmsColors.textGrey,
          ),
        ),
        if (questionCount != null) ...[
          const SizedBox(width: 8),
          Text('· $questionCount',
              style:
                  const TextStyle(fontSize: 11, color: LmsColors.textGrey)),
        ],
        if (!contiguous) ...[
          const SizedBox(width: 10),
          Tooltip(
            message: 'This part\'s questions are not consecutive — the paper '
                'leaves it and comes back.',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFB8860B).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('SPLIT',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFB8860B))),
            ),
          ),
        ],
        const Expanded(child: Divider(indent: 12, color: LmsColors.border)),
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final TestPreviewQuestion question;
  final int number;
  final bool locked;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  const _QuestionCard({
    required this.question,
    required this.number,
    required this.locked,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onEdit,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  @override
  Widget build(BuildContext context) {
    final correct = question.correctIndex;

    return Container(
      padding: const EdgeInsets.all(14),
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
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: LmsColors.textGrey)),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      // An image-only stem is legitimate — an ECG is often the
                      // whole question — so empty text is labelled, not blank.
                      question.questionText.trim().isEmpty
                          ? '(image only)'
                          : question.questionText,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                        color: question.questionText.trim().isEmpty
                            ? LmsColors.textGrey
                            : LmsColors.textDark,
                      ),
                    ),
                    if (question.hasImage) ...[
                      const SizedBox(height: 8),
                      // The figure IS the question for an ECG or a slide, so
                      // it is drawn here rather than announced by a chip.
                      QuestionImageView(
                          url: question.questionImageUrl!, maxHeight: 220),
                    ],
                  ],
                ),
              ),
              if (!locked) ...[
                _IconAction(Icons.arrow_upward_rounded,
                    canMoveUp ? onMoveUp : null, 'Move up'),
                _IconAction(Icons.arrow_downward_rounded,
                    canMoveDown ? onMoveDown : null, 'Move down'),
                _IconAction(Icons.edit_outlined, onEdit, 'Edit'),
                _IconAction(Icons.delete_outline_rounded, onDelete, 'Delete',
                    danger: true),
              ],
            ],
          ),
          const SizedBox(height: 9),
          for (var i = 0; i < question.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 22),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    i == correct
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked,
                    size: 14,
                    color: i == correct ? LmsColors.success : LmsColors.textGrey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          question.options[i].text.trim().isEmpty
                              ? '${String.fromCharCode(65 + i)}. (image only)'
                              : '${String.fromCharCode(65 + i)}. '
                                  '${question.options[i].text}',
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.3,
                            fontWeight: i == correct
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: i == correct
                                ? LmsColors.success
                                : LmsColors.textDark,
                          ),
                        ),
                        if (question.options[i].hasImage) ...[
                          const SizedBox(height: 6),
                          QuestionImageView(
                              url: question.options[i].imageUrl!,
                              maxHeight: 130),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (correct == null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 22),
              child: Text(
                'correct_option is "${question.correctOption}", which does not '
                'address any of these options.',
                style: const TextStyle(fontSize: 11.5, color: LmsColors.error),
              ),
            ),
          ],
          if (question.subject != null || question.topic != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 22),
              child: Wrap(
                spacing: 6,
                children: [
                  if (question.subject != null)
                    _Chip(Icons.category_outlined, question.subject!),
                  if (question.topic != null)
                    _Chip(Icons.label_outline_rounded, question.topic!),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool danger;

  const _IconAction(this.icon, this.onPressed, this.tooltip,
      {this.danger = false});

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 17),
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        color: danger ? LmsColors.error : LmsColors.textGrey,
      );
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Chip(this.icon, this.label);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: LmsColors.bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: LmsColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: LmsColors.textGrey),
            const SizedBox(width: 5),
            Text(label,
                style:
                    const TextStyle(fontSize: 10.5, color: LmsColors.textGrey)),
          ],
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
