import 'package:flutter/material.dart';

import '../../core/theam/theam_dart.dart';
import '../../models/admin_test_model.dart';
import '../../models/course_types_model.dart';
import '../../services/admin_test_service.dart';

/// Edit an existing test.
///
/// The rule the form enforces before sending: once any student has started,
/// only the name and the instructions can change. Everything else is disabled
/// from [AdminTest.canEditScoring] rather than left enabled to fail — an admin
/// should never fill in a form that is going to 409.
///
/// Instructions stay editable even then. They change nothing already marked,
/// so a typo in the rules of a live paper must be fixable without building a
/// second test.
class EditTestSheet extends StatefulWidget {
  final AdminTest test;
  final List<CourseTypeSummary> courseTypes;

  const EditTestSheet({
    super.key,
    required this.test,
    this.courseTypes = const [],
  });

  @override
  State<EditTestSheet> createState() => _EditTestSheetState();
}

class _EditTestSheetState extends State<EditTestSheet> {
  final _service = AdminTestService();
  final _formKey = GlobalKey<FormState>();

  late final _name = TextEditingController(text: widget.test.title);
  late final _instructions =
      TextEditingController(text: widget.test.instructions ?? '');
  late final _type = TextEditingController(text: widget.test.type ?? '');
  late final _totalQuestions =
      TextEditingController(text: '${widget.test.totalQuestions}');
  late final _marksCorrect =
      TextEditingController(text: '${widget.test.marksCorrect}');
  late final _marksIncorrect =
      TextEditingController(text: '${widget.test.marksIncorrect}');
  late final _duration = TextEditingController(
      text: widget.test.durationMinutes?.toString() ?? '');

  late int? _courseTypeId = widget.test.courseTypeId;

  bool _isBusy = false;
  String? _error;

  bool get _locked => !widget.test.canEditScoring;

