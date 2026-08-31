import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theam/theam_dart.dart';
import '../../models/admin_test_model.dart';
import '../../models/course_types_model.dart';
import '../../services/admin_test_service.dart';
import '../../widget/shimmer_loading.dart';
import 'test_error_table.dart';

/// The four steps, in the order the API enforces.
enum TestStep { shell, upload, review, publish }

/// Creating a test, as a wizard rather than a form.
///
/// The steps exist because uploading must never publish: a bad CSV import has
/// to be seen by a human before any student can sit the paper. A single form
/// with one submit button would collapse that gap.
///
///   1 shell    POST   /api/admin/courses/:courseId/tests   (courseTypeId in body)
///   2 upload   POST   /api/admin/tests/:id/questions/upload
///   3 review   GET    /api/admin/tests/:id/preview
///   4 publish  POST   /api/admin/tests/:id/publish
class TestWizardScreen extends StatefulWidget {
  final int courseId;
  final String courseTitle;

  /// The exam types on this course, offered in the create form.
  final List<CourseTypeSummary> courseTypes;

  /// Preselected exam type, or null for "All exam types".
  ///
  /// Null is a real scope, not a missing value: the server serves a paper with
  /// no course type to every student on the course. The dropdown says so
  /// explicitly rather than leaving it as the empty default.
  final int? initialCourseTypeId;

  /// Set when re-entering the wizard for a test that already exists, so an
  /// admin can resume at upload or review instead of creating a second shell.
  final AdminTest? existing;
  final TestStep startAt;

  const TestWizardScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
    this.courseTypes = const [],
    this.initialCourseTypeId,
    this.existing,
    this.startAt = TestStep.shell,
  });

  @override
  State<TestWizardScreen> createState() => _TestWizardScreenState();
}

class _TestWizardScreenState extends State<TestWizardScreen> {
  final _service = AdminTestService();
  final _formKey = GlobalKey<FormState>();

  late TestStep _step;
  AdminTest? _test;

  // ── Step 1 fields ────────────────────────────────────────────────
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _totalQuestionsController = TextEditingController();
  final _marksCorrectController = TextEditingController(text: '1');
  final _marksIncorrectController = TextEditingController(text: '0');
  final _durationController = TextEditingController();

  bool _isBusy = false;
  String? _error;

  /// Null means "All exam types" - the whole course sees the paper.
  int? _courseTypeId;


  // ── Step 2 state ─────────────────────────────────────────────────
  String? _pickedFileName;
  int? _pickedRowCount;
  TestUploadResult? _uploadResult;

  // ── Step 3 state ─────────────────────────────────────────────────
  TestPreview? _preview;

