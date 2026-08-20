import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theam/theam_dart.dart';
import '../../provider/lesson_upload_provider.dart';
import '../../services/lesson_services.dart';
import '../../services/lesson_upload_service.dart';
import '../../models/lesson_detail_model.dart';
import '../../models/quiz_model.dart';
import '../../provider/question_bank_provider.dart';
import '../../services/quiz_service.dart';
import 'lesson_subscription_sheet.dart';

class _UploadTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isUploading;
  final bool hasFile;
  final String? fileLabel;
  final String placeholder;
  final String? errorMessage;
  final VoidCallback onPick;
  final VoidCallback onRetry;
  final VoidCallback onRemove;
  final Widget? previewImage;

  const _UploadTile({
    required this.icon,
    required this.color,
    required this.isUploading,
    required this.hasFile,
    required this.fileLabel,
    required this.placeholder,
    required this.errorMessage,
    required this.onPick,
    required this.onRetry,
    required this.onRemove,
    this.previewImage,
  });

  @override
  Widget build(BuildContext context) {
    if (errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: LmsColors.error.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: LmsColors.error.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: LmsColors.error, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(errorMessage!, style: const TextStyle(color: LmsColors.error, fontSize: 12.5))),
            TextButton(onPressed: onRetry, child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w700))),
          ],
        ),
      );
    }

    if (isUploading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(color: LmsColors.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: LmsColors.border)),
        child: Row(
          children: [
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: color)),
            const SizedBox(width: 10),
            const Text('Uploading...', style: TextStyle(fontSize: 13, color: LmsColors.textGrey)),
          ],
        ),
      );
    }

    if (hasFile) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            if (previewImage != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(width: 40, height: 40, child: previewImage),
              ),
              const SizedBox(width: 10),
            ] else ...[
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                fileLabel ?? 'File attached',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18, color: LmsColors.textGrey),
              onPressed: onRemove,
              tooltip: 'Remove',
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        decoration: BoxDecoration(
          color: LmsColors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: LmsColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: LmsColors.textGrey),
            const SizedBox(width: 10),
            Text(placeholder, style: const TextStyle(fontSize: 13, color: LmsColors.textGrey)),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: LmsColors.textGrey));
  }
}

Future<bool?> showAddEditLessonSheet(
    BuildContext context, {
      required int chapterId,
      int? courseId, // NEW - needed to list the course's plans
      int? lessonId,
      String? initialTitle,
      String? initialDescription,
      LessonType? initialType,
      String? initialVideoUrl,
      String? initialVideoPublicId,
      String? initialThumbnailUrl,
      String? initialThumbnailPublicId,
      String? initialNoteUrl,
      String? initialNotePublicId,
      String? initialNoteFileType,
      String? initialContent, // legacy free-text reference, shown read-only
      int? initialQuizId,
      bool? initialIsFreePreview,
      LessonAccessType? initialAccessType,
      LessonStatus? initialStatus, // NEW
      Set<int> initialPlanIds = const {}, // NEW - multi-plan selection
      List<LessonPlanSummary> initialPlans = const [], // NEW - keeps delisted plans visible
      int? initialDisplayOrder,
    }) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LessonUpdateProvider()),
          // Subject/topic for the quiz picker. Its own instance, so the
          // Question Bank screen's taxonomy state is untouched.
          ChangeNotifierProvider(create: (_) => SubjectTopicProvider()),
        ],
        child: _AddEditLessonSheet(
          chapterId: chapterId,
          courseId: courseId, // NEW
          lessonId: lessonId,
          initialTitle: initialTitle,
          initialDescription: initialDescription,
          initialType: initialType,
          initialVideoUrl: initialVideoUrl,
          initialVideoPublicId: initialVideoPublicId,
          initialThumbnailUrl: initialThumbnailUrl,
          initialThumbnailPublicId: initialThumbnailPublicId,
          initialNoteUrl: initialNoteUrl,
          initialNotePublicId: initialNotePublicId,
          initialNoteFileType: initialNoteFileType,
          initialContent: initialContent,
          initialQuizId: initialQuizId,
          initialIsFreePreview: initialIsFreePreview,
          initialAccessType: initialAccessType,
          initialStatus: initialStatus, // NEW
          initialPlanIds: initialPlanIds, // NEW
          initialPlans: initialPlans, // NEW
          initialDisplayOrder: initialDisplayOrder,
        ),
      );
    },
  );
}

enum _VideoSourceMode { upload, url }

class _AddEditLessonSheet extends StatefulWidget {
  final int chapterId;
  final int? courseId; // NEW
  final int? lessonId;
  final String? initialTitle;
  final String? initialDescription;
  final LessonType? initialType;
  final String? initialVideoUrl;
  final String? initialVideoPublicId;
  final String? initialThumbnailUrl;
  final String? initialThumbnailPublicId;
  final String? initialNoteUrl;
  final String? initialNotePublicId;
  final String? initialNoteFileType;
  final String? initialContent;
  final int? initialQuizId;
  final bool? initialIsFreePreview;
  final LessonAccessType? initialAccessType;
  final LessonStatus? initialStatus; // NEW
  final Set<int> initialPlanIds; // NEW
  final List<LessonPlanSummary> initialPlans; // NEW
  final int? initialDisplayOrder;

