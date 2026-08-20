import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theam/theam_dart.dart';
import '../../models/question_bank_model.dart';
import '../../provider/question_bank_provider.dart';
import '../../widget/breadcrumb_widget.dart';

/// Minimum and maximum options the backend accepts.
const int kMinOptions = 2;
const int kMaxOptions = 6;

/// Create / edit a question. Same shell as showAddEditLessonSheet, but a far
/// smaller form: no uploads, no video/note/quiz-ref, no plan picker. Pops
/// `true` once the write succeeded so the caller can refresh.
///
/// Spins up its own providers, exactly like the lesson sheet does, so the
/// list screen's filter state and loading spinner are untouched by a save.
Future<bool?> showAddEditQuestionSheet(
  BuildContext context, {
  Question? question,
  int? initialSubjectId,
  int? initialTopicId,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => QuestionUpdateProvider()),
          ChangeNotifierProvider(create: (_) => SubjectTopicProvider()),
        ],
        child: _AddEditQuestionSheet(
          question: question,
          initialSubjectId: initialSubjectId,
          initialTopicId: initialTopicId,
        ),
      );
    },
  );
}

class _AddEditQuestionSheet extends StatefulWidget {
  final Question? question;
  final int? initialSubjectId;
  final int? initialTopicId;

  const _AddEditQuestionSheet({
    this.question,
    this.initialSubjectId,
    this.initialTopicId,
  });

  @override
  State<_AddEditQuestionSheet> createState() => _AddEditQuestionSheetState();
}

/// One option row's editing state. Controllers live here so adding, removing
/// or reordering a row can never shuffle text between the other rows.
class _OptionDraft {
  final int? id;
  final TextEditingController textController;
  final TextEditingController imageUrlController;
  bool isCorrect;

  _OptionDraft({this.id, String text = '', String imageUrl = '', this.isCorrect = false})
      : textController = TextEditingController(text: text),
        imageUrlController = TextEditingController(text: imageUrl);

  void dispose() {
    textController.dispose();
    imageUrlController.dispose();
  }
}