  @override
  void initState() {
    super.initState();
    _test = widget.existing;
    _step = widget.startAt;
    _courseTypeId = widget.existing?.courseTypeId ?? widget.initialCourseTypeId;
    if (_step == TestStep.review) _loadPreview();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _totalQuestionsController.dispose();
    _marksCorrectController.dispose();
    _marksIncorrectController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  String get _scopeLabel {
    if (_courseTypeId == null) return 'All exam types';
    for (final t in widget.courseTypes) {
      if (t.id == _courseTypeId) return t.title;
    }
    return _test?.courseTypeTitle ?? 'All exam types';
  }

  String get _scopeAudience => _courseTypeId == null
      ? 'every student on ${widget.courseTitle}'
      : '$_scopeLabel students';

  // ── Step 1 ───────────────────────────────────────────────────────

  Future<void> _createShell() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isBusy = true;
      _error = null;
    });

    final result = await _service.createTest(
      courseId: widget.courseId,
      draft: AdminTest(
        id: 0,
        courseId: widget.courseId,
        courseTypeId: _courseTypeId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        totalQuestions: int.parse(_totalQuestionsController.text.trim()),
        questionCount: 0,
        marksCorrect: num.tryParse(_marksCorrectController.text.trim()) ?? 1,
        marksIncorrect: num.tryParse(_marksIncorrectController.text.trim()) ?? 0,
        durationMinutes: int.tryParse(_durationController.text.trim()),
      ),
    );

    if (!mounted) return;
    setState(() => _isBusy = false);

    if (result.isSuccess && result.test != null) {
      setState(() {
        _test = result.test;
        _step = TestStep.upload;
      });
    } else {
      setState(() => _error = result.errorMessage);
    }
  }

  // ── Step 2 ───────────────────────────────────────────────────────

  Future<void> _pickAndUpload() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      withData: true, // web has no file path to read from
    );
    if (picked == null || picked.files.single.bytes == null) return;

    final bytes = picked.files.single.bytes!;
    final name = picked.files.single.name;

    // Counted locally so a row-count mismatch is caught before a round trip.
    // A quoted question stem may contain newlines, so this is a floor, not a
    // guarantee - the server still has the final say.
    final rows = _countCsvRows(bytes);

    setState(() {
      _pickedFileName = name;
      _pickedRowCount = rows;
      _uploadResult = null;
      _error = null;
    });

    setState(() => _isBusy = true);
    final result = await _service.uploadQuestions(
      testId: _test!.id,
      bytes: bytes,
      filename: name,
    );

    if (!mounted) return;
    setState(() {
      _isBusy = false;
      _uploadResult = result;
      _error = result.isSuccess ? null : result.errorMessage;
    });

    // Upload never publishes - it moves to review, and a human decides.
    //
    // Only a clean import advances on its own. With warnings the admin stays
    // here to read them: auto-advancing past an amber table is the same as
    // not showing it.
    if (result.isSuccess && !result.hasWarnings) {
      await _loadPreview(advance: true);
    }
  }

  /// Physical data lines, excluding the header and blank trailing lines.
  ///
  /// Counts quotes so a comma - or a newline - inside a quoted question stem
  /// doesn't inflate the count. Returns null when the file looks unparseable
  /// rather than guessing, so the server's own check is the one that speaks.
  static int? _countCsvRows(Uint8List bytes) {
    final String text;
    try {
      text = String.fromCharCodes(bytes);
    } catch (_) {
      return null;
    }
    if (text.trim().isEmpty) return null;

    var rows = 0;
    var inQuotes = false;
    var current = StringBuffer();

    void endLine() {
      if (current.toString().trim().isNotEmpty) rows++;
      current = StringBuffer();
    }

    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (char == '"') {
        // A doubled quote inside a quoted field is an escaped quote.
        if (inQuotes && i + 1 < text.length && text[i + 1] == '"') {
          current.write('""');
          i++;
          continue;
        }
        inQuotes = !inQuotes;
        current.write(char);
      } else if ((char == '\n' || char == '\r') && !inQuotes) {
        if (char == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
        endLine();
      } else {
        current.write(char);
      }
    }
    endLine();

    if (rows == 0) return null;
    return rows - 1; // drop the header
  }

  // ── Step 3 ───────────────────────────────────────────────────────

  Future<void> _loadPreview({bool advance = false}) async {
    if (_test == null) return;
    setState(() {
      _isBusy = true;
      if (advance) _step = TestStep.review;
    });

    final result = await _service.preview(_test!.id);
    if (!mounted) return;

    setState(() {
      _isBusy = false;
      if (result.isSuccess) {
        _preview = result.preview;
        if (result.preview?.test != null) _test = result.preview!.test;
      } else {
        _error = result.errorMessage;
      }
    });
  }

  // ── Step 4 ───────────────────────────────────────────────────────

  Future<void> _publish() async {
    setState(() {
      _isBusy = true;
      _error = null;
    });

    final result = await _service.publish(_test!.id);
    if (!mounted) return;

    setState(() {
      _isBusy = false;
      if (result.isSuccess) {
        _test = result.test ?? _test;
        _step = TestStep.publish;
      } else {
        _error = result.errorMessage;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: LmsColors.textDark,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _test?.title.isNotEmpty == true ? _test!.title : 'New test',
              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${widget.courseTitle} › $_scopeLabel',
              style: const TextStyle(fontSize: 11.5, color: LmsColors.textGrey),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          _StepRail(current: _step),
          const SizedBox(height: 24),
          if (_error != null) ...[
            _ErrorBanner(message: _error!),
            const SizedBox(height: 16),
          ],
          switch (_step) {
            TestStep.shell => _shellForm(),
            TestStep.upload => _uploadStep(),
            TestStep.review => _reviewStep(),
            TestStep.publish => _publishedStep(),
          },
        ],
      ),
    );
  }

  // ── Step 1 UI ────────────────────────────────────────────────────

  Widget _shellForm() {
    return Form(
      key: _formKey,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _StepTitle(
              'Create the test',
              'Nothing is visible to students yet. Questions come next, as a '
                  'CSV upload.',
            ),
            const SizedBox(height: 20),

            _field(_titleController, 'Title', hint: 'DHA Mock Paper 1',
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'A title is required' : null),
            const SizedBox(height: 14),
            _field(_descriptionController, 'Description (optional)', maxLines: 2),
            const SizedBox(height: 14),

            _examTypeDropdown(),
            const SizedBox(height: 6),
            _Hint(
              _courseTypeId == null
                  ? 'Every student on ${widget.courseTitle} will see this '
                      'paper, whichever exam type they picked.'
                  : 'Only students whose selected exam type is "$_scopeLabel" '
                      'will see this paper.',
            ),
            const SizedBox(height: 16),

            _field(
              _totalQuestionsController,
              'Total questions',
              hint: '200',
              keyboardType: TextInputType.number,
              validator: (v) {
                final n = int.tryParse((v ?? '').trim());
                if (n == null || n <= 0) return 'Enter a whole number above 0';
                return null;
              },
            ),
            const SizedBox(height: 6),
            // Explained here, before the upload, because it is a contract the
            // CSV must satisfy exactly - not a target to aim at.
            const _Hint(
              'This is a contract, not a target. The CSV must contain exactly '
              'this many question rows to upload, and the test cannot be '
              'published until it holds exactly this many.',
            ),
            const SizedBox(height: 16),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _field(
                    _marksCorrectController,
                    'Marks per correct answer',
                    hint: '1',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      final n = num.tryParse((v ?? '').trim());
                      if (n == null || n <= 0) return 'Must be above 0';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    _marksIncorrectController,
                    'Negative marks (e.g. -0.25)',
                    hint: '-0.25',
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                    // A positive value here would literally reward a wrong
                    // answer, so it is caught before the request.
                    validator: (v) {
                      final n = num.tryParse((v ?? '').trim());
                      if (n == null) return 'Enter a number';
                      if (n > 0) {
                        return 'Must be 0 or negative — use -0.25, not 0.25';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            _field(
              _durationController,
              'Duration in minutes (optional)',
              hint: '180',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),

            _PrimaryButton(
              label: 'Create and continue',
              busy: _isBusy,
              onPressed: _createShell,
            ),
          ],
        ),
      ),
    );
  }

  /// Exam type, with "All exam types" as an explicit option.
  ///
  /// The empty entry is spelled out rather than left as a blank default: null
  /// means the whole course sees the paper, which is a scope an admin should
  /// choose on purpose, not fall into.
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
          decoration: InputDecoration(
            filled: true,
            fillColor: LmsColors.bg,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: const BorderSide(color: LmsColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: const BorderSide(color: LmsColors.border),
            ),
          ),
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('All exam types',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            for (final type in widget.courseTypes)
              DropdownMenuItem<int?>(
                value: type.id,
                child: Text(type.title,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: _test != null
              ? null // the scope is fixed once the shell exists
              : (value) => setState(() => _courseTypeId = value),
        ),
      ],
    );
  }

  // ── Step 2 UI ────────────────────────────────────────────────────

  Widget _uploadStep() {
    final result = _uploadResult;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepTitle(
            'Upload the questions',
            'A CSV with exactly ${_test?.totalQuestions ?? 0} question rows. '
                'Uploading does not publish anything.',
          ),
          const SizedBox(height: 18),

          Row(
            children: [
              _PrimaryButton(
                label: _pickedFileName == null ? 'Choose CSV file' : 'Choose another file',
                busy: _isBusy,
                onPressed: _pickAndUpload,
                icon: Icons.upload_file_rounded,
              ),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: _showTemplate,
                icon: const Icon(Icons.description_outlined, size: 17),
                label: const Text('CSV format'),
              ),
            ],
          ),

          if (_pickedFileName != null) ...[
            const SizedBox(height: 14),
            Text(
              '$_pickedFileName'
              '${_pickedRowCount != null ? ' · $_pickedRowCount question rows' : ''}',
              style: const TextStyle(fontSize: 12.5, color: LmsColors.textGrey),
            ),
          ],

          // A row count that does not match totalQuestions is said out loud
          // but does not block: the server accepts a partial import and gates
          // publishing on readyToPublish instead.
          if (_pickedRowCount != null &&
              _test != null &&
              _pickedRowCount != _test!.totalQuestions) ...[
            const SizedBox(height: 12),
            _UploadBanner(
              color: const Color(0xFFB8860B),
              icon: Icons.info_outline_rounded,
              title: 'This file has $_pickedRowCount of '
                  '${_test!.totalQuestions} questions',
              body: 'It will still import. The test cannot be published until '
                  'it holds all ${_test!.totalQuestions}.',
            ),
          ],

          if (result != null && result.isSuccess) ...[
            const SizedBox(height: 16),
            _UploadBanner(
              color: result.hasWarnings
                  ? const Color(0xFFB8860B)
                  : LmsColors.success,
              icon: result.hasWarnings
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_rounded,
              title: 'Imported ${result.imported} question'
                  '${result.imported == 1 ? '' : 's'}'
                  '${result.hasWarnings ? ', ${result.warnings.length} to check' : ''}',
              // The server's own sentence, not a reworded one.
              body: result.message,
            ),
          ],

          if (result != null && result.issues.isNotEmpty) ...[
            const SizedBox(height: 20),
            TestErrorTable(
              issues: result.issues,
              nothingWasSaved: !result.isSuccess,
            ),
          ],

          if (result != null && result.isSuccess) ...[
            const SizedBox(height: 24),
            _PrimaryButton(
              label: 'Continue to review',
              busy: _isBusy,
              onPressed: () => _loadPreview(advance: true),
            ),
          ],
        ],
      ),
    );
  }

  void _showTemplate() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('CSV format'),
        content: const SingleChildScrollView(
          child: Text(
            'Header row, then one row per question:\n\n'
            'question_text,option_a,option_b,option_c,option_d,'
            'correct_option,explanation\n\n'
            'correct_option must be A, B, C or D.\n\n'
            'Wrap any field containing a comma in double quotes:\n'
            '"A 54-year-old, previously well, presents with...",...\n\n'
            'To include a double quote inside a quoted field, double it: "".',
            style: TextStyle(fontSize: 12.5, height: 1.5, fontFamily: 'monospace'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  // ── Step 3 UI ────────────────────────────────────────────────────

  Widget _reviewStep() {
    final test = _test;
    final questions = _preview?.questions ?? const <TestPreviewQuestion>[];

    if (_isBusy && _preview == null) {
      return const ShimmerListSkeleton(rowCount: 4, padding: EdgeInsets.zero);
    }

    final complete = test != null && test.questionCount == test.totalQuestions;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 860),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepTitle(
            'Review the paper',
            'Exactly what every student will sit. Nothing is visible to them '
                'until you publish.',
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: complete ? LmsColors.primarySoft : LmsColors.errorBg,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: complete ? LmsColors.primary : LmsColors.errorBorder,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  complete ? Icons.task_alt_rounded : Icons.warning_amber_rounded,
                  size: 19,
                  color: complete ? LmsColors.primary : LmsColors.error,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    test == null
                        ? 'Loading...'
                        : complete
                            ? '${test.progressLabel} questions stored. Ready to publish.'
                            : '${test.progressLabel} questions stored. Publishing '
                                'is blocked until the paper is complete.',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: complete ? LmsColors.primary : LmsColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          for (var i = 0; i < questions.length; i++) ...[
            _PreviewCard(question: questions[i], number: i + 1),
            const SizedBox(height: 10),
          ],

          const SizedBox(height: 8),
          Row(
            children: [
              _PrimaryButton(
                label: 'Publish to students',
                busy: _isBusy,
                // readyToPublish is the server's own signal - the button is
                // disabled from it rather than attempting a publish and
                // reading a 409 as "not ready".
                onPressed: (test?.readyToPublish ?? false) ? _publish : null,
                icon: Icons.publish_rounded,
              ),
              const SizedBox(width: 12),
              if (!(test?.readyToPublish ?? false))
                const Expanded(
                  child: Text(
                    'The server has not marked this test ready to publish.',
                    style: TextStyle(fontSize: 12, color: LmsColors.textGrey),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Step 4 UI ────────────────────────────────────────────────────

  Widget _publishedStep() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: LmsColors.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: LmsColors.success.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_rounded,
                    size: 34, color: LmsColors.success),
                const SizedBox(height: 12),
                Text(
                  '"${_test?.title ?? 'Test'}" is published',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_test?.questionCount ?? 0} questions are now live for '
                  '$_scopeAudience.',
                  style: const TextStyle(fontSize: 12.5, height: 1.4,
                      color: LmsColors.textGrey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _PrimaryButton(
            label: 'Done',
            busy: false,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
  }

  // ── Shared bits ──────────────────────────────────────────────────

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(fontSize: 13.5),
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            filled: true,
            fillColor: LmsColors.bg,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: const BorderSide(color: LmsColors.border),
            ),
          ),
        ),
      ],
    );
  }
}

class _StepRail extends StatelessWidget {
  final TestStep current;
  const _StepRail({required this.current});

  static const _labels = ['Create', 'Upload', 'Review', 'Publish'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: i <= current.index ? LmsColors.primary : LmsColors.border,
              ),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i <= current.index ? LmsColors.primary : LmsColors.bg,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: i <= current.index ? LmsColors.primary : LmsColors.border,
                  ),
                ),
                child: i < current.index
                    ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                    : Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: i <= current.index
                              ? Colors.white
                              : LmsColors.textGrey,
                        ),
                      ),
              ),
              const SizedBox(width: 7),
              Text(
                _labels[i],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: i <= current.index ? LmsColors.primary : LmsColors.textGrey,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _StepTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _StepTitle(this.title, this.subtitle);

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 12.5, height: 1.4, color: LmsColors.textGrey)),
        ],
      );
}

