import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theam/theam_dart.dart';
import '../../models/admin_test_model.dart';
import '../../models/course_types_model.dart';
import '../../services/admin_test_service.dart';
import '../../services/csv_image_links.dart';
import '../../services/file_download.dart';
import '../../services/question_image_service.dart';
import '../../services/pdf_text.dart';
import '../../widget/question_image_view.dart';
import '../../widget/shimmer_loading.dart';
import 'test_error_table.dart';

/// The four steps, in the order the API enforces.
/// Details -> CSV -> Review -> Publish.
///
/// Images are not uploaded here. A CSV row carries an image URL, not a file,
/// so a question's picture is referenced by an address the admin already has
/// - there is nothing for the wizard to do with a file.
enum TestStep { shell, upload, review, publish }

/// Creating a test, as a wizard rather than a form.
///
/// The steps exist because uploading must never publish: a bad CSV import has
/// to be seen by a human before any student can sit the paper. A single form
/// with one submit button would collapse that gap.
///
///   1 details  POST   /api/admin/courses/:courseId/tests   (courseTypeId in body)
///   2 upload   POST   /api/admin/tests/:id/questions/upload
///   3 review   GET    /api/admin/tests/:id/preview
///   4 publish  POST   /api/admin/tests/:id/publish
class TestWizardScreen extends StatefulWidget {
  final int courseId;
  final String courseTitle;

  /// The exam types on this course, offered in the create form.
  final List<CourseTypeSummary> courseTypes;

  /// The exam type this paper is being written for.
  ///
  /// Required. A test belongs to an exam - DHA and MOHAP are different papers
  /// - so a course-wide test would serve a DHA candidate the MOHAP paper. The
  /// server still accepts a null scope for older rows; new ones never use it.
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
  final _imageService = QuestionImageService();
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
  final _instructionsController = TextEditingController();

  bool _isBusy = false;
  String? _error;

  /// Null means "All exam types" - the whole course sees the paper.
  int? _courseTypeId;


  // ── Step 2 state ─────────────────────────────────────────────────
  String? _pickedFileName;
  int? _pickedRowCount;
  TestUploadResult? _uploadResult;

  /// Kept so the file can be re-sent with a different flag without making the
  /// admin find it in the file dialog again.
  Uint8List? _pickedBytes;

  /// `?allowMissingImages=true`. Off by default - see the service.
  bool _allowMissingImages = false;

  /// Uploaded pictures: filename in lower case -> the address it now lives at.
  ///
  /// A paper names its images (`q18_rhabdomyolysis.png`); the importer wants an
  /// address. Holding the mapping here lets the CSV keep the names it was
  /// written with - see [linkCsvImages].
  final Map<String, String> _questionImages = {};
  bool _uploadingImages = false;

  /// Names the picked file asks for that nothing has been uploaded under.
  List<String> _missingImages = const [];

  // ── Step 3 state ─────────────────────────────────────────────────
  TestPreview? _preview;

  @override
  void initState() {
    super.initState();
    _test = widget.existing;
    _step = widget.startAt;
    _courseTypeId = widget.existing?.courseTypeId ?? widget.initialCourseTypeId;

    final existing = widget.existing;
    if (existing != null) {
      _titleController.text = existing.title;
      _descriptionController.text = existing.description ?? '';
      _instructionsController.text = existing.instructions ?? '';
      _totalQuestionsController.text = '${existing.totalQuestions}';
      _marksCorrectController.text = '${existing.marksCorrect}';
      _marksIncorrectController.text = '${existing.marksIncorrect}';
      _durationController.text = existing.durationMinutes?.toString() ?? '';
    }
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
    _instructionsController.dispose();
    super.dispose();
  }

  String get _scopeLabel {
    if (_courseTypeId == null) return 'No exam type';
    for (final t in widget.courseTypes) {
      if (t.id == _courseTypeId) return t.title;
    }
    return _test?.courseTypeTitle ?? 'All exam types';
  }

  String get _scopeAudience => '$_scopeLabel students';

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
        instructions: _instructionsController.text.trim(),
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