  const _AddEditLessonSheet({
    required this.chapterId,
    this.courseId, // NEW
    this.lessonId,
    this.initialTitle,
    this.initialDescription,
    this.initialType,
    this.initialVideoUrl,
    this.initialVideoPublicId,
    this.initialThumbnailUrl,
    this.initialThumbnailPublicId,
    this.initialNoteUrl,
    this.initialNotePublicId,
    this.initialNoteFileType,
    this.initialContent,
    this.initialQuizId,
    this.initialIsFreePreview,
    this.initialAccessType,
    this.initialStatus, // NEW
    this.initialPlanIds = const {}, // NEW
    this.initialPlans = const [], // NEW
    this.initialDisplayOrder,
  });

  @override
  State<_AddEditLessonSheet> createState() => _AddEditLessonSheetState();
}

class _AddEditLessonSheetState extends State<_AddEditLessonSheet> {
  final _formKey = GlobalKey<FormState>();
  final _uploadService = LessonUploadService();

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _videoUrlController;
  LessonType _type = LessonType.video;
  late bool _isFreePreview;
  late LessonAccessType _accessType;
  late LessonStatus _status; // NEW

  // Premium plan picker - a lesson can require any number of plans; empty
  // means "any active subscription".
  late Set<int> _planIds;

  _VideoSourceMode _videoSourceMode = _VideoSourceMode.upload;
  String? _videoUrl;
  String? _videoPublicId;
  String? _pickedVideoName;
  bool _isUploadingVideo = false;
  String? _videoUploadError;
  bool _videoRemoved = false;

  String? _thumbnailUrl;
  String? _thumbnailPublicId;
  String? _pickedThumbnailName;
  bool _isUploadingThumbnail = false;
  String? _thumbnailUploadError;
  bool _thumbnailRemoved = false;

  String? _noteUrl;
  String? _notePublicId;
  String? _noteFileType;
  String? _pickedNoteName;
  bool _isUploadingNote = false;
  String? _noteUploadError;
  bool _noteRemoved = false;

  // ── Quiz link (only used when _type == LessonType.quiz) ──────────
  final _quizService = QuizService();

  int? _selectedQuizId;
  Quiz? _selectedQuiz; // carries the live question count for the summary chip
  List<Quiz> _availableQuizzes = [];

  /// Filters that narrow the quiz dropdown. Subject and topic mirror the
  /// Question Bank taxonomy; the exam tag is derived from the loaded quizzes
  /// because no endpoint lists tags on their own.
  int? _filterSubjectId;
  int? _filterTopicId;
  String? _filterExamTag;

  bool _isLoadingQuizzes = false;
  bool _isLoadingSelectedQuiz = false;
  String? _quizLoadError;

  /// Set when Save is pressed on a quiz lesson with nothing selected - the
  /// dropdown isn't a FormField, so it can't report through the validator.
  String? _quizValidationError;

  bool get _isQuiz => _type == LessonType.quiz;

  /// True when an edit started on a quiz lesson - needed to know whether to
  /// send an explicit null on the way out of quiz type.
  late final bool _startedAsQuiz;

  /// publicIds of assets uploaded during THIS session that are not yet
  /// saved onto a lesson. Anything left here when the sheet closes is an
  /// orphan on Cloudinary, so it gets deleted. Initial values from edit
  /// mode are deliberately NOT tracked - those belong to the saved lesson,
  /// and removing them is the save's job (via the remove* flags).
  String? _freshVideoPublicId;
  String? _freshThumbnailPublicId;
  String? _freshNotePublicId;

  bool get _isEditMode => widget.lessonId != null;

  bool get _hadInitialVideo =>
      widget.initialVideoUrl != null || widget.initialVideoPublicId != null;

  bool get _hadInitialThumbnail =>
      widget.initialThumbnailUrl != null || widget.initialThumbnailPublicId != null;

  bool get _hadInitialNote =>
      widget.initialNoteUrl != null || widget.initialNotePublicId != null;

  bool get _hadInitialDescription =>
      widget.initialDescription != null && widget.initialDescription!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _descriptionController = TextEditingController(text: widget.initialDescription ?? '');
    _type = widget.initialType ?? LessonType.video;
    _isFreePreview = widget.initialIsFreePreview ?? false;
    _accessType = widget.initialAccessType ?? LessonAccessType.free;
    _status = widget.initialStatus ?? LessonStatus.draft; // NEW
    _planIds = {...widget.initialPlanIds}; // NEW

    _videoUrl = widget.initialVideoUrl;
    _videoPublicId = widget.initialVideoPublicId;
    _videoUrlController = TextEditingController(text: widget.initialVideoUrl ?? '');

    if (widget.initialVideoUrl != null && widget.initialVideoPublicId == null) {
      _videoSourceMode = _VideoSourceMode.url;
    }

    _thumbnailUrl = widget.initialThumbnailUrl;
    _thumbnailPublicId = widget.initialThumbnailPublicId;

    _noteUrl = widget.initialNoteUrl;
    _notePublicId = widget.initialNotePublicId;
    _noteFileType = widget.initialNoteFileType;

    _selectedQuizId = widget.initialQuizId;
    _startedAsQuiz = _isEditMode && widget.initialType == LessonType.quiz;