class _AddEditQuestionSheetState extends State<_AddEditQuestionSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _questionTextController;
  late final TextEditingController _questionImageUrlController;
  late final TextEditingController _explanationController;
  late final TextEditingController _marksCorrectController;
  late final TextEditingController _marksIncorrectController;
  final _tagController = TextEditingController();

  int? _subjectId;
  int? _topicId;
  Difficulty _difficulty = Difficulty.medium;
  QuestionStatus _status = QuestionStatus.active;
  final List<String> _tags = [];
  final List<_OptionDraft> _options = [];

  /// The option list isn't a TextFormField, so it can't report through the
  /// form validator - this carries its error instead.
  String? _optionsError;

  bool get _isEditMode => widget.question != null;

  @override
  void initState() {
    super.initState();
    final q = widget.question;

    _questionTextController = TextEditingController(text: q?.questionText ?? '');
    _questionImageUrlController = TextEditingController(text: q?.questionImageUrl ?? '');
    _explanationController = TextEditingController(text: q?.explanation ?? '');
    _marksCorrectController = TextEditingController(text: '${q?.marksCorrect ?? 1}');
    _marksIncorrectController = TextEditingController(text: '${q?.marksIncorrect ?? 0}');

    _subjectId = q?.subjectId ?? widget.initialSubjectId;
    _topicId = q?.topicId ?? widget.initialTopicId;
    _difficulty = q?.difficulty ?? Difficulty.medium;
    _status = q?.status ?? QuestionStatus.active;
    _tags.addAll(q?.tagNames ?? const []);

    if (q != null && q.options.isNotEmpty) {
      _options.addAll(q.options.map((o) => _OptionDraft(
            id: o.id,
            text: o.optionText,
            imageUrl: o.optionImageUrl ?? '',
            isCorrect: o.isCorrect,
          )));
    } else {
      _options.addAll(List.generate(kMinOptions, (_) => _OptionDraft()));
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final taxonomy = context.read<SubjectTopicProvider>();
      taxonomy.loadSubjects();
      if (_subjectId != null) taxonomy.loadTopics(subjectId: _subjectId!);
    });
  }

  @override
  void dispose() {
    _questionTextController.dispose();
    _questionImageUrlController.dispose();
    _explanationController.dispose();
    _marksCorrectController.dispose();
    _marksIncorrectController.dispose();
    _tagController.dispose();
    for (final option in _options) {
      option.dispose();
    }
    super.dispose();
  }

  void _onSubjectChanged(int? subjectId) {
    if (subjectId == null || subjectId == _subjectId) return;
    setState(() {
      _subjectId = subjectId;
      _topicId = null; // topics belong to exactly one subject
    });
    context.read<SubjectTopicProvider>().loadTopics(subjectId: subjectId);
  }

  // ── Options ────────────────────────────────────────────────────────

  void _addOption() {
    if (_options.length >= kMaxOptions) return;
    setState(() {
      _options.add(_OptionDraft());
      _optionsError = null;
    });
  }

  void _removeOption(int index) {
    if (_options.length <= kMinOptions) return;
    setState(() {
      _options.removeAt(index).dispose();
      _optionsError = null;
    });
  }

  /// Radio-style: marking one correct clears the rest, matching the
  /// backend's "exactly one correct option" rule.
  void _markCorrect(int index) {
    setState(() {
      for (int i = 0; i < _options.length; i++) {
        _options[i].isCorrect = i == index;
      }
      _optionsError = null;
    });
  }

  void _reorderOptions(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      _options.insert(newIndex, _options.removeAt(oldIndex));
    });
  }

  /// Checked before the network call, so the backend's rule surfaces as an
  /// inline message rather than a 400 after a round-trip.
  String? _validateOptions() {
    final texts = _options.map((o) => o.textController.text.trim()).toList();
    if (texts.any((t) => t.isEmpty)) {
      return 'Every option needs text, or remove the empty ones.';
    }
    if (texts.length < kMinOptions) return 'A question needs at least $kMinOptions options.';

    final correct = _options.where((o) => o.isCorrect).length;
    if (correct == 0) return 'Mark one option as the correct answer.';
    if (correct > 1) return 'Only one option can be correct.';
    return null;
  }

  // ── Tags ───────────────────────────────────────────────────────────

  void _addTag(String raw) {
    final incoming = raw
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty && !_tags.contains(t));

    if (incoming.isEmpty) {
      _tagController.clear();
      return;
    }
    setState(() => _tags.addAll(incoming));
    _tagController.clear();
  }

  /// A typed comma commits the chip, the same way enter does.
  void _onTagChanged(String value) {
    if (value.endsWith(',')) _addTag(value);
  }

  // ── Save ───────────────────────────────────────────────────────────

  Future<void> _handleSave() async {
    final optionsError = _validateOptions();
    final formValid = _formKey.currentState!.validate();

    if (optionsError != null) setState(() => _optionsError = optionsError);
    if (!formValid || optionsError != null) return;

    final provider = context.read<QuestionUpdateProvider>();

    String? trimmedOrNull(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();

    final draft = Question(
      id: widget.question?.id ?? 0,
      subjectId: _subjectId!,
      topicId: _topicId!,
      questionText: _questionTextController.text.trim(),
      questionImageUrl: trimmedOrNull(_questionImageUrlController),
      difficulty: _difficulty,
      marksCorrect: num.tryParse(_marksCorrectController.text.trim()) ?? 1,
      marksIncorrect: num.tryParse(_marksIncorrectController.text.trim()) ?? 0,
      explanation: trimmedOrNull(_explanationController),
      status: _status,
      tagNames: List.of(_tags),
      options: [
        for (int i = 0; i < _options.length; i++)
          QuestionOption(
            id: _options[i].id,
            optionText: _options[i].textController.text.trim(),
            optionImageUrl: trimmedOrNull(_options[i].imageUrlController),
            isCorrect: _options[i].isCorrect,
            displayOrder: i,
          ),
      ],
    );

    final success = _isEditMode
        ? await provider.updateQuestion(widget.question!.id, draft)
        : await provider.createQuestion(draft);

    if (!mounted) return;
    if (success) Navigator.pop(context, true);
  }

  // ── Styling (reuses LmsColors + the lesson sheet's field decoration) ──

  InputDecoration _inputDecoration(String hint, {IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: LmsColors.textGrey, fontSize: 13.5),
      prefixIcon: icon != null ? Icon(icon, size: 18, color: LmsColors.textGrey) : null,
      filled: true,
      fillColor: LmsColors.bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: LmsColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: LmsColors.primary, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<QuestionUpdateProvider>();
    final taxonomy = context.watch<SubjectTopicProvider>();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        decoration: const BoxDecoration(
          color: LmsColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: LmsColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _isEditMode ? 'Edit Question' : 'Add Question',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: LmsColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                LmsBreadcrumb(path: [
                  'Question Bank',
                  taxonomy.subjectNamesById[_subjectId],
                  taxonomy.topicNamesById[_topicId],
                ]),

                // ── 1. Question ──────────────────────────────────────
                const _SectionHeader('Question', icon: Icons.help_outline_rounded),
                const _FieldLabel('Question text'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _questionTextController,
                  minLines: 2,
                  maxLines: 6,
                  decoration: _inputDecoration('e.g. Which chamber pumps blood to the lungs?'),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Question text is required'
                      : null,
                ),
                const SizedBox(height: 14),
                const _FieldLabel('Image URL (optional)'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _questionImageUrlController,
                  keyboardType: TextInputType.url,
                  decoration: _inputDecoration(
                    'https://example.com/diagram.png',
                    icon: Icons.image_outlined,
                  ),
                  validator: _validateOptionalUrl,
                ),
                const SizedBox(height: 14),
                const _FieldLabel('Subject'),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  initialValue: _subjectId,
                  isExpanded: true,
                  decoration: _inputDecoration('Select a subject', icon: Icons.folder_outlined),
                  items: taxonomy.subjects
                      .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                      .toList(),
                  onChanged: _onSubjectChanged,
                  validator: (value) => value == null ? 'Subject is required' : null,
                ),
                const SizedBox(height: 14),
                const _FieldLabel('Topic'),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  initialValue: _topicId,
                  isExpanded: true,
                  decoration: _inputDecoration(
                    _subjectId == null
                        ? 'Pick a subject first'
                        : taxonomy.isLoading
                            ? 'Loading topics...'
                            : 'Select a topic',
                    icon: Icons.label_outline_rounded,
                  ),
                  items: taxonomy.topics
                      .map((t) => DropdownMenuItem(value: t.id, child: Text(t.name)))
                      .toList(),
                  onChanged:
                      _subjectId == null ? null : (value) => setState(() => _topicId = value),
                  validator: (value) => value == null ? 'Topic is required' : null,
                ),

                // ── 2. Scoring ───────────────────────────────────────
                const _SectionHeader('Scoring', icon: Icons.calculate_outlined),
                const _FieldLabel('Difficulty'),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: Difficulty.values
                      .map((d) => _ChoiceChipTile(
                            label: d.label,
                            isSelected: d == _difficulty,
                            onTap: () => setState(() => _difficulty = d),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel('Marks if correct'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _marksCorrectController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: _inputDecoration('4'),
                            validator: (value) =>
                                num.tryParse(value?.trim() ?? '') == null ? 'Number' : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel('Marks if wrong'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _marksIncorrectController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            decoration: _inputDecoration('-1'),
                            validator: (value) =>
                                num.tryParse(value?.trim() ?? '') == null ? 'Number' : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // ── 3. Options ───────────────────────────────────────
                _SectionHeader(
                  'Options (${_options.length}/$kMaxOptions)',
                  icon: Icons.checklist_rounded,
                  trailing: TextButton.icon(
                    onPressed: _options.length >= kMaxOptions ? null : _addOption,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add option',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ),
                ),
                const Text(
                  'Drag to reorder. Exactly one option must be marked correct.',
                  style: TextStyle(fontSize: 11.5, color: LmsColors.textGrey),
                ),
                const SizedBox(height: 8),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: _options.length,
                  onReorder: _reorderOptions,
                  itemBuilder: (context, index) {
                    final draft = _options[index];
                    return Padding(
                      key: ValueKey(draft),
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _OptionRow(
                        index: index,
                        draft: draft,
                        canRemove: _options.length > kMinOptions,
                        onMarkCorrect: () => _markCorrect(index),
                        onRemove: () => _removeOption(index),
                        textDecoration: _inputDecoration('Option ${index + 1}'),
                        imageDecoration: _inputDecoration(
                          'Option image URL (optional)',
                          icon: Icons.image_outlined,
                        ),
                        validateUrl: _validateOptionalUrl,
                      ),
                    );
                  },
                ),
                if (_optionsError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(_optionsError!,
                        style: const TextStyle(color: LmsColors.error, fontSize: 12.5)),
                  ),

                // ── 4. Metadata ──────────────────────────────────────
                const _SectionHeader('Metadata', icon: Icons.sell_outlined),
                const _FieldLabel('Explanation (optional)'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _explanationController,
                  minLines: 2,
                  maxLines: 5,
                  decoration: _inputDecoration('Shown to the student after they answer'),
                ),
                const SizedBox(height: 14),
                const _FieldLabel('Tags (optional)'),
                const SizedBox(height: 6),
                TextField(
                  controller: _tagController,
                  decoration: _inputDecoration(
                    'Type a tag, then enter or comma',
                    icon: Icons.sell_outlined,
                  ),
                  onChanged: _onTagChanged,
                  onSubmitted: _addTag,
                ),
                if (_tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _tags
                        .map((tag) => Chip(
                              label: Text(tag, style: const TextStyle(fontSize: 12.5)),
                              onDeleted: () => setState(() => _tags.remove(tag)),
                              backgroundColor: LmsColors.bg,
                              side: const BorderSide(color: LmsColors.border),
                            ))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 6),
                const Text(
                  'New tags are created automatically when the question is saved.',
                  style: TextStyle(fontSize: 11.5, color: LmsColors.textGrey),
                ),
                const SizedBox(height: 14),
                const _FieldLabel('Status'),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: QuestionStatus.values
                      .map((s) => _ChoiceChipTile(
                            label: s.label,
                            isSelected: s == _status,
                            onTap: () => setState(() => _status = s),
                          ))
                      .toList(),
                ),

                if (provider.errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    provider.errorMessage!,
                    style: const TextStyle(color: LmsColors.error, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: provider.isUpdating ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LmsColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: provider.isUpdating
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                          )
                        : Text(
                            _isEditMode ? 'Save Changes' : 'Add Question',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Empty is fine; anything typed has to look like a URL, because the backend
/// stores it verbatim and a typo would render as a broken image to students.
String? _validateOptionalUrl(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return null;
  final uri = Uri.tryParse(v);
  if (uri == null || !uri.hasScheme || !uri.hasAuthority) return 'Enter a valid URL';
  return null;
}

class _OptionRow extends StatelessWidget {
  final int index;
  final _OptionDraft draft;
  final bool canRemove;
  final VoidCallback onMarkCorrect;
  final VoidCallback onRemove;
  final InputDecoration textDecoration;
  final InputDecoration imageDecoration;
  final String? Function(String?) validateUrl;

  const _OptionRow({
    required this.index,
    required this.draft,
    required this.canRemove,
    required this.onMarkCorrect,
    required this.onRemove,
    required this.textDecoration,
    required this.imageDecoration,
    required this.validateUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      decoration: BoxDecoration(
        color: draft.isCorrect ? LmsColors.success.withValues(alpha: 0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: draft.isCorrect ? LmsColors.success.withValues(alpha: 0.35) : LmsColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.only(top: 14, left: 4, right: 2),
              child: Icon(Icons.drag_indicator_rounded, size: 18, color: LmsColors.textGrey),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Radio<bool>(
              value: true,
              groupValue: draft.isCorrect,
              onChanged: (_) => onMarkCorrect(),
              activeColor: LmsColors.success,
            ),
          ),
          Expanded(
            child: Column(
              children: [
                TextFormField(controller: draft.textController, decoration: textDecoration),
                const SizedBox(height: 8),
                TextFormField(
                  controller: draft.imageUrlController,
                  keyboardType: TextInputType.url,
                  style: const TextStyle(fontSize: 12.5),
                  decoration: imageDecoration,
                  validator: validateUrl,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: canRemove ? onRemove : null,
            icon: const Icon(Icons.close_rounded, size: 18),
            color: LmsColors.textGrey,
            tooltip: canRemove
                ? 'Remove option'
                : 'A question needs at least $kMinOptions options',
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;

  const _SectionHeader(this.title, {required this.icon, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: LmsColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: LmsColors.textDark,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _ChoiceChipTile extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChoiceChipTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: LmsColors.primarySoft,
      backgroundColor: LmsColors.bg,
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: isSelected ? LmsColors.primary : LmsColors.textDark,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isSelected ? LmsColors.primary : LmsColors.border),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: LmsColors.textGrey,
      ),
    );
  }
}