  /// Fills the instructions from an instruction sheet, as text.
  ///
  /// The server stores instructions as text, so the PDF is read rather than
  /// attached: what it found lands in the field, where the admin can correct
  /// it. Nothing about the paper has to be retyped, and nothing new has to be
  /// hosted or kept in sync.
  Future<void> _instructionsFromPdf() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );
    if (picked == null || picked.files.single.bytes == null) return;

    try {
      final text = _tidyPdfText(extractPdfText(picked.files.single.bytes!));
      if (!mounted) return;
      setState(() {
        _instructionsController.text = text;
        _error = null;
      });
    } on PdfTextException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'That PDF could not be read: $e');
    }
  }

  /// PDF text carries the page's own line breaks. A blank line is a real
  /// paragraph; a break mid-sentence is just where the column ended.
  static String _tidyPdfText(String raw) => raw
      .replaceAll('\r\n', '\n')
      .split(RegExp(r'\n{2,}'))
      .map((p) =>
          p.replaceAll('\n', ' ').replaceAll(RegExp(r'[ \t]+'), ' ').trim())
      .where((p) => p.isNotEmpty)
      .join('\n\n');

  // ── Step 2 ───────────────────────────────────────────────────────

  Future<void> _pickAndUpload() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      withData: true, // web has no file path to read from
    );
    final file = picked?.files.single;
    if (file == null || file.bytes == null) return;

    setState(() {
      _pickedFileName = file.name;
      _pickedBytes = file.bytes;
      // Counted locally so a row-count mismatch is caught before a round
      // trip. A quoted question stem may contain newlines, so this is a
      // floor, not a guarantee - the server still has the final say.
      _pickedRowCount = _countCsvRows(file.bytes!);
      _uploadResult = null;
      _error = null;
    });

    await _sendPickedFile();
  }

  /// Uploads the pictures the question file names.
  ///
  /// One request per file - that is what the endpoint takes - so a file that
  /// is refused (over 2MB, or a format the server will not store) is reported
  /// by name while the rest still land.
  Future<void> _pickImages() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: QuestionImageService.allowedExtensions,
      allowMultiple: true,
      withData: true,
    );
    if (picked == null) return;

    setState(() {
      _uploadingImages = true;
      _error = null;
    });

    final refused = <String>[];
    for (final file in picked.files) {
      final bytes = file.bytes;
      if (bytes == null) continue;
      final result =
          await _imageService.upload(bytes: bytes, filename: file.name);
      if (result.isSuccess) {
        _questionImages[file.name.toLowerCase()] = result.image!.url;
      } else {
        refused.add('${file.name} - ${result.errorMessage}');
      }
    }

    if (!mounted) return;
    setState(() {
      _uploadingImages = false;
      _error = refused.isEmpty ? null : refused.join('\n');
      // Whatever was missing was measured against a smaller set of images.
      _missingImages = const [];
    });

    // A refused upload saved nothing, and adding images at that point is an
    // answer to it - so send the file again rather than leaving a red table on
    // screen that is already out of date. A send that succeeded is left alone:
    // repeating it would import the paper twice.
    final sent = _uploadResult;
    if (_pickedBytes != null && (sent == null || !sent.isSuccess)) {
      await _sendPickedFile();
    }
  }

  /// Uploads whatever is already picked. Separate from picking so the same
  /// file can be retried with [_allowMissingImages] flipped, or after more
  /// images have gone up.
  Future<void> _sendPickedFile() async {
    final bytes = _pickedBytes;
    final name = _pickedFileName;
    if (bytes == null || name == null || _test == null) return;

    // The names in the file are swapped for addresses on the way out, so the
    // sheet an admin wrote never has to carry a Cloudinary URL.
    final linked =
        linkCsvImages(utf8.decode(bytes, allowMalformed: true), _questionImages);

    setState(() {
      _isBusy = true;
      _missingImages = linked.missing;
    });
    final result = await _service.uploadQuestions(
      testId: _test!.id,
      bytes: linked.linked == 0
          ? bytes
          : Uint8List.fromList(utf8.encode(linked.csv)),
      filename: name,
      allowMissingImages: _allowMissingImages,
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

  /// Changes the paper's declared length to match the file that was picked.
  ///
  /// Only offered while `canEditScoring` - the server freezes the count once a
  /// student has started, and a button that always 409s is worse than none.
  Future<void> _setTotalQuestions(int total) async {
    if (_test == null) return;
    setState(() => _isBusy = true);
    final result = await _service.setTotalQuestions(_test!.id, total);
    if (!mounted) return;

    setState(() {
      _isBusy = false;
      _test = result.test ?? _test;
      _error = result.isSuccess ? null : result.errorMessage;
    });

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.unpublished
            // Editing a published test drops it to draft. Silent, and the
            // admin finds out when a student cannot see the paper.
            ? 'The test now expects $total questions, and has gone back to '
                'draft.'
            : 'The test now expects $total questions.'),
      ));
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

            // Always editable, even on a locked paper: it changes nothing
            // already marked.
            _field(_instructionsController, 'Instructions for students (optional)',
                hint: 'Read every question carefully. No going back.',
                maxLines: 3),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _isBusy ? null : _instructionsFromPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 17),
                label: const Text('Load from a PDF',
                    style: TextStyle(fontSize: 12.5)),
              ),
            ),
            const SizedBox(height: 14),

            _examTypeDropdown(),
            const SizedBox(height: 6),
            _Hint(
              _courseTypeId == null
                  ? 'Pick the exam this paper is for. Only students who chose '
                      'that exam will see it.'
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

  /// Exam type. Required - there is no "whole course" option.
  ///
  /// A paper is written for one exam. Offering a course-wide scope invites the
  /// mistake it was added to prevent: a DHA candidate served the MOHAP paper.
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
          validator: (value) =>
              value == null ? 'Choose the exam this paper is for' : null,
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

  // ── Step 3 UI ────────────────────────────────────────────────────

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

          // Off by default, and stated as a consequence rather than a setting:
          // a question whose diagram is missing is a broken question, so this
          // has to read like a decision, not a convenience.
          _AllowMissingImagesBox(
            value: _allowMissingImages,
            enabled: !_isBusy,
            onChanged: (v) => setState(() => _allowMissingImages = v),
          ),
          const SizedBox(height: 12),

          // Pictures go up before the file that names them. The importer
          // resolves an image cell to something it can serve, and a name it
          // has never seen fails the whole row.
          _QuestionImagesBox(
            uploaded: _questionImages.length,
            busy: _uploadingImages,
            onPick: _isBusy || _uploadingImages ? null : _pickImages,
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              _PrimaryButton(
                label: _pickedFileName == null
                    ? 'Choose CSV file'
                    : 'Choose another file',
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
              TextButton.icon(
                onPressed: _downloadTemplate,
                icon: const Icon(Icons.download_outlined, size: 17),
                label: const Text('Download template'),
              ),
            ],
          ),

          if (_pickedFileName != null) ...[
            const SizedBox(height: 14),
            Text(
              '$_pickedFileName'
              '${_pickedRowCount != null ? ' · $_pickedRowCount question rows' : ''}'
              '${_questionImages.isNotEmpty ? ' · ${_questionImages.length} image'
                  '${_questionImages.length == 1 ? '' : 's'} uploaded' : ''}',
              style: const TextStyle(fontSize: 12.5, color: LmsColors.textGrey),
            ),
          ],

          // Said here because the server's version of it is one row-level
          // error per picture, buried in a table of 150.
          if (_missingImages.isNotEmpty) ...[
            const SizedBox(height: 12),
            _UploadBanner(
              color: const Color(0xFFB8860B),
              icon: Icons.image_not_supported_outlined,
              title: '${_missingImages.length} image'
                  '${_missingImages.length == 1 ? ' is' : 's are'} named in the '
                  'file but not uploaded',
              body: '${_missingImages.take(8).join(', ')}'
                  '${_missingImages.length > 8 ? ', and ${_missingImages.length - 8} more' : ''}. '
                  'Add them above and send the file again, or tick "Import now, '
                  'add images later" to bring those rows in without a picture.',
              action: _BannerButton(
                label: 'Add images',
                busy: _uploadingImages,
                onPressed: _pickImages,
              ),
            ),
          ],

          // A row count that does not match totalQuestions is said out loud
          // but does not block: the server accepts a partial import and gates
          // publishing on readyToPublish instead.
          //
          // The fix is offered here because the mismatch is usually the test's
          // number being wrong, not the file - and hunting for the edit form
          // to change one integer is the slowest possible way to say so.
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
              action: _test!.canEditScoring
                  ? _BannerButton(
                      label: 'Make this test $_pickedRowCount questions',
                      busy: _isBusy,
                      onPressed: () => _setTotalQuestions(_pickedRowCount!),
                    )
                  // Scoring is frozen once anyone has sat the paper, so the
                  // only way out is the file.
                  : null,
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

          // Offered only after images are what actually blocked, never before:
          // until then it is a setting nobody needs to think about.
          if (!_allowMissingImages &&
              result != null &&
              result.blocking.any((i) => i.field.toLowerCase().contains('image'))) ...[
            const SizedBox(height: 14),
            _BannerButton(
              label: 'Import anyway, without those images',
              busy: _isBusy,
              onPressed: () {
                setState(() => _allowMissingImages = true);
                _sendPickedFile();
              },
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

  /// The columns the importer reads, as the row the template carries.
  ///
  /// Headers only when downloaded: a template with sample rows in it comes
  /// back uploaded with the samples still there.
  static const _templateHeader =
      'question_order,question_text,question_image_filename,'
      'option_a,option_b,option_c,option_d,option_e,option_f,'
      'correct_option,explanation,subject,topic';

  void _downloadTemplate() =>
      downloadTextFile('test_questions_template.csv', '$_templateHeader\n');

  void _showTemplate() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('CSV format'),
        content: const SingleChildScrollView(
          child: Text(
            'Header row, then one row per question:\n\n'
            '$_templateHeader\n\n'
            '"Download template" saves exactly that row as an empty file to '
            'fill in.\n\n'
            'OPTIONS. Four to six, and it is per question - a paper may mix '
            'them. option_a to option_d are required on every row. option_e '
            'and option_f are for the questions that carry five or six '
            'answers; leave them blank on the rest. Fewer than four is '
            'refused.\n\n'
            'correct_option is the answer\'s letter, A to F, and it has to '
            'point at an option that is filled in. option_f filled with '
            'option_e blank is also refused: the letters would close up and '
            'the answer key would address the wrong option.\n\n'
            'question_order is the question number on the paper.\n\n'
            'subject and topic group a question, the same way your own import '
            'sheets do. Optional. A section column is read too, for a paper '
            'split into named parts.\n\n'
            'IMAGES. Upload the pictures with "Add images" first, then name '
            'them in the file exactly as the files are named. They are swapped '
            'for their addresses as the file is sent.\n\n'
            'question_image_filename takes either form below, and '
            'question_image_url is the same column under another name '
            '(case-insensitive). Both apply to option_a_image_url through '
            'option_f_image_url too.\n\n'
            'https://res.cloudinary.com/.../ecg.svg\n'
            '    A full address. Always works, from any host.\n\n'
            'ecg.svg\n'
            '    A file name. Works only if an image of that name was '
            'uploaded to THIS test; otherwise the file is refused.\n\n'
            'If you have no uploaded images, use full https:// links, or tick '
            '"Import now, add images later" to bring those rows in without '
            'their pictures.\n\n'
            'A question can be an image with no text, and so can an option. '
            'Leave question_text blank and fill question_image_filename. Only '
            'a row with neither is an error.\n\n'
            'Wrap any field containing a comma in double quotes:\n'
            '"A 54-year-old, previously well, presents with...",...\n\n'
            'To include a double quote inside a quoted field, double it: "".',
            style: TextStyle(fontSize: 12.5, height: 1.5, fontFamily: 'monospace'),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _downloadTemplate,
            icon: const Icon(Icons.download_outlined, size: 17),
            label: const Text('Download template'),
          ),
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
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
              // Always available. Everything up to here is already saved on
              // the server, so the wizard must have an exit that keeps it -
              // otherwise an incomplete paper leaves the admin stuck on a
              // disabled Publish with nowhere to go but the back arrow.
              OutlinedButton.icon(
                onPressed: _isBusy ? null : () => Navigator.pop(context, true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: LmsColors.textDark,
                  side: const BorderSide(color: LmsColors.border),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11)),
                ),
                icon: const Icon(Icons.save_outlined, size: 17),
                label: const Text('Save as draft',
                    style: TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          if (!(test?.readyToPublish ?? false)) ...[
            const SizedBox(height: 10),
            const _Hint(
              'The server has not marked this test ready to publish yet. '
              'Save it as a draft — nothing is lost, and you can publish from '
              'the test list once the paper is complete.',
            ),
          ],
          const SizedBox(height: 18),

          for (var i = 0; i < questions.length; i++) ...[
            _PreviewCard(question: questions[i], number: i + 1),
            const SizedBox(height: 10),
          ],
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

  static const _labels = ['Details', 'CSV', 'Review', 'Publish'];

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
              child: QuestionImageView(url: question.questionImageUrl!),
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
                      child: QuestionImageView(
                        url: question.options[i].imageUrl!,
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
/// A one-line outcome banner above the error table.
/// "Import now, add images later" -> `?allowMissingImages=true`.
///
/// Off by default. Worded as what it costs rather than what it enables: the
/// rows import, but every question that needed a diagram arrives without one.
/// Uploading the pictures a question file names.
///
/// Separate from the file itself because the order matters: an image cell is
/// resolved as the CSV is sent, so anything uploaded afterwards is too late
/// for the rows that asked for it.
class _QuestionImagesBox extends StatelessWidget {
  final int uploaded;
  final bool busy;
  final VoidCallback? onPick;

  const _QuestionImagesBox({
    required this.uploaded,
    required this.busy,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: LmsColors.bg,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: LmsColors.border),
      ),
      child: Row(
        children: [
          Icon(
            uploaded == 0 ? Icons.image_outlined : Icons.image_rounded,
            size: 19,
            color: uploaded == 0 ? LmsColors.textGrey : LmsColors.primary,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Question images',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  uploaded == 0
                      ? 'Upload the pictures your file names - '
                          'q18_rhabdomyolysis.png and the like - before the '
                          'CSV. Rows that carry https:// links need none.'
                      : '$uploaded uploaded. Your file can keep the names it '
                          'was written with; they are swapped for addresses as '
                          'it is sent.',
                  style: const TextStyle(
                      fontSize: 12, height: 1.35, color: LmsColors.textGrey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton.icon(
            onPressed: busy ? null : onPick,
            icon: busy
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_photo_alternate_outlined, size: 18),
            label: Text(busy
                ? 'Uploading...'
                : uploaded == 0
                    ? 'Add images'
                    : 'Add more'),
          ),
        ],
      ),
    );
  }
}

class _AllowMissingImagesBox extends StatelessWidget {
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _AllowMissingImagesBox({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? () => onChanged(!value) : null,
      borderRadius: BorderRadius.circular(11),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: value,
                onChanged: enabled ? (v) => onChanged(v ?? false) : null,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                activeColor: LmsColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Import now, add images later',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    value
                        ? 'Rows whose image cannot be found will import with no '
                            'image, listed as warnings to fix later.'
                        : 'An image the server cannot find stops the whole '
                            'file. Tick this to import those rows without it.',
                    style: const TextStyle(
                        fontSize: 12, height: 1.35, color: LmsColors.textGrey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small filled action that sits inside a banner.
class _BannerButton extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback onPressed;

  const _BannerButton({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: LmsColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label),
    );
  }
}

class _UploadBanner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String? body;

  /// Sits under the text, not beside it - a banner that wraps to two lines
  /// would otherwise squeeze the button to nothing.
  final Widget? action;

  const _UploadBanner({
    required this.color,
    required this.icon,
    required this.title,
    this.body,
    this.action,
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
                if (action != null) ...[
                  const SizedBox(height: 10),
                  action!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