    if (_isQuiz) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _initQuizPicker());
    }
  }

  /// Loads the subject list, and - in edit mode - resolves the already-linked
  /// quiz so its subject/topic/tag can pre-populate the filters and its title
  /// can show in the summary chip.
  Future<void> _initQuizPicker() async {
    if (!mounted) return;
    final taxonomy = context.read<SubjectTopicProvider>();
    taxonomy.loadSubjects();

    final linkedId = _selectedQuizId;
    if (linkedId == null) return;

    setState(() => _isLoadingSelectedQuiz = true);
    final result = await _quizService.get(linkedId);

    if (!mounted) return;
    if (!result.isSuccess || result.quiz == null) {
      setState(() {
        _isLoadingSelectedQuiz = false;
        _quizLoadError = result.errorMessage;
      });
      return;
    }

    final quiz = result.quiz!;
    setState(() {
      _isLoadingSelectedQuiz = false;
      _selectedQuiz = quiz;
      _filterSubjectId = quiz.subjectId;
      _filterTopicId = quiz.topicId;
      _filterExamTag = quiz.examTag;
    });

    await taxonomy.loadTopics(subjectId: quiz.subjectId);
    await _loadQuizzes();
  }

  @override
  void dispose() {
    // Sheet dismissed without a successful save - every upload made here is
    // unreferenced. Fire-and-forget through the service, not the provider:
    // ChangeNotifierProvider is tearing the provider down right now and its
    // notifyListeners() would throw.
    _discardOrphan(_freshVideoPublicId, _uploadService.deleteVideo);
    _discardOrphan(_freshThumbnailPublicId, _uploadService.deleteThumbnail);
    _discardOrphan(_freshNotePublicId, _uploadService.deleteNote);

    _titleController.dispose();
    _descriptionController.dispose();
    _videoUrlController.dispose();
    super.dispose();
  }

  void _discardOrphan(String? publicId, Future<DeleteResult> Function(String) delete) {
    if (publicId != null && publicId.isNotEmpty) delete(publicId);
  }

  /// Deletes an unsaved upload through the provider, so the sheet's error
  /// state reflects a failed cleanup. Safe to call while mounted only.
  Future<void> _deleteFreshAsset(
    String? publicId,
    Future<bool> Function({required String publicId}) delete,
  ) async {
    if (publicId == null || publicId.isEmpty) return;
    await delete(publicId: publicId);
  }

  void _setAccessType(LessonAccessType value) {
    setState(() {
      _accessType = value;
      // Mirrors the backend: a free lesson can't carry plans.
      if (value != LessonAccessType.premium) _planIds = {};
    });
  }

  Future<void> _pickVideo() async {
    final provider = context.read<LessonUpdateProvider>();

    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    final Uint8List bytes = result.files.single.bytes!;
    final String name = result.files.single.name;

    // Replacing a file picked earlier in this session: the old upload is
    // about to become unreachable, so drop it before the new one lands.
    final String? replaced = _freshVideoPublicId;

    setState(() {
      _pickedVideoName = name;
      _isUploadingVideo = true;
      _videoUploadError = null;
      _videoRemoved = false;
      _freshVideoPublicId = null;
    });

    await _deleteFreshAsset(replaced, provider.deleteVideoAsset);

    final uploadResult = await _uploadService.uploadVideo(bytes, name);

    if (!mounted) return;
    setState(() {
      _isUploadingVideo = false;
      if (uploadResult.isSuccess) {
        _videoUrl = uploadResult.url;
        _videoPublicId = uploadResult.publicId;
        _freshVideoPublicId = uploadResult.publicId;
      } else {
        _videoUploadError = uploadResult.errorMessage;
      }
    });
  }

  Future<void> _removeVideo() async {
    final provider = context.read<LessonUpdateProvider>();
    final String? orphan = _freshVideoPublicId;

    setState(() {
      _videoUrl = null;
      _videoPublicId = null;
      _pickedVideoName = null;
      _videoUploadError = null;
      _freshVideoPublicId = null;
      _videoUrlController.clear();
      _videoRemoved = _isEditMode && _hadInitialVideo;
    });

    await _deleteFreshAsset(orphan, provider.deleteVideoAsset);
  }

  Future<void> _setVideoSourceMode(_VideoSourceMode mode) async {
    if (mode == _videoSourceMode) return;

    final provider = context.read<LessonUpdateProvider>();
    final String? orphan = _freshVideoPublicId;

    setState(() {
      _videoSourceMode = mode;
      _videoUrl = null;
      _videoPublicId = null;
      _pickedVideoName = null;
      _videoUploadError = null;
      _freshVideoPublicId = null;
      _videoUrlController.clear();
      _videoRemoved = _isEditMode && _hadInitialVideo;
    });

    await _deleteFreshAsset(orphan, provider.deleteVideoAsset);
  }

  void _onVideoUrlChanged(String value) {
    final trimmed = value.trim();
    setState(() {
      _videoUrl = trimmed.isEmpty ? null : trimmed;
      _videoPublicId = null;
      _videoRemoved = trimmed.isEmpty && _isEditMode && _hadInitialVideo;
    });
  }

  Future<void> _pickThumbnail() async {
    final provider = context.read<LessonUpdateProvider>();

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    final Uint8List bytes = result.files.single.bytes!;
    final String name = result.files.single.name;

    final String? replaced = _freshThumbnailPublicId;

    setState(() {
      _pickedThumbnailName = name;
      _isUploadingThumbnail = true;
      _thumbnailUploadError = null;
      _thumbnailRemoved = false;
      _freshThumbnailPublicId = null;
    });

    await _deleteFreshAsset(replaced, provider.deleteThumbnailAsset);

    final uploadResult = await _uploadService.uploadThumbnail(bytes, name);

    if (!mounted) return;
    setState(() {
      _isUploadingThumbnail = false;
      if (uploadResult.isSuccess) {
        _thumbnailUrl = uploadResult.url;
        _thumbnailPublicId = uploadResult.publicId;
        _freshThumbnailPublicId = uploadResult.publicId;
      } else {
        _thumbnailUploadError = uploadResult.errorMessage;
      }
    });
  }

  Future<void> _removeThumbnail() async {
    final provider = context.read<LessonUpdateProvider>();
    final String? orphan = _freshThumbnailPublicId;

    setState(() {
      _thumbnailUrl = null;
      _thumbnailPublicId = null;
      _pickedThumbnailName = null;
      _thumbnailUploadError = null;
      _freshThumbnailPublicId = null;
      _thumbnailRemoved = _isEditMode && _hadInitialThumbnail;
    });

    await _deleteFreshAsset(orphan, provider.deleteThumbnailAsset);
  }

  Future<void> _pickNote() async {
    final provider = context.read<LessonUpdateProvider>();

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    final Uint8List bytes = result.files.single.bytes!;
    final String name = result.files.single.name;

    final String? replaced = _freshNotePublicId;

    setState(() {
      _pickedNoteName = name;
      _isUploadingNote = true;
      _noteUploadError = null;
      _noteRemoved = false;
      _freshNotePublicId = null;
    });

    await _deleteFreshAsset(replaced, provider.deleteNoteAsset);

    final uploadResult = await _uploadService.uploadNote(bytes, name);

    if (!mounted) return;
    setState(() {
      _isUploadingNote = false;
      if (uploadResult.isSuccess) {
        _noteUrl = uploadResult.url;
        _notePublicId = uploadResult.publicId;
        _noteFileType = uploadResult.fileType;
        _freshNotePublicId = uploadResult.publicId;
      } else {
        _noteUploadError = uploadResult.errorMessage;
      }
    });
  }

  Future<void> _removeNote() async {
    final provider = context.read<LessonUpdateProvider>();
    final String? orphan = _freshNotePublicId;

    setState(() {
      _noteUrl = null;
      _notePublicId = null;
      _noteFileType = null;
      _pickedNoteName = null;
      _noteUploadError = null;
      _freshNotePublicId = null;
      _noteRemoved = _isEditMode && _hadInitialNote;
    });

    await _deleteFreshAsset(orphan, provider.deleteNoteAsset);
  }

  // ── Quiz picker ──────────────────────────────────────────────────

  /// Switching the primary type in or out of quiz. The media tiles and the
  /// quiz picker are mutually exclusive, so this also spins up the picker
  /// the first time quiz is chosen.
  void _onTypeChanged(LessonType type) {
    if (type == _type) return;
    final wasQuiz = _isQuiz;
    setState(() {
      _type = type;
      _quizValidationError = null;
    });
    if (!wasQuiz && type == LessonType.quiz) _initQuizPicker();
  }

  Future<void> _onQuizSubjectChanged(int? subjectId) async {
    if (subjectId == null || subjectId == _filterSubjectId) return;

    final taxonomy = context.read<SubjectTopicProvider>();
    setState(() {
      _filterSubjectId = subjectId;
      _filterTopicId = null; // a topic only means something inside its subject
      _filterExamTag = null;
      _availableQuizzes = [];
    });

    await taxonomy.loadTopics(subjectId: subjectId);
  }

  Future<void> _onQuizTopicChanged(int? topicId) async {
    setState(() {
      _filterTopicId = topicId;
      _filterExamTag = null;
    });
    await _loadQuizzes();
  }

  Future<void> _onExamTagChanged(String? examTag) async {
    setState(() => _filterExamTag = examTag);
    await _loadQuizzes();
  }

  Future<void> _loadQuizzes() async {
    if (_filterSubjectId == null || _filterTopicId == null) return;

    setState(() {
      _isLoadingQuizzes = true;
      _quizLoadError = null;
    });

    final result = await _quizService.list(
      subjectId: _filterSubjectId,
      topicId: _filterTopicId,
      examTag: _filterExamTag,
    );

    if (!mounted) return;
    setState(() {
      _isLoadingQuizzes = false;
      if (result.isSuccess) {
        _availableQuizzes = result.quizzes ?? [];
        // A selection that the new filters exclude has to go, or Save would
        // send a quiz the admin can no longer see.
        if (_selectedQuizId != null &&
            !_availableQuizzes.any((q) => q.id == _selectedQuizId)) {
          _selectedQuizId = null;
          _selectedQuiz = null;
        }
      } else {
        _quizLoadError = result.errorMessage;
      }
    });
  }

  Future<void> _onQuizSelected(int? quizId) async {
    setState(() {
      _selectedQuizId = quizId;
      _quizValidationError = null;
      _selectedQuiz = quizId == null
          ? null
          : _availableQuizzes.where((q) => q.id == quizId).firstOrNull;
    });
    if (quizId == null) return;

    // Re-read the quiz on its own: the list row's pool count can be stale by
    // the time an admin gets here, and that number drives the warning.
    setState(() => _isLoadingSelectedQuiz = true);
    final result = await _quizService.get(quizId);

    if (!mounted) return;
    setState(() {
      _isLoadingSelectedQuiz = false;
      if (result.isSuccess && result.quiz != null) _selectedQuiz = result.quiz;
    });
  }

  /// Creates a quiz inline from the subject/topic/tag already chosen, then
  /// selects it - so the admin never leaves the lesson sheet.
  Future<void> _openNewQuizDialog() async {
    final subjectId = _filterSubjectId;
    final topicId = _filterTopicId;
    if (subjectId == null || topicId == null) return;

    final titleController = TextEditingController();
    final countController = TextEditingController(text: '10');
    final formKey = GlobalKey<FormState>();

    final created = await showDialog<Quiz>(
      context: context,
      builder: (ctx) => _NewQuizDialog(
        formKey: formKey,
        titleController: titleController,
        countController: countController,
        examTag: _filterExamTag,
        onSubmit: () async {
          if (!formKey.currentState!.validate()) return null;
          return _quizService.create(Quiz(
            id: 0,
            title: titleController.text.trim(),
            subjectId: subjectId,
            topicId: topicId,
            examTag: _filterExamTag,
            questionCount: int.tryParse(countController.text.trim()) ?? 10,
          ));
        },
      ),
    );

    titleController.dispose();
    countController.dispose();

    if (created == null || !mounted) return;

    setState(() {
      _availableQuizzes = [created, ..._availableQuizzes];
      _quizValidationError = null;
    });
    await _onQuizSelected(created.id);
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isUploadingVideo || _isUploadingThumbnail || _isUploadingNote) return;

    // A quiz lesson has to point at a quiz - the dropdown can't report this
    // through the form validator, so it's checked here before any request.
    if (_isQuiz && _selectedQuizId == null) {
      setState(() => _quizValidationError = 'Pick a quiz for this lesson.');
      return;
    }

    final provider = context.read<LessonUpdateProvider>();
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    final bool removeDescription =
        _isEditMode && _hadInitialDescription && description.isEmpty;

    // Media and the quiz link are mutually exclusive. On a quiz lesson every
    // media field is omitted (null = "key absent" in the service), and on the
    // way out of quiz type the link is explicitly nulled to unlink it.
    final bool removeQuiz = _startedAsQuiz && !_isQuiz;

    final bool success = _isEditMode
        ? await provider.updateLesson(
      chapterId: widget.chapterId,
      lessonId: widget.lessonId!,
      title: title,
      description: description.isEmpty ? null : description,
      removeDescription: removeDescription,
      type: _type,
      videoUrl: _isQuiz ? null : _videoUrl,
      videoPublicId: _isQuiz ? null : _videoPublicId,
      removeVideo: _isQuiz ? false : _videoRemoved,
      thumbnailUrl: _isQuiz ? null : _thumbnailUrl,
      thumbnailPublicId: _isQuiz ? null : _thumbnailPublicId,
      removeThumbnail: _isQuiz ? false : _thumbnailRemoved,
      noteUrl: _isQuiz ? null : _noteUrl,
      notePublicId: _isQuiz ? null : _notePublicId,
      noteFileType: _isQuiz ? null : _noteFileType,
      removeNote: _isQuiz ? false : _noteRemoved,
      isFreePreview: _isFreePreview,
      accessType: _accessType,
      status: _status,
      planIds: _planIds.toList(),
      quizId: _isQuiz ? _selectedQuizId : null,
      removeQuiz: removeQuiz,
    )
        : await provider.createLesson(
      chapterId: widget.chapterId,
      title: title,
      description: description.isEmpty ? null : description,
      type: _type,
      videoUrl: _isQuiz ? null : _videoUrl,
      videoPublicId: _isQuiz ? null : _videoPublicId,
      thumbnailUrl: _isQuiz ? null : _thumbnailUrl,
      thumbnailPublicId: _isQuiz ? null : _thumbnailPublicId,
      noteUrl: _isQuiz ? null : _noteUrl,
      notePublicId: _isQuiz ? null : _notePublicId,
      noteFileType: _isQuiz ? null : _noteFileType,
      displayOrder: widget.initialDisplayOrder,
      isFreePreview: _isFreePreview,
      accessType: _accessType,
      status: _status,
      planIds: _planIds.toList(),
      quizId: _isQuiz ? _selectedQuizId : null,
    );

    if (!mounted) return;
    if (success) {
      if (!_isQuiz) {
        // Persisted onto the lesson - dispose() must not delete them.
        _freshVideoPublicId = null;
        _freshThumbnailPublicId = null;
        _freshNotePublicId = null;
      }
      // On a quiz lesson the media fields were omitted, so any upload made
      // in this session is unreferenced. Leaving the ids tracked lets
      // dispose() clean them off Cloudinary.
      Navigator.pop(context, true);
    }
  }

  InputDecoration _inputDecoration(String hint, {IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: LmsColors.textGrey, fontSize: 13.5),
      prefixIcon: icon != null ? Icon(icon, size: 18, color: LmsColors.textGrey) : null,
      filled: true,
      fillColor: LmsColors.bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: LmsColors.border)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: LmsColors.primary, width: 1.5),
      ),
    );
  }

  IconData _noteIcon() {
    switch (_noteFileType) {
      case 'doc':
      case 'docx':
        return Icons.description_outlined;
      default:
        return Icons.picture_as_pdf_outlined;
    }
  }

  // ── Quiz picker UI ───────────────────────────────────────────────

  Widget _quizPicker() {
    final taxonomy = context.watch<SubjectTopicProvider>();
    final examTags = examTagsOf(_availableQuizzes);
    final canPickTopic = _filterSubjectId != null;
    final canPickQuiz = _filterTopicId != null;
    final legacyRef = widget.initialContent?.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('Quiz'),
        const SizedBox(height: 6),
        const Text(
          'Narrow by subject and topic, then pick the quiz this lesson runs.',
          style: TextStyle(fontSize: 11.5, color: LmsColors.textGrey),
        ),
        const SizedBox(height: 10),

        // A lesson saved before quizzes existed still carries its old
        // free-text reference. Showing it is the only clue an admin has as
        // to which quiz to pick now.
        if (legacyRef.isNotEmpty && _selectedQuizId == null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: LmsColors.bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: LmsColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.history_rounded, size: 15, color: LmsColors.textGrey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Previously referenced "$legacyRef". Pick a quiz to replace it.',
                    style: const TextStyle(fontSize: 11.5, color: LmsColors.textGrey),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        DropdownButtonFormField<int>(
          initialValue: _filterSubjectId,
          isExpanded: true,
          decoration: _inputDecoration('Subject', icon: Icons.folder_outlined),
          items: taxonomy.subjects
              .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
              .toList(),
          onChanged: _onQuizSubjectChanged,
        ),
        const SizedBox(height: 10),

        DropdownButtonFormField<int>(
          initialValue: _filterTopicId,
          isExpanded: true,
          decoration: _inputDecoration(
            canPickTopic ? 'Topic' : 'Topic (pick a subject first)',
            icon: Icons.label_outline_rounded,
          ),
          items: taxonomy.topics
              .map((t) => DropdownMenuItem(value: t.id, child: Text(t.name)))
              .toList(),
          onChanged: canPickTopic ? _onQuizTopicChanged : null,
        ),
        const SizedBox(height: 10),

        // Exam tags are derived from the quizzes already loaded - there is no
        // endpoint that lists them.
        if (examTags.isNotEmpty) ...[
          DropdownButtonFormField<String?>(
            initialValue: _filterExamTag,
            isExpanded: true,
            decoration: _inputDecoration('Exam tag (optional)', icon: Icons.sell_outlined),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Any exam tag')),
              ...examTags.map((t) => DropdownMenuItem<String?>(value: t, child: Text(t))),
            ],
            onChanged: _onExamTagChanged,
          ),
          const SizedBox(height: 10),
        ],

        if (_isLoadingQuizzes)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: LmsColors.primary),
              ),
            ),
          )
        else
          DropdownButtonFormField<int>(
            initialValue: _selectedQuizId,
            isExpanded: true,
            decoration: _inputDecoration(
              !canPickQuiz
                  ? 'Quiz (pick a topic first)'
                  : _availableQuizzes.isEmpty
                      ? 'No quizzes match these filters'
                      : 'Select a quiz',
              icon: Icons.quiz_outlined,
            ),
            items: _availableQuizzes
                .map((q) => DropdownMenuItem(value: q.id, child: Text(q.title)))
                .toList(),
            onChanged: canPickQuiz ? _onQuizSelected : null,
          ),

        if (_quizLoadError != null) ...[
          const SizedBox(height: 8),
          Text(_quizLoadError!,
              style: const TextStyle(color: LmsColors.error, fontSize: 12.5)),
        ],
        if (_quizValidationError != null) ...[
          const SizedBox(height: 8),
          Text(_quizValidationError!,
              style: const TextStyle(color: LmsColors.error, fontSize: 12.5)),
        ],

        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: canPickQuiz ? _openNewQuizDialog : null,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('New Quiz',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
        ),

        if (_selectedQuiz != null || _isLoadingSelectedQuiz) ...[
          const SizedBox(height: 4),
          _QuizSummaryChip(
            quiz: _selectedQuiz,
            isLoading: _isLoadingSelectedQuiz,
          ),
        ],
      ],
    );
  }

  Widget _planPicker() {
    if (widget.courseId == null) {
      return const Text(
        'Plan list unavailable here - this lesson will require any active subscription.',
        style: TextStyle(fontSize: 12, color: LmsColors.textGrey),
      );
    }

    // Same selector the standalone subscription sheet uses, so create / edit /
    // delete of a plan behaves identically wherever you are.
    return LessonPlanSelector(
      courseId: widget.courseId!,
      selectedPlanIds: _planIds,
      attachedPlans: widget.initialPlans,
      onChanged: (ids) => setState(() => _planIds = ids),
    );
  }

  Widget _sourceModeToggle() {
    Widget segment(String label, IconData icon, _VideoSourceMode mode) {
      final isSelected = _videoSourceMode == mode;
      return Expanded(
        child: InkWell(
          onTap: () => _setVideoSourceMode(mode),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? LmsColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15, color: isSelected ? Colors.white : LmsColors.textGrey),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : LmsColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: LmsColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LmsColors.border),
      ),
      child: Row(
        children: [
          segment('Upload file', Icons.upload_outlined, _VideoSourceMode.upload),
          segment('Paste URL', Icons.link_rounded, _VideoSourceMode.url),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LessonUpdateProvider>();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bool canSave = !provider.isUpdating &&
        !_isUploadingVideo &&
        !_isUploadingThumbnail &&
        !_isUploadingNote;

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
                    decoration: BoxDecoration(color: LmsColors.border, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _isEditMode ? 'Edit Lesson' : 'Add Lesson',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: LmsColors.textDark),
                ),
                const SizedBox(height: 20),

                const _FieldLabel('Lesson Title'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _titleController,
                  autofocus: true,
                  decoration: _inputDecoration('e.g. Introduction to Anatomy'),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Title is required' : null,
                ),
                const SizedBox(height: 18),

                const _FieldLabel('Description (optional)'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  minLines: 2,
                  decoration: _inputDecoration('Briefly describe what this lesson covers'),
                ),
                const SizedBox(height: 18),

                // ── Status (NEW) ──
                const _FieldLabel('Publish Status'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: LessonStatus.values.map((s) {
                    final isSelected = s == _status;
                    return ChoiceChip(
                      label: Text(s.apiValue.toUpperCase()),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _status = s),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : LmsColors.textDark,
                      ),
                      selectedColor: s == LessonStatus.published ? LmsColors.success : (s == LessonStatus.draft ? LmsColors.primary : LmsColors.textGrey),
                      backgroundColor: LmsColors.bg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: isSelected ? Colors.transparent : LmsColors.border),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),

                const _FieldLabel('Primary Type'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: LessonType.values.map((t) {
                    final isSelected = t == _type;
                    return ChoiceChip(
                      label: Text(t.apiValue),
                      selected: isSelected,
                      onSelected: (_) => _onTypeChanged(t),
                      labelStyle: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : LmsColors.textDark,
                      ),
                      selectedColor: LmsColors.primary,
                      backgroundColor: LmsColors.bg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: isSelected ? LmsColors.primary : LmsColors.border),
                      ),
                    );
                  }).toList(),
                ),

                // Media and the quiz link are mutually exclusive - on a quiz
                // lesson these come out of the tree rather than being
                // disabled, so there's nothing to half-fill.
                if (!_isQuiz) ...[
                const _FieldLabel('Thumbnail Image (optional)'),
                const SizedBox(height: 6),
                _UploadTile(
                  icon: Icons.image_outlined,
                  color: const Color(0xFF2ECC71),
                  isUploading: _isUploadingThumbnail,
                  hasFile: _thumbnailUrl != null,
                  fileLabel: _pickedThumbnailName ?? (_thumbnailUrl != null ? 'Thumbnail attached' : null),
                  placeholder: 'Tap to choose an image (JPG, PNG, WEBP)',
                  errorMessage: _thumbnailUploadError,
                  onPick: _pickThumbnail,
                  onRetry: _pickThumbnail,
                  onRemove: _removeThumbnail,
                  previewImage: _thumbnailUrl != null
                      ? Image.network(
                    _thumbnailUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined, size: 18),
                  )
                      : null,
                ),
                const SizedBox(height: 18),

                const _FieldLabel('Class Video (optional)'),
                const SizedBox(height: 6),
                _sourceModeToggle(),
                const SizedBox(height: 8),
                if (_videoSourceMode == _VideoSourceMode.upload)
                  _UploadTile(
                    icon: Icons.play_circle_outline_rounded,
                    color: const Color(0xFF4C6FFF),
                    isUploading: _isUploadingVideo,
                    hasFile: _videoUrl != null,
                    fileLabel: _pickedVideoName ?? (_videoUrl != null ? 'Video attached' : null),
                    placeholder: 'Tap to choose a video file (MP4, MOV, MKV, WEBM)',
                    errorMessage: _videoUploadError,
                    onPick: _pickVideo,
                    onRetry: _pickVideo,
                    onRemove: _removeVideo,
                  )
                else
                  TextFormField(
                    controller: _videoUrlController,
                    onChanged: _onVideoUrlChanged,
                    keyboardType: TextInputType.url,
                    decoration: _inputDecoration(
                      'https://example.com/video.mp4',
                      icon: Icons.link_rounded,
                    ),
                    validator: (value) {
                      if (_videoSourceMode != _VideoSourceMode.url) return null;
                      final v = value?.trim() ?? '';
                      if (v.isEmpty) return null;
                      final uri = Uri.tryParse(v);
                      if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
                        return 'Enter a valid URL';
                      }
                      return null;
                    },
                  ),
                const SizedBox(height: 16),

                const _FieldLabel('Notes (PDF or Word document, optional)'),
                const SizedBox(height: 6),
                _UploadTile(
                  icon: _noteIcon(),
                  color: const Color(0xFFFF9F43),
                  isUploading: _isUploadingNote,
                  hasFile: _noteUrl != null,
                  fileLabel: _pickedNoteName ?? (_noteUrl != null ? 'Note attached' : null),
                  placeholder: 'Tap to choose a PDF or Word file',
                  errorMessage: _noteUploadError,
                  onPick: _pickNote,
                  onRetry: _pickNote,
                  onRemove: _removeNote,
                ),
                const SizedBox(height: 16),
                ],

                if (_isQuiz) ...[
                  _quizPicker(),
                  const SizedBox(height: 16),
                ],

                const _FieldLabel('Access Type'),
                const SizedBox(height: 8),
                Row(
                  children: LessonAccessType.values.map((a) {
                    final isSelected = a == _accessType;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(a.apiValue),
                        avatar: Icon(
                          a == LessonAccessType.premium ? Icons.workspace_premium_rounded : Icons.lock_open_rounded,
                          size: 15,
                          color: isSelected ? Colors.white : LmsColors.textDark,
                        ),
                        selected: isSelected,
                        onSelected: (_) => _setAccessType(a),
                        labelStyle: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : LmsColors.textDark,
                        ),
                        selectedColor: LmsColors.primary,
                        backgroundColor: LmsColors.bg,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: isSelected ? LmsColors.primary : LmsColors.border),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                if (_accessType == LessonAccessType.premium) ...[
                  const SizedBox(height: 16),
                  const _FieldLabel('Required Plans'),
                  const SizedBox(height: 6),
                  _planPicker(),
                ],
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: LmsColors.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: LmsColors.border),
                  ),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _isFreePreview,
                    onChanged: (value) => setState(() => _isFreePreview = value),
                    activeColor: LmsColors.success,
                    title: const Text('Free Preview', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      _isFreePreview
                          ? 'Visible to everyone, even without a subscription'
                          : 'Requires an active subscription (default)',
                      style: const TextStyle(fontSize: 11.5, color: LmsColors.textGrey),
                    ),
                  ),
                ),

                if (provider.errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Text(provider.errorMessage!, style: const TextStyle(color: LmsColors.error, fontSize: 13)),
                ],

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: canSave ? _handleSave : null,
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
                      _isEditMode ? 'Save Changes' : 'Add Lesson',
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

