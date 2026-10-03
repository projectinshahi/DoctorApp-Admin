import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/theam/theam_dart.dart';
import '../../models/admin_test_model.dart';
import '../../services/admin_test_service.dart';
import '../../services/question_image_service.dart';
import '../../widget/question_image_view.dart';

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

/// The option letters a test question can use. A to D are the paper's usual
/// four; E and F are optional, because some questions carry six and dropping
/// them here would delete two answers the CSV imported correctly.
const List<String> questionOptionLetters = ['A', 'B', 'C', 'D', 'E', 'F'];

/// Below this index an option must be filled in.
const int requiredQuestionOptions = 4;

/// How many option rows an existing question opens with: the four required
/// ones, plus however many extras it already carries.
int visibleQuestionOptions(int optionCount) => optionCount
    .clamp(requiredQuestionOptions, questionOptionLetters.length)
    .toInt();

/// Why this set of options cannot be saved, or null when it can.
///
/// [filled] is one flag per letter, in letter order: an option counts as
/// filled when it has text, an image, or both. [visible] is how many rows the
/// admin can see - a row on screen has to be filled, which is also why Save
/// is disabled rather than letting the server explain an empty row.
String? questionOptionProblem(
  List<bool> filled,
  String correct, {
  int visible = requiredQuestionOptions,
}) {
  for (var i = 0; i < visible && i < filled.length; i++) {
    if (!filled[i]) {
      return 'Option ${questionOptionLetters[i]} needs text or an image';
    }
  }

  // No holes: the paper addresses options by letter, so a filled F behind an
  // empty E would renumber every answer under a key written against the
  // original letters.
  for (var i = requiredQuestionOptions; i < filled.length - 1; i++) {
    if (!filled[i] && filled[i + 1]) {
      return 'Option ${questionOptionLetters[i + 1]} is filled but Option '
          '${questionOptionLetters[i]} is empty - fill '
          '${questionOptionLetters[i]}, or move '
          '${questionOptionLetters[i + 1]} into it';
    }
  }

  if (!questionAnswerLetters(filled).contains(correct)) {
    return 'The correct answer is $correct, which is empty';
  }
  return null;
}

/// The letters an answer may point at: only the options that actually hold
/// something. Offering an empty one lets an admin key the answer to a blank.
List<String> questionAnswerLetters(List<bool> filled) => [
      for (var i = 0; i < questionOptionLetters.length; i++)
        if (filled[i]) questionOptionLetters[i],
    ];

class _QuestionFormSheetState extends State<QuestionFormSheet> {
  final _service = AdminTestService();
  final _imageService = QuestionImageService();
  final _formKey = GlobalKey<FormState>();

  late final _questionText = TextEditingController();
  late final _questionImage = TextEditingController();
  late final _explanation = TextEditingController();
  late final _section = TextEditingController();
  late final _subject = TextEditingController();
  late final _topic = TextEditingController();
  late final _order = TextEditingController();

  final _optionText = List.generate(_letters.length, (_) => TextEditingController());
  final _optionImage = List.generate(_letters.length, (_) => TextEditingController());

  String _correct = 'A';
  bool _isBusy = false;
  String? _error;

  /// Field-level problems from the server's 400, shown under the field named.
  Map<String, String> _problems = const {};

  static const _letters = questionOptionLetters;
  static const _requiredOptions = requiredQuestionOptions;

  bool _filled(int i) =>
      _optionText[i].text.trim().isNotEmpty ||
      _optionImage[i].text.trim().isNotEmpty;

  List<bool> get _filledFlags =>
      [for (var i = 0; i < _letters.length; i++) _filled(i)];

  /// Rows on screen. A to D always; E and F arrive through Add option.
  int _visible = requiredQuestionOptions;

  /// A sixth is the ceiling, and the next letter only opens once the one
  /// before it holds something - which is what keeps E from being empty under
  /// a filled F.
  bool get _canAdd => _visible < _letters.length && _filled(_visible - 1);

  bool get _isEdit => widget.existing != null;

  /// Typing anywhere changes what can be saved and which letters the answer
  /// can point at, so the form rebuilds on every keystroke.
  void _refresh(String _) => setState(() {});

  void _addOption() => setState(() => _visible++);

  /// Removing E pulls F up into it rather than leaving a hole, and the answer
  /// follows the letter it was pointing at.
  void _removeOption(int index) {
    setState(() {
      for (var i = index; i < _letters.length - 1; i++) {
        _optionText[i].text = _optionText[i + 1].text;
        _optionImage[i].text = _optionImage[i + 1].text;
      }
      _optionText.last.clear();
      _optionImage.last.clear();
      _visible--;

      final at = _letters.indexOf(_correct);
      if (at == index) {
        _correct = _letters.first; // the answer went with the option
      } else if (at > index) {
        _correct = _letters[at - 1];
      }
    });
  }

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
      for (var i = 0; i < _letters.length && i < q.options.length; i++) {
        _optionText[i].text = q.options[i].text;
        _optionImage[i].text = q.options[i].imageUrl ?? '';
      }
      _visible = visibleQuestionOptions(q.options.length);
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

