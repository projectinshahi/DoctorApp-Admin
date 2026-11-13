import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theam/theam_dart.dart';
import '../../models/admin_test_model.dart' show TestUploadIssue;
import '../../models/course_types_model.dart';
import '../../models/question_bank_model.dart';
import '../../models/quiz_model.dart';
import '../../models/sheet_row_model.dart';
import '../../provider/course_get_provider.dart';
import '../../services/course_details_service.dart';
import '../../services/quiz_service.dart';
import '../../services/file_download.dart';
import '../../services/question_bank_service.dart';
import '../../services/sheet_csv_service.dart';
import '../../services/subject_topic_service.dart';
import '../Test/test_error_table.dart';

/// Making a quiz out of a CSV, the way a mock test is made out of one.
///
/// A quiz has no clock - that is what separates it from a test. What it has
/// is a course and an exam it is for, a subject and topic its questions live
/// under, and the questions themselves.
///
/// Three writes, in this order, because each needs the one before it:
///   1. every row becomes a question in the bank   POST /api/questions
///   2. the quiz                                   POST /api/quizzes
///   3. those exact questions pinned to it         PUT  /admin/quizzes/:id/questions
///
/// Step 3 is what makes the quiz serve the file rather than everything that
/// happens to share the topic. The file is read here rather than posted:
/// there is no bulk import route, which is also why a half-finished import
/// leaves the questions it already made.
class QuizImportTab extends StatefulWidget {
  const QuizImportTab({super.key});

  @override
  State<QuizImportTab> createState() => _QuizImportTabState();
}

class _QuizImportTabState extends State<QuizImportTab> {
  final _taxonomy = SubjectTopicService();
  final _questions = QuestionBankService();
  final _quizzes = QuizService();
  final _courseDetails = CourseDetailsService();
  final _csv = SheetCsvService();
  final _titleController = TextEditingController();

  int? _courseId;
  List<CourseTypeSummary> _types = const [];
  int? _courseTypeId;
  bool _loadingTypes = false;

  List<Subject> _subjects = const [];
  List<Topic> _topics = const [];
  int? _subjectId;
  int? _topicId;
  bool _loadingSubjects = false;
  bool _loadingTopics = false;
  String? _taxonomyError;

  String? _fileName;
  List<SheetQuestion> _rows = const [];
  List<TestUploadIssue> _issues = const [];
  String? _fileError;

  /// How many rows have been sent, while sending. Null when idle.
  int? _importedSoFar;

  /// The quiz the import built, once it exists, and whatever stopped it.
  Quiz? _quiz;
  String? _quizError;
  int _created = 0;
  List<TestUploadIssue> _failures = const [];
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<CourseListGetProvider>();
      if (provider.courses.isEmpty) await provider.fetchCourses(limit: 100);
      if (!mounted || _courseId != null) return;
      final first =
          provider.courses.isEmpty ? null : provider.courses.first.id;
      if (first != null) await _selectCourse(first);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  /// The course decides which exams are on offer; the exam is what the quiz
  /// is tagged with, so a student sitting DHA is not shown the MOHAP quiz.
  Future<void> _selectCourse(int courseId) async {
    setState(() {
      _courseId = courseId;
      _courseTypeId = null;
      _types = const [];
      _loadingTypes = true;
    });

    try {
      final response = await _courseDetails.fetchCourseTypes(courseId);
      if (!mounted || _courseId != courseId) return;
      setState(() {
        _loadingTypes = false;
        _types = response.courseTypes;
        _courseTypeId = _types.isEmpty ? null : _types.first.id;
      });
    } catch (e) {
      if (!mounted || _courseId != courseId) return;
      setState(() {
        _loadingTypes = false;
        _taxonomyError = 'Could not load this course\'s exams: $e';
      });
    }
  }

  Future<void> _loadSubjects() async {
    setState(() {
      _loadingSubjects = true;
      _taxonomyError = null;
    });
    final result = await _taxonomy.getSubjects();
    if (!mounted) return;
    setState(() {
      _loadingSubjects = false;
      if (result.isSuccess) {
        _subjects = result.subjects ?? const [];
      } else {
        _taxonomyError = result.errorMessage;
      }
    });
  }

  Future<void> _loadTopics(int subjectId) async {
    setState(() {
      _loadingTopics = true;
      _topics = const [];
      _topicId = null;
      _taxonomyError = null;
    });
    final result = await _taxonomy.getTopics(subjectId: subjectId);
    if (!mounted) return;
    setState(() {
      _loadingTopics = false;
      if (result.isSuccess) {
        _topics = result.topics ?? const [];
      } else {
        _taxonomyError = result.errorMessage;
      }
    });
  }