class _Hint extends StatelessWidget {
  final String text;
  const _Hint(this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: LmsColors.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: LmsColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded, size: 15, color: LmsColors.textGrey),
            const SizedBox(width: 9),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 11.5, height: 1.4, color: LmsColors.textGrey)),
            ),
          ],
        ),
      );
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: LmsColors.errorBg,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: LmsColors.errorBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded, size: 18, color: LmsColors.error),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: const TextStyle(
                      fontSize: 12.5, height: 1.35, color: LmsColors.error)),
            ),
          ],
        ),
      );
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback? onPressed;
  final IconData? icon;

  const _PrimaryButton({
    required this.label,
    required this.busy,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: LmsColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
      icon: busy
          ? const SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : (icon != null ? Icon(icon, size: 17) : const SizedBox.shrink()),
      label: Text(label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final TestPreviewQuestion question;
  final int number;

  const _PreviewCard({required this.question, required this.number});

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
                      fontSize: 13, fontWeight: FontWeight.w800,
                      color: LmsColors.textGrey)),
              const SizedBox(width: 9),
              Expanded(
                child: Text(question.questionText,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700, height: 1.35)),
              ),
            ],
          ),
          if (question.hasImage) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 22),
              child: _ReviewImage(url: question.questionImageUrl!, label: 'Question'),
            ),
          ],
          const SizedBox(height: 10),
          for (var i = 0; i < question.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 5, left: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        i == correct
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked,
                        size: 15,
                        color: i == correct ? LmsColors.success : LmsColors.textGrey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          // An image-only option has no text, so the letter
                          // still has to identify it on its own.
                          question.options[i].text.trim().isEmpty
                              ? '${String.fromCharCode(65 + i)}.'
                              : '${String.fromCharCode(65 + i)}. '
                                  '${question.options[i].text}',
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.3,
                            fontWeight:
                                i == correct ? FontWeight.w700 : FontWeight.w400,
                            color:
                                i == correct ? LmsColors.success : LmsColors.textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (question.options[i].hasImage)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 23),
                      child: _ReviewImage(
                        url: question.options[i].imageUrl!,
                        label: 'Option ${String.fromCharCode(65 + i)}',
                        maxHeight: 150,
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
          if ((question.explanation ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 9),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(left: 22),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: LmsColors.bg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(question.explanation!,
                  style: const TextStyle(
                      fontSize: 12, height: 1.4, color: LmsColors.textGrey)),
            ),
          ],
        ],
      ),
    );
  }
}

