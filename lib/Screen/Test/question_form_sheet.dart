import 'package:flutter/material.dart';

import '../../core/theam/theam_dart.dart';
import '../../models/admin_test_model.dart';
import '../../services/admin_test_service.dart';

/// Add or edit one question.
///
/// Nothing here is marked required. A stem can be an image alone — an ECG is
/// often the whole question — and so can an option, and the CSV importer
/// accepts exactly that. Marking the text fields required would make every
/// image-only question it imported uneditable.
///
/// The real rule is "text or image, never neither", checked per field before
/// the request; the server's 400 is the backstop, not the first line.
class QuestionFormSheet extends StatefulWidget {
  final int testId;
  final TestPreviewQuestion? existing;

  /// Existing section names, offered as suggestions while still accepting a
  /// new one — sections are derived from these labels, not a fixed list.
  final List<String> knownSections;

  /// Where an appended question lands. The server refuses anything above
  /// lastOrder + 1.
  final int nextOrder;

  const QuestionFormSheet({
    super.key,
    required this.testId,
    this.existing,
    this.knownSections = const [],
    required this.nextOrder,
  });

  @override
  State<QuestionFormSheet> createState() => _QuestionFormSheetState();
}

class _QuestionFormSheetState extends State<QuestionFormSheet> {
  final _service = AdminTestService();
  final _formKey = GlobalKey<FormState>();

  late final _questionText = TextEditingController();
  late final _questionImage = TextEditingController();
  late final _explanation = TextEditingController();
  late final _section = TextEditingController();
  late final _subject = TextEditingController();
  late final _topic = TextEditingController();
  late final _order = TextEditingController();

  final _optionText = List.generate(4, (_) => TextEditingController());
  final _optionImage = List.generate(4, (_) => TextEditingController());

  String _correct = 'A';
  bool _isBusy = false;
  String? _error;

  /// Field-level problems from the server's 400, shown under the field named.
  Map<String, String> _problems = const {};