Future<bool> confirmAndDeleteLesson(
    BuildContext context, {
      required int chapterId,
      required int lessonId,
      required String lessonTitle,
    }) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Delete Lesson', style: TextStyle(fontWeight: FontWeight.w800)),
      content: Text(
        'Are you sure you want to delete "$lessonTitle"? '
            'This will permanently remove the lesson along with its video, thumbnail, and notes. '
            'This action cannot be undone.',
        style: const TextStyle(fontSize: 13.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: LmsColors.error),
          child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );

  if (confirmed != true) return false;

  final provider = LessonUpdateProvider();
  final success = await provider.deleteLesson(chapterId: chapterId, lessonId: lessonId);

  if (!context.mounted) return success;

  if (success) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lesson deleted successfully')),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(provider.errorMessage ?? 'Failed to delete lesson')),
    );
  }

  return success;
}


/// Summary of the linked quiz: title plus the live pool count, so an admin
/// can see a thin question pool before students do.
class _QuizSummaryChip extends StatelessWidget {
  final Quiz? quiz;
  final bool isLoading;

  const _QuizSummaryChip({required this.quiz, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: LmsColors.primary),
            ),
            SizedBox(width: 8),
            Text('Loading quiz...',
                style: TextStyle(fontSize: 12, color: LmsColors.textGrey)),
          ],
        ),
      );
    }

    final q = quiz;
    if (q == null) return const SizedBox.shrink();

    final pool = q.activeQuestionPool;
    final underfilled = q.isUnderfilled;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: underfilled ? LmsColors.errorBg : LmsColors.primarySoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: underfilled ? LmsColors.errorBorder : LmsColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            underfilled ? Icons.warning_amber_rounded : Icons.quiz_outlined,
            size: 16,
            color: underfilled ? LmsColors.error : LmsColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  q.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: underfilled ? LmsColors.error : LmsColors.primary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  pool == null
                      ? '${q.questionCount} questions per attempt'
                      : underfilled
                          ? 'Only $pool active question${pool == 1 ? '' : 's'} available '
                              'for ${q.questionCount} per attempt'
                          : '${q.questionCount} of $pool active questions per attempt',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: underfilled ? LmsColors.error : LmsColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline quiz creation. Subject, topic and exam tag are inherited from what