  @override
  void dispose() {
    for (final c in [
      _name,
      _instructions,
      _type,
      _totalQuestions,
      _marksCorrect,
      _marksIncorrect,
      _duration,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isBusy = true;
      _error = null;
    });

    final draft = AdminTest(
      id: widget.test.id,
      courseId: widget.test.courseId,
      courseTypeId: _courseTypeId,
      title: _name.text.trim(),
      instructions: _instructions.text.trim(),
      type: _type.text.trim().isEmpty ? null : _type.text.trim(),
      totalQuestions:
          int.tryParse(_totalQuestions.text.trim()) ?? widget.test.totalQuestions,
      questionCount: widget.test.questionCount,
      marksCorrect:
          num.tryParse(_marksCorrect.text.trim()) ?? widget.test.marksCorrect,
      marksIncorrect:
          num.tryParse(_marksIncorrect.text.trim()) ?? widget.test.marksIncorrect,
      durationMinutes: int.tryParse(_duration.text.trim()),
      isPublished: widget.test.isPublished,
      readyToPublish: widget.test.readyToPublish,
      isLocked: widget.test.isLocked,
      attemptCount: widget.test.attemptCount,
    );

    final result = await _service.updateTest(draft);
    if (!mounted) return;

    if (result.isSuccess) {
      // A live paper going dark unnoticed is a support ticket, so the drop to
      // draft is said out loud rather than left to be discovered.
      Navigator.pop(context, result.unpublished ? 'unpublished' : 'saved');
      return;
    }

    setState(() {
      _isBusy = false;
      _error = result.errorMessage;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 700),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Edit test',
                        style: TextStyle(
                            fontSize: 16.5, fontWeight: FontWeight.w800)),
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
                      if (_locked) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: const Color(0xFFB8860B)
                                .withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFFB8860B)
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            '${widget.test.attemptCount} student'
                            '${widget.test.attemptCount == 1 ? ' has' : 's have'} '
                            'already started this test, so only the name and '
                            'the instructions can change. Scoring is stored '
                            'per answer as it is given — editing it now would '
                            'score one attempt two different ways.',
                            style: const TextStyle(
                                fontSize: 12, height: 1.4,
                                color: Color(0xFFB8860B)),
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],

                      if (widget.test.isPublished) ...[
                        const _Hint(
                          'This test is published. Saving any change drops it '
                          'back to draft — students will not see it until you '
                          'publish it again.',
                        ),
                        const SizedBox(height: 16),
                      ],

                      _field(_name, 'Name',
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? 'A name is required'
                              : null),
                      const SizedBox(height: 14),

                      // Always enabled, even on a locked paper.
                      _field(_instructions, 'Instructions for students',
                          maxLines: 4,
                          hint: 'Read every question carefully. No going back.'),
                      const SizedBox(height: 5),
                      const _Hint(
                        'Shown before the timer starts. Editable at any time — '
                        'it changes nothing already marked.',
                      ),
                      const SizedBox(height: 18),

                      _field(_type, 'Test type', enabled: !_locked),
                      const SizedBox(height: 14),

                      _examTypeDropdown(),
                      const SizedBox(height: 14),

                      _field(
                        _totalQuestions,
                        'Total questions',
                        enabled: !_locked,
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (_locked) return null;
                          final n = int.tryParse((v ?? '').trim());
                          if (n == null || n <= 0) {
                            return 'Enter a whole number above 0';
                          }
                          // The server refuses a total below what is already
                          // imported, so it is caught before the request.
                          if (n < widget.test.questionCount) {
                            return 'The paper already holds '
                                '${widget.test.questionCount} questions';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _field(
                              _marksCorrect,
                              'Marks per correct answer',
                              enabled: !_locked,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              validator: (v) {
                                if (_locked) return null;
                                final n = num.tryParse((v ?? '').trim());
                                if (n == null || n <= 0) {
                                  return 'Must be above 0';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _field(
                              _marksIncorrect,
                              'Negative marks (e.g. -0.25)',
                              enabled: !_locked,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true, signed: true),
                              validator: (v) {
                                if (_locked) return null;
                                final n = num.tryParse((v ?? '').trim());
                                if (n == null) return 'Enter a number';
                                if (n > 0) {
                                  return 'Must be 0 or negative — use -0.25, '
                                      'not 0.25';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      _field(_duration, 'Duration in minutes',
                          enabled: !_locked,
                          keyboardType: TextInputType.number),

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
                        : const Text('Save changes',
                            style: TextStyle(
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

  Widget _examTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Exam type',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 7),
        DropdownButtonFormField<int?>(
          initialValue: _courseTypeId,
          isExpanded: true,
          decoration: _decoration(enabled: !_locked),
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('All exam types', style: TextStyle(fontSize: 13)),
            ),
            for (final type in widget.courseTypes)
              DropdownMenuItem<int?>(
                value: type.id,
                child: Text(type.title,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged:
              _locked ? null : (value) => setState(() => _courseTypeId = value),
        ),
      ],
    );
  }

  InputDecoration _decoration({required bool enabled}) => InputDecoration(
        filled: true,
        fillColor: enabled ? LmsColors.bg : const Color(0xFFF0F0F3),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: LmsColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: LmsColors.border),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: LmsColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: LmsColors.primary),
        ),
      );

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    int maxLines = 1,
    bool enabled = true,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: enabled ? LmsColors.textDark : LmsColors.textGrey)),
            if (!enabled) ...[
              const SizedBox(width: 7),
              const Icon(Icons.lock_outline_rounded,
                  size: 13, color: LmsColors.textGrey),
            ],
          ],
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(
              fontSize: 13.5,
              color: enabled ? LmsColors.textDark : LmsColors.textGrey),
          decoration: _decoration(enabled: enabled).copyWith(
            hintText: hint,
            hintStyle:
                const TextStyle(fontSize: 12.5, color: LmsColors.textGrey),
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