/// An image on the review screen.
///
/// A broken URL is reported rather than hidden: review is the last look before
/// students see the paper, and an option that silently renders as nothing is
/// exactly the defect this step exists to catch.
class _ReviewImage extends StatelessWidget {
  final String url;
  final String label;
  final double maxHeight;

  const _ReviewImage({
    required this.url,
    required this.label,
    this.maxHeight = 220,
  });

  /// SVG is served from the image host, a different origin from this app, and
  /// rendered through flutter_svg, which does not execute script. Both facts
  /// have to stay true - never inline one of these files into the page.
  bool get _isSvg => Uri.tryParse(url)?.path.toLowerCase().endsWith('.svg') ?? false;

  @override
  Widget build(BuildContext context) {
    if (_isSvg) {
      return Align(
        alignment: Alignment.centerLeft,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: 420),
            child: SvgPicture.network(
              url,
              fit: BoxFit.contain,
              placeholderBuilder: (_) => const LmsShimmer(
                child: ShimmerBox(width: 160, height: 90, radius: 9),
              ),
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: 420),
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : SizedBox(
                    height: maxHeight * 0.5,
                    width: 160,
                    child: const LmsShimmer(
                      child: ShimmerBox(width: 160, height: 90, radius: 9),
                    ),
                  ),
            errorBuilder: (_, __, ___) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: LmsColors.error.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: LmsColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.broken_image_outlined,
                      size: 15, color: LmsColors.error),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      '$label image did not load — $url',
                      style: const TextStyle(fontSize: 11.5, color: LmsColors.error),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A one-line outcome banner above the error table.
class _UploadBanner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String? body;

  const _UploadBanner({
    required this.color,
    required this.icon,
    required this.title,
    this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: color)),
                if (body != null && body!.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(body!,
                      style: TextStyle(
                          fontSize: 12.5, height: 1.35, color: color)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