  /// Picks a picture, uploads it, and drops the address it comes back with
  /// into [controller].
  ///
  /// The field stays an ordinary text field: a picture already hosted
  /// somewhere is still pasted in by hand, and nothing about an imported
  /// question becomes uneditable.
  Future<void> _uploadInto(TextEditingController controller) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: QuestionImageService.allowedExtensions,
      withData: true,
    );
    final file = picked?.files.single;
    if (file == null || file.bytes == null) return;

    setState(() => _isBusy = true);
    final result =
        await _imageService.upload(bytes: file.bytes!, filename: file.name);

    if (!mounted) return;
    setState(() {
      _isBusy = false;
      if (result.isSuccess) {
        controller.text = result.image!.url;
        _error = null;
      } else {
        _error = result.errorMessage;
      }
    });
  }

  /// An image field: the address, a button that uploads one, and the picture.
  ///
  /// The picture is the point. An address says nothing about whether the right
  /// figure is attached - a nephrostomy diagram under a rhabdomyolysis
  /// question reads as correct until someone looks at it.
  Widget _imageField(
    TextEditingController controller,
    String label, {
    bool dense = false,
    String? errorText,
  }) {
    final url = controller.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _field(controller, label,
            hint: 'https://... or upload one',
            dense: dense,
            errorText: errorText,
            suffix: _uploadButton(controller),
            onChanged: _refresh),
        if (url.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: QuestionImageView(
                    url: url, maxHeight: dense ? 120 : 170),
              ),
              IconButton(
                tooltip: 'Remove this image',
                onPressed: _isBusy
                    ? null
                    : () {
                        controller.clear();
                        _refresh('');
                      },
                icon: const Icon(Icons.close_rounded, size: 17),
                color: LmsColors.textGrey,
                splashRadius: 18,
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _uploadButton(TextEditingController controller) => IconButton(
        tooltip: 'Upload an image',
        onPressed: _isBusy ? null : () => _uploadInto(controller),
        icon: const Icon(Icons.add_photo_alternate_outlined, size: 19),
        color: LmsColors.primary,
        splashRadius: 20,
      );

  /// Text or image, never neither.
  String? _missing() {
    if (_questionText.text.trim().isEmpty && _questionImage.text.trim().isEmpty) {
      return 'The question needs text or an image';
    }
    return questionOptionProblem(_filledFlags, _correct, visible: _visible);
  }

  /// Empty strings are sent, not dropped: `""` clears a field on the server,
  /// and an admin removing an explanation means to remove it.
  Map<String, dynamic> _payload() {
    final order = int.tryParse(_order.text.trim());

    return {
      'questionText': _questionText.text.trim(),
      'questionImageUrl': _questionImage.text.trim(),
      // All six are sent, empty included: "" is what clears an option that
      // was there before, and a key left out would leave it in place.
      for (var i = 0; i < _letters.length; i++) ...{
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
                          onChanged: _refresh,
                          errorText: _problemFor('question_text') ??
                              _problemFor('questionText')),
                      const SizedBox(height: 12),
                      _imageField(_questionImage, 'Question image URL',
                          errorText: _problemFor('question_image_url')),
                      const SizedBox(height: 20),

                      const Text('Options  -  tick the correct one',
                          style: TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),

                      RadioGroup<String>(
                        groupValue: _correct,
                        onChanged: (value) =>
                            setState(() => _correct = value ?? _correct),
                        child: Column(
                          children: [
                            for (var i = 0; i < _visible; i++) ...[
                              _optionBlock(i),
                              const SizedBox(height: 14),
                            ],
                          ],
                        ),
                      ),

                      if (_visible < _letters.length)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            // Opens only once the option before it holds
                            // something, so E can never be empty under F.
                            onPressed: _canAdd ? _addOption : null,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: Text(
                              _canAdd
                                  ? 'Add option ${_letters[_visible]}'
                                  : 'Fill option ${_letters[_visible - 1]} to '
                                      'add another',
                              style: const TextStyle(fontSize: 12.5),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),

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
                children: [
                  if (_missing() != null)
                    Expanded(
                      child: Text(
                        _missing()!,
                        style: const TextStyle(
                            fontSize: 12, color: LmsColors.textGrey),
                      ),
                    )
                  else
                    const Spacer(),
                  TextButton(
                    onPressed: _isBusy ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _isBusy || _missing() != null ? null : _save,
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
              // A radio, not a checkbox: a second correct answer has to be
              // impossible to express, not merely rejected on save. An empty
              // option cannot be chosen at all.
              SizedBox(
                width: 28,
                height: 28,
                child: Radio<String>(
                  value: letter,
                  // An empty option cannot be chosen at all.
                  enabled: _filled(i),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 6),
              Text('Option $letter',
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w800)),
              if (i >= _requiredOptions) ...[
                const SizedBox(width: 6),
                const Text('optional',
                    style: TextStyle(fontSize: 11, color: LmsColors.textGrey)),
              ],
              if (_correct == letter) ...[
                const SizedBox(width: 8),
                const Text('correct answer',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: LmsColors.primary)),
              ],
              const Spacer(),
              if (i >= _requiredOptions)
                TextButton.icon(
                  onPressed: () => _removeOption(i),
                  icon: const Icon(Icons.close_rounded, size: 15),
                  label: const Text('Remove',
                      style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                      foregroundColor: LmsColors.textGrey,
                      visualDensity: VisualDensity.compact),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _field(_optionText[i], 'Text', dense: true, onChanged: _refresh),
          const SizedBox(height: 8),
          _imageField(_optionImage[i], 'Image URL',
              dense: true, errorText: problem),
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
    ValueChanged<String>? onChanged,
    Widget? suffix,
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
          onChanged: onChanged,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(fontSize: 12.5, color: LmsColors.textGrey),
            errorText: errorText,
            suffixIcon: suffix,
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