  // ── The file ─────────────────────────────────────────────────────

  Future<void> _pickFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      withData: true, // web has no path to read from
    );
    final file = picked?.files.single;
    if (file == null || file.bytes == null) return;

    setState(() {
      _fileName = file.name;
      _fileError = null;
      _rows = const [];
      _issues = const [];
      _resetResult();
    });

    try {
      final parsed =
          _csv.parseCsv(utf8.decode(file.bytes!, allowMalformed: true));
      if (!mounted) return;
      setState(() {
        _rows = parsed;
        _issues = validateQuestions(parsed);
      });
    } on SheetCsvException catch (e) {
      if (!mounted) return;
      setState(() => _fileError = e.message);
    }
  }

  void _resetResult() {
    _importedSoFar = null;
    _created = 0;
    _failures = const [];
    _quiz = null;
    _quizError = null;
    _done = false;
  }

  // ── The import ───────────────────────────────────────────────────

  bool get _canImport =>
      _subjectId != null &&
      _topicId != null &&
      _titleController.text.trim().isNotEmpty &&
      _rows.isNotEmpty &&
      !_issues.any((i) => !i.isWarning) &&
      _importedSoFar == null;

  /// What stopped the button being pressable, or null when nothing does.
  String? get _blockedBecause {
    if (_subjectId == null || _topicId == null) {
      return 'Pick a subject and a topic first.';
    }
    if (_titleController.text.trim().isEmpty) {
      return 'Give the quiz a title.';
    }
    if (_rows.isEmpty) return 'Choose a CSV file.';
    return null;
  }

  Future<void> _import() async {
    if (!_canImport) return;
    final subjectId = _subjectId!;
    final topicId = _topicId!;

    setState(() {
      _resetResult();
      _importedSoFar = 0;
    });

    final failures = <TestUploadIssue>[];
    final createdIds = <int>[];

    for (var i = 0; i < _rows.length; i++) {
      final row = _rows[i];
      final result = await _questions.createQuestion(
        questionFrom(row, subjectId: subjectId, topicId: topicId),
      );
      if (!mounted) return;

      final id = result.question?.id;
      if (result.isSuccess && id != null) {
        createdIds.add(id);
      } else {
        failures.add(TestUploadIssue(
          row: row.sourceRow,
          field: 'question_text',
          message: result.errorMessage ?? 'The server refused this row',
        ));
      }

      setState(() {
        _importedSoFar = i + 1;
        _created = createdIds.length;
      });
    }

    if (!mounted) return;
    setState(() => _importedSoFar = null);

    if (createdIds.isNotEmpty) {
      await _buildQuiz(createdIds, subjectId: subjectId, topicId: topicId);
    }

    if (!mounted) return;
    setState(() {
      _failures = failures;
      _done = true;
    });
  }

  /// The quiz over the questions just made, serving those and nothing else.
  ///
  /// Pinning is a second call: a quiz created from a subject and topic alone
  /// is a filter, and would serve every other question that shares them.
  Future<void> _buildQuiz(
    List<int> questionIds, {
    required int subjectId,
    required int topicId,
  }) async {
    final exam = _types.where((t) => t.id == _courseTypeId).firstOrNull;

    final created = await _quizzes.create(Quiz(
      id: 0,
      title: _titleController.text.trim(),
      subjectId: subjectId,
      topicId: topicId,
      examTag: exam?.title,
      // Left to the server: a pinned quiz serves what it is given.
      questionCount: null,
    ));
    if (!mounted) return;

    final quiz = created.quiz;
    if (!created.isSuccess || quiz == null) {
      setState(() => _quizError =
          created.errorMessage ?? 'The questions were saved, but the quiz '
              'could not be created');
      return;
    }

    final pinned = await _quizzes.setQuestionSet(
      quizId: quiz.id,
      questionIds: questionIds,
    );
    if (!mounted) return;

    setState(() {
      _quiz = quiz;
      _quizError = pinned.isSuccess
          ? null
          : pinned.errorMessage ??
              'The quiz was created, but its questions could not be pinned';
    });
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add a quiz from a CSV',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text(
            'The rows become questions in the bank, and the quiz serves '
            'exactly those. A quiz is untimed - students take it at their own '
            'pace. A paper with a clock on it is a test, not a quiz.',
            style: TextStyle(
                fontSize: 12.5, height: 1.4, color: LmsColors.textGrey),
          ),
          const SizedBox(height: 18),

          _card(
            step: '1',
            title: 'Which course and exam',
            child: _coursePickers(),
          ),
          const SizedBox(height: 12),

          _card(
            step: '2',
            title: 'Where the questions belong',
            child: _scopePickers(),
          ),
          const SizedBox(height: 12),

          _card(
            step: '3',
            title: 'The quiz',
            child: _quizDetails(),
          ),
          const SizedBox(height: 12),

          _card(
            step: '4',
            title: 'The file',
            child: _filePicker(),
          ),

          if (_rows.isNotEmpty || _fileError != null) ...[
            const SizedBox(height: 12),
            _card(step: '5', title: 'What the file says', child: _review()),
          ],

          if (_done) ...[
            const SizedBox(height: 12),
            _card(step: '6', title: 'Result', child: _result()),
          ],
        ],
      ),
    );
  }

  Widget _card({
    required String step,
    required String title,
    required Widget child,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          color: LmsColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: LmsColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                      color: LmsColors.primary, shape: BoxShape.circle),
                  child: Text(step,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ),
                const SizedBox(width: 9),
                Text(title,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );

  Widget _coursePickers() {
    final courses = context.watch<CourseListGetProvider>().courses;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 420,
          child: DropdownButtonFormField<int>(
            initialValue: _courseId,
            isExpanded: true,
            decoration: _fieldDecoration('Course'),
            items: [
              for (final course in courses)
                DropdownMenuItem(value: course.id, child: Text(course.title)),
            ],
            onChanged: _importedSoFar != null
                ? null
                : (value) {
                    if (value != null) _selectCourse(value);
                  },
          ),
        ),
        const SizedBox(height: 10),
        if (_loadingTypes)
          const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2))
        else if (_types.isEmpty)
          const Text('This course has no exams yet. The quiz will not be '
              'tagged with one.',
              style: TextStyle(fontSize: 12, color: LmsColors.textGrey))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in _types)
                ChoiceChip(
                  label: Text(type.title),
                  selected: type.id == _courseTypeId,
                  onSelected: _importedSoFar != null
                      ? null
                      : (_) => setState(() => _courseTypeId = type.id),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: type.id == _courseTypeId
                        ? Colors.white
                        : LmsColors.textDark,
                  ),
                  selectedColor: LmsColors.primary,
                  backgroundColor: LmsColors.bg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                        color: type.id == _courseTypeId
                            ? Colors.transparent
                            : LmsColors.border),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _quizDetails() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 420,
            child: TextField(
              controller: _titleController,
              enabled: _importedSoFar == null,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 13.5),
              decoration:
                  _fieldDecoration('Quiz title, as students see it'),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'No duration: a quiz is not timed. Set a time limit by making a '
            'test instead.',
            style: TextStyle(fontSize: 12, color: LmsColors.textGrey),
          ),
        ],
      );

  Widget _scopePickers() {
    if (_loadingSubjects) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<int>(
                initialValue: _subjectId,
                isExpanded: true,
                decoration: _fieldDecoration('Subject'),
                items: [
                  for (final subject in _subjects)
                    DropdownMenuItem(
                        value: subject.id, child: Text(subject.name)),
                ],
                onChanged: _importedSoFar != null
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _subjectId = value);
                        _loadTopics(value);
                      },
              ),
            ),
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<int>(
                initialValue: _topicId,
                isExpanded: true,
                decoration: _fieldDecoration(_loadingTopics
                    ? 'Loading topics…'
                    : _subjectId == null
                        ? 'Topic — pick a subject first'
                        : 'Topic'),
                items: [
                  for (final topic in _topics)
                    DropdownMenuItem(value: topic.id, child: Text(topic.name)),
                ],
                onChanged: _topics.isEmpty || _importedSoFar != null
                    ? null
                    : (value) => setState(() => _topicId = value),
              ),
            ),
          ],
        ),
        if (_taxonomyError != null) ...[
          const SizedBox(height: 8),
          Text(_taxonomyError!,
              style: const TextStyle(fontSize: 12, color: LmsColors.error)),
        ],
        if (!_loadingTopics && _subjectId != null && _topics.isEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            'This subject has no topics yet. Add one before importing — a '
            'bank question has to sit under a topic.',
            style: TextStyle(fontSize: 12, color: LmsColors.textGrey),
          ),
        ],
      ],
    );
  }

  Widget _filePicker() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _importedSoFar != null ? null : _pickFile,
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: Text(_fileName == null ? 'Choose CSV file' : 'Replace file'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: LmsColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _downloadTemplate,
                icon: const Icon(Icons.download_rounded, size: 17),
                label: const Text('Download template'),
              ),
              TextButton.icon(
                onPressed: _showFormat,
                icon: const Icon(Icons.help_outline_rounded, size: 17),
                label: const Text('CSV format'),
              ),
            ],
          ),
          if (_fileName != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.description_outlined,
                    size: 16, color: LmsColors.textGrey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$_fileName — ${_rows.length} question'
                    '${_rows.length == 1 ? '' : 's'} read',
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ],
      );

  Widget _review() {
    if (_fileError != null) {
      return Text(_fileError!,
          style: const TextStyle(fontSize: 12.5, color: LmsColors.error));
    }

    final blocking = _issues.where((i) => !i.isWarning).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_issues.isNotEmpty) ...[
          TestErrorTable(issues: _issues, nothingWasSaved: blocking > 0),
          const SizedBox(height: 12),
        ],
        ..._rows.take(5).map(_previewRow),
        if (_rows.length > 5) ...[
          const SizedBox(height: 6),
          Text('…and ${_rows.length - 5} more',
              style:
                  const TextStyle(fontSize: 12, color: LmsColors.textGrey)),
        ],
        const SizedBox(height: 14),
        if (_importedSoFar != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                value: _rows.isEmpty ? null : _importedSoFar! / _rows.length,
                minHeight: 6,
              ),
              const SizedBox(height: 8),
              Text('Adding question $_importedSoFar of ${_rows.length} — '
                  'keep this tab open',
                  style: const TextStyle(
                      fontSize: 12, color: LmsColors.textGrey)),
            ],
          )
        else
          ElevatedButton.icon(
            onPressed: _canImport ? _import : null,
            icon: const Icon(Icons.playlist_add_rounded, size: 18),
            label: Text('Create the quiz from ${_rows.length} question'
                '${_rows.length == 1 ? '' : 's'}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: LmsColors.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        if (_importedSoFar == null && blocking == 0 && _blockedBecause != null) ...[
          const SizedBox(height: 8),
          Text(_blockedBecause!,
              style: const TextStyle(
                  fontSize: 12, color: LmsColors.textGrey)),
        ],
      ],
    );
  }

  Widget _previewRow(SheetQuestion question) {
    final answer = question.correctOption >= 1 &&
            question.correctOption <= question.options.length
        ? question.options[question.correctOption - 1]
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 34,
            child: Text('L${question.sourceRow}',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: LmsColors.textGrey)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(question.questionText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '${question.options.length} options'
                  '${answer == null ? '' : ' · answer: $answer'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11.5, color: LmsColors.textGrey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _result() {
    final failed = _failures.length;
    final ok = failed == 0 && _quiz != null && _quizError == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
                ok
                    ? Icons.check_circle_rounded
                    : Icons.error_outline_rounded,
                size: 18,
                color: ok ? LmsColors.success : LmsColors.error),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                _quiz == null
                    ? '$_created question${_created == 1 ? '' : 's'} added, no '
                        'quiz made'
                    : '"${_quiz!.title}" serves $_created question'
                        '${_created == 1 ? '' : 's'}'
                        '${failed == 0 ? '' : ', $failed refused'}',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        if (_quizError != null) ...[
          const SizedBox(height: 8),
          Text(_quizError!,
              style: const TextStyle(fontSize: 12.5, color: LmsColors.error)),
        ],
        if (failed > 0) ...[
          const SizedBox(height: 10),
          // The rows that did go in are already saved: this import cannot be
          // undone in one click, so the refused lines are named instead.
          const Text(
            'The added questions are saved. Fix these lines in the file and '
            'upload just those rows again.',
            style: TextStyle(fontSize: 12, color: LmsColors.textGrey),
          ),
          const SizedBox(height: 10),
          TestErrorTable(issues: _failures, nothingWasSaved: false),
        ],
      ],
    );
  }

  InputDecoration _fieldDecoration(String label) => InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: LmsColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: LmsColors.border),
        ),
      );

  void _downloadTemplate() =>
      downloadTextFile('question_bank_template.csv', '$kQuestionCsvHeader\n');

  void _showFormat() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('CSV format'),
        content: const SingleChildScrollView(
          child: Text(
            'Header row, then one row per question:\n\n'
            '$kQuestionCsvHeader\n\n'
            '"Download template" saves exactly that row as an empty file to '
            'fill in.\n\n'
            'OPTIONS. Four to six per question, and a file may mix them: '
            'option1 to option4 are required, option5 and option6 are for the '
            'questions that have them. Leave the rest blank.\n\n'
            'correct_option points at the answer, as a number (1-6) or as a '
            'letter (A-F). It has to point at an option that is filled in.\n\n'
            'difficulty is easy, medium or hard — blank means medium. '
            'marks_correct and marks_incorrect are numbers; blank means 1 and '
            '0. tags are separated by commas inside the one cell, which means '
            'the cell has to be quoted: "anatomy, thorax".\n\n'
            'IMAGES. question_image_url and optionN_image_url take an address '
            'the picture already lives at, not a file. Upload the picture '
            'first and paste its link.\n\n'
            'The subject and topic are the ones picked above, not columns: '
            'every row in the file lands in the same place.',
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}

/// The columns the parser reads, as the row the template carries.
///
/// Headers only when downloaded: a template with sample rows in it comes back
/// uploaded with the samples still in it.
const String kQuestionCsvHeader =
    'question_text,question_image_url,'
    'option1,option1_image_url,option2,option2_image_url,'
    'option3,option3_image_url,option4,option4_image_url,'
    'option5,option5_image_url,option6,option6_image_url,'
    'correct_option,difficulty,marks_correct,marks_incorrect,explanation,tags';

/// What is wrong with the file, before anything is sent.
///
/// The server checks its own rules again; this is about catching the whole
/// file in one look rather than discovering line 40 after 39 questions are
/// already in the bank.
List<TestUploadIssue> validateQuestions(List<SheetQuestion> questions) {
  final issues = <TestUploadIssue>[];

  for (final question in questions) {
    if (question.options.length < 4) {
      issues.add(TestUploadIssue(
        row: question.sourceRow,
        field: 'option1-option4',
        message: 'Only ${question.options.length} option'
            '${question.options.length == 1 ? '' : 's'} — four is the minimum',
      ));
    }

    if (question.correctOption < 1 ||
        question.correctOption > question.options.length) {
      issues.add(TestUploadIssue(
        row: question.sourceRow,
        field: 'correct_option',
        message: question.correctOption == 0
            ? 'Missing — give the answer as 1-6 or A-F'
            : 'Points at option ${question.correctOption}, which is blank',
      ));
    }

    final difficulty = question.difficulty.trim().toLowerCase();
    if (difficulty.isNotEmpty &&
        !Difficulty.values.any((d) => d.name == difficulty)) {
      issues.add(TestUploadIssue(
        row: question.sourceRow,
        field: 'difficulty',
        message: '"${question.difficulty}" is not easy, medium or hard — '
            'medium will be used',
        severity: 'warning',
      ));
    }

    for (final (field, raw) in [
      ('marks_correct', question.marksCorrect),
      ('marks_incorrect', question.marksIncorrect),
    ]) {
      if (raw.trim().isNotEmpty && num.tryParse(raw.trim()) == null) {
        issues.add(TestUploadIssue(
          row: question.sourceRow,
          field: field,
          message: '"$raw" is not a number — the default will be used',
          severity: 'warning',
        ));
      }
    }
  }

  return issues;
}

/// One CSV row as the bank's create endpoint wants it.
///
/// The subject and topic come from the pickers, not the file: the whole point
/// of the tab is that one file fills one place in the bank.
Question questionFrom(
  SheetQuestion row, {
  required int subjectId,
  required int topicId,
}) =>
    Question(
      id: 0,
      subjectId: subjectId,
      topicId: topicId,
      questionText: row.questionText,
      questionImageUrl: row.questionImageUrl,
      difficulty: DifficultyX.fromApiValue(
          row.difficulty.trim().isEmpty ? null : row.difficulty.trim().toLowerCase()),
      marksCorrect: num.tryParse(row.marksCorrect.trim()) ?? 1,
      marksIncorrect: num.tryParse(row.marksIncorrect.trim()) ?? 0,
      explanation: row.explanation.trim().isEmpty ? null : row.explanation.trim(),
      status: QuestionStatus.active,
      tagNames: row.tags,
      options: [
        for (var i = 0; i < row.options.length; i++)
          QuestionOption(
            optionText: row.options[i],
            optionImageUrl: row.optionImageUrls[i],
            isCorrect: i + 1 == row.correctOption,
            displayOrder: i,
          ),
      ],
    );