/// the lesson sheet already has selected, so this only asks for a title and a
/// question count.
class _NewQuizDialog extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController titleController;
  final TextEditingController countController;
  final String? examTag;
  final Future<QuizResult?> Function() onSubmit;

  const _NewQuizDialog({
    required this.formKey,
    required this.titleController,
    required this.countController,
    required this.examTag,
    required this.onSubmit,
  });

  @override
  State<_NewQuizDialog> createState() => _NewQuizDialogState();
}

class _NewQuizDialogState extends State<_NewQuizDialog> {
  bool _isSaving = false;
  String? _errorMessage;

  Future<void> _submit() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final result = await widget.onSubmit();

    if (!mounted) return;
    if (result == null) {
      setState(() => _isSaving = false); // validation failed, message is inline
      return;
    }
    if (result.isSuccess && result.quiz != null) {
      Navigator.pop(context, result.quiz);
      return;
    }
    setState(() {
      _isSaving = false;
      _errorMessage = result.errorMessage ?? 'Failed to create quiz';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('New Quiz', style: TextStyle(fontWeight: FontWeight.w800)),
      content: Form(
        key: widget.formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: widget.titleController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Quiz title'),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Title is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: widget.countController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Questions per attempt'),
              validator: (value) {
                final n = int.tryParse(value?.trim() ?? '');
                if (n == null || n < 1) return 'Enter a whole number of 1 or more';
                return null;
              },
            ),
            const SizedBox(height: 12),
            Text(
              widget.examTag == null
                  ? 'Uses the subject and topic selected above.'
                  : 'Uses the subject, topic and "${widget.examTag}" tag selected above.',
              style: const TextStyle(fontSize: 11.5, color: LmsColors.textGrey),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(_errorMessage!,
                  style: const TextStyle(color: LmsColors.error, fontSize: 12.5)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: LmsColors.primary,
            foregroundColor: Colors.white,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}