  static const _letters = ['A', 'B', 'C', 'D'];

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final q = widget.existing;
    if (q != null) {
      _questionText.text = q.questionText;
      _questionImage.text = q.questionImageUrl ?? '';
      _explanation.text = q.explanation ?? '';
      _section.text = q.section ?? '';
      _subject.text = q.subject ?? '';
      _topic.text = q.topic ?? '';
      _order.text = q.questionOrder?.toString() ?? '';
      _correct = q.correctOption.trim().toUpperCase().isEmpty
          ? 'A'
          : q.correctOption.trim().toUpperCase();
      for (var i = 0; i < 4 && i < q.options.length; i++) {
        _optionText[i].text = q.options[i].text;
        _optionImage[i].text = q.options[i].imageUrl ?? '';
      }
    } else {
      _order.text = '${widget.nextOrder}';
    }
  }

  @override
  void dispose() {
    for (final c in [
      _questionText,
      _questionImage,
      _explanation,
      _section,
      _subject,
      _topic,
      _order,
      ..._optionText,
      ..._optionImage,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Text or image, never neither.
  String? _missing() {
    if (_questionText.text.trim().isEmpty && _questionImage.text.trim().isEmpty) {
      return 'The question needs text or an image';
    }
    for (var i = 0; i < 4; i++) {
      if (_optionText[i].text.trim().isEmpty &&
          _optionImage[i].text.trim().isEmpty) {
        return 'Option ${_letters[i]} needs text or an image';
      }
    }
    return null;
  }

  /// Empty strings are sent, not dropped: `""` clears a field on the server,
  /// and an admin removing an explanation means to remove it.
  Map<String, dynamic> _payload() {
    final order = int.tryParse(_order.text.trim());

    return {
      'questionText': _questionText.text.trim(),
      'questionImageUrl': _questionImage.text.trim(),
      for (var i = 0; i < 4; i++) ...{
        'option${_letters[i]}': _optionText[i].text.trim(),
        'option${_letters[i]}ImageUrl': _optionImage[i].text.trim(),
      },
      'correctOption': _correct,
      'explanation': _explanation.text.trim(),
      'section': _section.text.trim(),
      'subject': _subject.text.trim(),
      'topic': _topic.text.trim(),
      if (order != null) 'questionOrder': order,
    };
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final missing = _missing();
    if (missing != null) {
      setState(() => _error = missing);
      return;
    }

    setState(() {
      _isBusy = true;
      _error = null;
      _problems = const {};
    });

    final result = _isEdit
        ? await _service.updateQuestion(
            widget.testId, widget.existing!.id, _payload())
        : await _service.createQuestion(widget.testId, _payload());

    if (!mounted) return;

    if (result.isSuccess) {
      Navigator.pop(context, true);
      return;
    }

    setState(() {
      _isBusy = false;
      _error = result.errorMessage;
      _problems = {
        for (final p in result.problems) p.field.toLowerCase(): p.message,
      };
    });
  }

  String? _problemFor(String field) =>
      _problems[field.toLowerCase()] ??
      _problems[field.toLowerCase().replaceAll('_', '')];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _isEdit ? 'Edit question' : 'Add a question',
                      style: const TextStyle(
                          fontSize: 16.5, fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: LmsColors.border),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Hint(
                        'A question or an option can be an image with no text. '
                        'Fill either side — just not neither.',
                      ),
                      const SizedBox(height: 16),

                      _field(_questionText, 'Question',
                          maxLines: 3,
                          errorText: _problemFor('question_text') ??
                              _problemFor('questionText')),
                      const SizedBox(height: 12),
                      _field(_questionImage, 'Question image URL',
                          hint: 'https://...',
                          errorText: _problemFor('question_image_url')),
                      const SizedBox(height: 20),

                      for (var i = 0; i < 4; i++) ...[
                        _optionBlock(i),
                        const SizedBox(height: 14),
                      ],

                      const SizedBox(height: 4),
                      const Text('Correct answer',
                          style: TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final letter in _letters)
                            ChoiceChip(
                              label: Text(letter),
                              selected: _correct == letter,
                              onSelected: (_) =>
                                  setState(() => _correct = letter),
                              selectedColor: LmsColors.primarySoft,
                              labelStyle: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: _correct == letter
                                    ? LmsColors.primary
                                    : LmsColors.textDark,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      _field(_explanation, 'Explanation', maxLines: 2),
                      const SizedBox(height: 14),

                      _sectionField(),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(child: _field(_subject, 'Subject')),
                          const SizedBox(width: 12),
                          Expanded(child: _field(_topic, 'Topic')),
                        ],
                      ),
                      const SizedBox(height: 14),

                      _field(_order, 'Position in the paper',
                          keyboardType: TextInputType.number),
                      const SizedBox(height: 5),
                      _Hint(
                        _isEdit
                            ? 'Changing this swaps places with whatever '
                                'question currently holds that position.'
                            : 'Leave as ${widget.nextOrder} to append. A lower '
                                'number inserts here and shifts the rest down.',
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: LmsColors.errorBg,
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(color: LmsColors.errorBorder),
                          ),
                          child: Text(_error!,
                              style: const TextStyle(
                                  fontSize: 12.5, color: LmsColors.error)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            const Divider(height: 1, color: LmsColors.border),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isBusy ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _isBusy ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: LmsColors.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11)),
                    ),
                    child: _isBusy
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(_isEdit ? 'Save changes' : 'Add question',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionBlock(int i) {
    final letter = _letters[i];
    final problem = _problemFor('option_${letter.toLowerCase()}') ??
        _problemFor('option$letter');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _correct == letter ? LmsColors.primarySoft : LmsColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: problem != null
              ? LmsColors.errorBorder
              : _correct == letter
                  ? LmsColors.primary.withValues(alpha: 0.35)
                  : LmsColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Option $letter',
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w800)),
              if (_correct == letter) ...[
                const SizedBox(width: 8),
                const Icon(Icons.check_circle_rounded,
                    size: 14, color: LmsColors.primary),
              ],
            ],
          ),
          const SizedBox(height: 8),
          _field(_optionText[i], 'Text', dense: true),
          const SizedBox(height: 8),
          _field(_optionImage[i], 'Image URL',
              hint: 'https://...', dense: true, errorText: problem),
        ],
      ),
    );
  }

  Widget _sectionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _field(_section, 'Section', hint: 'Part A'),
        if (widget.knownSections.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final name in widget.knownSections)
                ActionChip(
                  label: Text(name, style: const TextStyle(fontSize: 11.5)),
                  onPressed: () => setState(() => _section.text = name),
                  backgroundColor: LmsColors.bg,
                  side: const BorderSide(color: LmsColors.border),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const _Hint(
            'Sections are just labels on questions — typing a new name creates '
            'that part, and clearing it removes the question from every part.',
          ),
        ],
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    int maxLines = 1,
    bool dense = false,
    String? errorText,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: dense ? 11.5 : 12.5,
                fontWeight: dense ? FontWeight.w600 : FontWeight.w700,
                color: dense ? LmsColors.textGrey : LmsColors.textDark)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(fontSize: 12.5, color: LmsColors.textGrey),
            errorText: errorText,
            filled: true,
            fillColor: Colors.white,
            isDense: dense,
            contentPadding: EdgeInsets.symmetric(
                horizontal: 12, vertical: dense ? 10 : 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: LmsColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: LmsColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: LmsColors.primary),
            ),
          ),
        ),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;
  const _Hint(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            fontSize: 11.5, height: 1.35, color: LmsColors.textGrey),
      );
}
