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
import '../../services/quiz_service.dart';
import '../../services/sheet_question_sync_service.dart';
import '../../widget/sheet_quiz_picker.dart';
import 'lesson_badges.dart'; // LessonBadge, reused for the deck chips

/// A media slot on the lesson sheet, in one of four states: waiting for a
/// file, uploading, attached, or failed.
///
/// An image ([previewImage]) is shown large and cropped the way the lesson
/// card crops it, so a wrong or badly framed cover is caught here rather than
/// after publishing. Anything else - the video - is a row naming the file.
class _UploadTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isUploading;
  final bool hasFile;
  final String? fileLabel;

  /// The empty state's heading and the line under it.
  final String title;
  final String subtitle;

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
    required this.title,
    required this.subtitle,
    required this.errorMessage,
    required this.onPick,
    required this.onRetry,
    required this.onRemove,
    this.previewImage,
  });

  Widget _frame({required Color tint, required Widget child}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tint.withValues(alpha: 0.28)),
        ),
        child: child,
      );

  Widget _actions() => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(onPressed: onPick, child: const Text('Replace')),
          TextButton(
            onPressed: onRemove,
            style: TextButton.styleFrom(foregroundColor: LmsColors.error),
            child: const Text('Remove'),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    if (errorMessage != null) {
      return _frame(
        tint: LmsColors.error,
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: LmsColors.error, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(errorMessage!,
                  style: const TextStyle(
                      color: LmsColors.error, fontSize: 12.5, height: 1.35)),
            ),
            TextButton(
              onPressed: onRetry,
              child: const Text('Try again',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    }

    if (isUploading) {
      return _frame(
        tint: color,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _UploadBadge(icon: icon, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileLabel ?? 'Uploading',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: LmsColors.textDark),
                      ),
                      const SizedBox(height: 2),
                      const Text('Uploading — keep this sheet open',
                          style: TextStyle(
                              fontSize: 11.5, color: LmsColors.textGrey)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                minHeight: 5,
                color: color,
                backgroundColor: color.withValues(alpha: 0.15),
              ),
            ),
          ],
        ),
      );
    }

    if (hasFile && previewImage != null) {
      return Container(
        decoration: BoxDecoration(
          color: LmsColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: LmsColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 200,
              child: ColoredBox(color: LmsColors.bg, child: previewImage),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      size: 16, color: LmsColors.success),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      fileLabel ?? 'Image attached',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: LmsColors.textDark),
                    ),
                  ),
                  _actions(),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (hasFile) {
      return _frame(
        tint: color,
        child: Row(
          children: [
            _UploadBadge(icon: icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileLabel ?? 'File attached',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: LmsColors.textDark),
                  ),
                  const SizedBox(height: 3),
                  const Row(
                    children: [
                      Icon(Icons.check_circle_rounded,
                          size: 13, color: LmsColors.success),
                      SizedBox(width: 5),
                      Text('Uploaded',
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: LmsColors.success)),
                    ],
                  ),
                ],
              ),
            ),
            _actions(),
          ],
        ),
      );
    }

    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
        ),
        child: Row(
          children: [
            _UploadBadge(icon: icon, color: color, size: 46),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: LmsColors.textDark)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: LmsColors.textGrey)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.upload_rounded, size: 16, color: Colors.white),
                  SizedBox(width: 6),
                  Text('Browse',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _UploadBadge({required this.icon, required this.color, this.size = 40});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: size * 0.48, color: color),
      );
}

/// Free or premium, as one checkbox.
///
/// Ticked means every student can open it. Unticked means a subscription is
/// needed - and which subscription is the plan's business: a plan that buys
/// `video_lecture` opens premium videos, one that buys `mcq` opens premium
/// quizzes, so the same lesson can be open to one paying student and closed to
/// another without anything being set here.
class _FreeSwitch extends StatelessWidget {
  final bool isFree;
  final LessonType type;

  /// On a premium course a ticked box is a free preview, which is worth
  /// saying: it is the one lesson students who have paid nothing will see.
  final bool coursePremium;
  final ValueChanged<bool> onChanged;

  const _FreeSwitch({
    required this.isFree,
    required this.type,
    required this.coursePremium,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final noun = type == LessonType.quiz ? 'quiz' : 'video';

    return InkWell(
      onTap: () => onChanged(!isFree),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: isFree,
                onChanged: (v) => onChanged(v ?? false),
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
                  Text(
                      coursePremium && isFree
                          ? 'Free preview'
                          : 'Free for everyone',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    isFree
                        ? coursePremium
                            ? 'Open to everyone on a paid course - this $noun '
                                'is what a student sees before subscribing.'
                            : 'Any student can open this $noun, subscribed or '
                                'not.'
                        : 'Premium. A student needs a subscription whose plan '
                            'includes ${type == LessonType.quiz ? 'quizzes' : 'video lectures'}.',
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

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: LmsColors.textGrey));
  }
}

/// What `isFreePreview` has to be, given the course and the one tick.
///
/// | course  | ticked | accessType | isFreePreview |
/// |---------|--------|------------|---------------|
/// | free    | yes    | free       | false         |
/// | free    | no     | premium    | false         |
/// | premium | yes    | free       | **true**      |
/// | premium | no     | premium    | false         |
///
/// A free course has nothing to preview. A premium one does: the tick is what
/// lets a single lesson through to students who have paid nothing.
///
/// [coursePremium] null means the caller did not know, and then [current] - the
/// flag the lesson already carries - is kept rather than guessed at.
bool lessonFreePreview({
  required bool? coursePremium,
  required bool isFree,
  required bool current,
}) =>
    coursePremium == null ? current : coursePremium && isFree;

Future<bool?> showAddEditLessonSheet(
    BuildContext context, {
      required int chapterId,
      int? courseId, // NEW - needed to list the course's plans
      bool? coursePremium,
      int? lessonId,
      String? initialTitle,
      String? initialDescription,
      LessonType? initialType,
      String? initialVideoUrl,
      String? initialVideoPublicId,
      /// Every video the lesson already has. A caller that only knows the old
      /// single-video API can keep passing initialVideoUrl and leave this
      /// empty — the sheet promotes it to a one-row list.
      List<LessonVideo> initialVideos = const [],
      List<LessonDeck> initialRapidRecalls = const [],
      String? initialThumbnailUrl,
      String? initialThumbnailPublicId,
      String? initialNoteUrl,
      String? initialNotePublicId,
      String? initialNoteFileType,
      int? initialQuizId,
      String? initialQuizTitle,
      bool? initialIsFreePreview,
      LessonAccessType? initialAccessType,
      LessonStatus? initialStatus, // NEW
      Set<int> initialPlanIds = const {}, // NEW - multi-plan selection
      List<LessonPlanSummary> initialPlans = const [], // NEW - keeps delisted plans visible
      int? initialDisplayOrder,
      int? initialSubjectId,
    }) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return ChangeNotifierProvider(
        create: (_) => LessonUpdateProvider(),
        child: _AddEditLessonSheet(
          chapterId: chapterId,
          courseId: courseId, // NEW
          coursePremium: coursePremium,
          lessonId: lessonId,
          initialTitle: initialTitle,
          initialDescription: initialDescription,
          initialType: initialType,
          initialVideoUrl: initialVideoUrl,
          initialVideoPublicId: initialVideoPublicId,
          initialVideos: initialVideos,
          initialRapidRecalls: initialRapidRecalls,
          initialThumbnailUrl: initialThumbnailUrl,
          initialThumbnailPublicId: initialThumbnailPublicId,
          initialNoteUrl: initialNoteUrl,
          initialNotePublicId: initialNotePublicId,
          initialNoteFileType: initialNoteFileType,
          initialQuizId: initialQuizId,
          initialQuizTitle: initialQuizTitle,
          initialIsFreePreview: initialIsFreePreview,
          initialAccessType: initialAccessType,
          initialStatus: initialStatus, // NEW
          initialPlanIds: initialPlanIds, // NEW
          initialPlans: initialPlans, // NEW
          initialDisplayOrder: initialDisplayOrder,
          initialSubjectId: initialSubjectId,
        ),
      );
    },
  );
}

/// One row of the Videos list while the sheet is open.
///
/// Controllers rather than plain strings: each row is two text fields, and a
/// row that is deleted has to dispose its own.
class _VideoDraft {
  final TextEditingController title;
  final TextEditingController url;

  /// Carried through untouched so re-saving a lesson does not orphan an
  /// uploaded video on Cloudinary, or lose a length the server already knows.
  final String? videoPublicId;
  final int? durationSeconds;

  _VideoDraft({String? title, String? url, this.videoPublicId, this.durationSeconds})
      : title = TextEditingController(text: title ?? ''),
        url = TextEditingController(text: url ?? '');

  factory _VideoDraft.from(LessonVideo v) => _VideoDraft(
        title: v.title,
        url: v.videoUrl,
        videoPublicId: v.videoPublicId,
        durationSeconds: v.durationSeconds,
      );

  bool get isEmpty => url.text.trim().isEmpty && title.text.trim().isEmpty;

  /// Null for a row with no link — an empty row the admin added and left
  /// alone is dropped on save rather than failing it.
  Map<String, dynamic>? toJson() {
    final link = url.text.trim();
    if (link.isEmpty) return null;
    final name = title.text.trim();
    return {
      'videoUrl': link,
      if (name.isNotEmpty) 'title': name,
      // Only meaningful while the link is the one it was uploaded for.
      if (videoPublicId != null && videoPublicId!.isNotEmpty) 'videoPublicId': videoPublicId,
      if (durationSeconds != null) 'durationSeconds': durationSeconds,
    };
  }

  void dispose() {
    title.dispose();
    url.dispose();
  }
}

class _AddEditLessonSheet extends StatefulWidget {
  final int chapterId;
  final int? courseId;

  /// Whether the course this lesson sits in is premium.
  ///
  /// It decides what "free" means for a lesson: on a free course nothing is
  /// gated, so the tick is just `accessType: free`; on a premium course the
  /// same tick is a free preview, which is the flag the student app reads to
  /// let a lesson through an otherwise paid course. Null means the caller did
  /// not know, and then the lesson keeps whatever preview flag it already had.
  final bool? coursePremium; // NEW
  final int? lessonId;
  final String? initialTitle;
  final String? initialDescription;
  final LessonType? initialType;
  final String? initialVideoUrl;
  final String? initialVideoPublicId;
  final List<LessonVideo> initialVideos;
  final List<LessonDeck> initialRapidRecalls;
  final String? initialThumbnailUrl;
  final String? initialThumbnailPublicId;
  final String? initialNoteUrl;
  final String? initialNotePublicId;
  final String? initialNoteFileType;
  final int? initialQuizId;
  final String? initialQuizTitle;
  final bool? initialIsFreePreview;
  final LessonAccessType? initialAccessType;
  final LessonStatus? initialStatus; // NEW
  final Set<int> initialPlanIds; // NEW
  final List<LessonPlanSummary> initialPlans; // NEW
  final int? initialDisplayOrder;
  final int? initialSubjectId;

  const _AddEditLessonSheet({
    required this.chapterId,
    this.courseId,
    this.coursePremium, // NEW
    this.lessonId,
    this.initialTitle,
    this.initialDescription,
    this.initialType,
    this.initialVideoUrl,
    this.initialVideoPublicId,
    this.initialVideos = const [],
    this.initialRapidRecalls = const [],
    this.initialThumbnailUrl,
    this.initialThumbnailPublicId,
    this.initialNoteUrl,
    this.initialNotePublicId,
    this.initialNoteFileType,
    this.initialQuizId,
    this.initialQuizTitle,
    this.initialIsFreePreview,
    this.initialAccessType,
    this.initialStatus, // NEW
    this.initialPlanIds = const {}, // NEW
    this.initialPlans = const [], // NEW
    this.initialDisplayOrder,
    this.initialSubjectId,
  });

  @override
  State<_AddEditLessonSheet> createState() => _AddEditLessonSheetState();
}

class _AddEditLessonSheetState extends State<_AddEditLessonSheet> {
  final _formKey = GlobalKey<FormState>();
  final _uploadService = LessonUploadService();

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  LessonType _type = LessonType.video;
  /// No longer editable here - see the build method. Kept so a save resends
  /// what the lesson already had rather than quietly closing a free preview
  /// that students were relying on.
  late bool _isFreePreview;
  /// Free or premium, as one switch on the lesson itself.
  ///
  /// There is no plan picker beside it: the plan's entitlements decide which
  /// premium lessons a subscription opens - `video_lecture` for a video, `mcq`
  /// for a quiz - so naming plans here would be a second answer to a question
  /// the plan already answers.
  late LessonAccessType _accessType;
  late LessonStatus _status; // NEW

  /// Not editable here any more. It tagged a lesson for one filter in the
  /// Rapid Recall form and asked every admin about it on the way past. Kept so
  /// a save resends what the lesson already had rather than untagging it.
  int? _subjectId;

  // Premium plan picker - a lesson can require any number of plans; empty
  // means "any active subscription".
  late Set<int> _planIds;

  /// The Videos section. A lesson may hold any number, in this order, and a
  /// lesson with none is valid — that is a quiz-only lesson.
  final List<_VideoDraft> _videos = [];

  String? _thumbnailUrl;
  String? _thumbnailPublicId;
  String? _pickedThumbnailName;
  bool _isUploadingThumbnail = false;
  String? _thumbnailUploadError;
  bool _thumbnailRemoved = false;

  String? _noteUrl;
  String? _notePublicId;
  String? _noteFileType;
  bool _isUploadingNote = false;
  bool _noteRemoved = false;

  // ── Quiz ─────────────────────────────────────────────────────────
  // Three separate records, in this order:
  //   question -> lives in the bank (subject + topic)
  //   quiz     -> a filter that matches questions   POST /api/quizzes
  //   lesson   -> what a student opens              PUT  /api/lessons/:id
  // Skipping the third leaves a quiz no student can reach, which is why the
  // save always links as well as creates.
  final _quizService = QuizService();

  final _syncService = SheetQuestionSyncService();

  /// What the picker currently has, read live from the spreadsheet. Null on an
  /// edit that left the existing link alone, which is why [_linkedQuizId] is
  /// tracked separately.
  SheetQuizSelection? _quizDraft;

  /// Progress line while the selected rows are pushed into the bank.
  String? _syncStatus;

  /// The quiz already on this lesson. Kept when the admin doesn't re-pick.
  int? _linkedQuizId;

  bool _isCreatingQuiz = false;
  String? _quizValidationError;

  bool get _isQuiz => _type == LessonType.quiz;

  /// Whether the lesson arrived with a quiz. Needed to tell "left alone" from
  /// "cleared", which the API spells as an absent key versus an explicit null.
  bool _hadQuiz = false;

  String? _freshThumbnailPublicId;
  String? _freshNotePublicId;

  bool get _isEditMode => widget.lessonId != null;

  bool get _hadInitialThumbnail =>
      widget.initialThumbnailUrl != null || widget.initialThumbnailPublicId != null;


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
    _subjectId = widget.initialSubjectId;
    _planIds = {...widget.initialPlanIds}; // NEW

    // The list wins where the caller knows it; otherwise the lesson's single
    // videoUrl becomes row 1, so an older caller still opens the sheet filled.
    if (widget.initialVideos.isNotEmpty) {
      _videos.addAll(widget.initialVideos.map(_VideoDraft.from));
    } else if ((widget.initialVideoUrl ?? '').trim().isNotEmpty) {
      _videos.add(_VideoDraft(
        url: widget.initialVideoUrl,
        videoPublicId: widget.initialVideoPublicId,
      ));
    }

    _thumbnailUrl = widget.initialThumbnailUrl;
    _thumbnailPublicId = widget.initialThumbnailPublicId;

    _noteUrl = widget.initialNoteUrl;
    _notePublicId = widget.initialNotePublicId;
    _noteFileType = widget.initialNoteFileType;

    _linkedQuizId = widget.initialQuizId;
    _hadQuiz = widget.initialQuizId != null;

  }

  @override
  void dispose() {
    // Sheet dismissed without a successful save - every upload made here is
    // unreferenced. Fire-and-forget through the service, not the provider:
    // ChangeNotifierProvider is tearing the provider down right now and its
    // notifyListeners() would throw.
    _discardOrphan(_freshThumbnailPublicId, _uploadService.deleteThumbnail);
    _discardOrphan(_freshNotePublicId, _uploadService.deleteNote);

    _titleController.dispose();
    _descriptionController.dispose();
    for (final v in _videos) {
      v.dispose();
    }
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

  void _addVideo() => setState(() => _videos.add(_VideoDraft()));

  void _removeVideo(int index) {
    setState(() => _videos.removeAt(index).dispose());
  }

  /// Up and down rather than drag: the sheet is already a scroll view, and a
  /// reorderable list inside one is a fight over the same gesture.
  void _moveVideo(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _videos.length) return;
    setState(() => _videos.insert(target, _videos.removeAt(index)));
  }

  /// Every row that has a link, in order. Rows left completely blank are
  /// dropped — an admin who hit "Add video" and changed their mind has not
  /// made a mistake worth blocking the save for.
  List<Map<String, dynamic>> get _videoPayload =>
      [for (final v in _videos) v.toJson()].whereType<Map<String, dynamic>>().toList();

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

  /// Switching the primary type. The media tiles are hidden on a quiz
  /// lesson, so this only has to rebuild.
  void _onTypeChanged(LessonType type) {
    if (type == _type) return;
    setState(() {
      _type = type;
      _quizValidationError = null;
    });
  }

  void _onQuizDraftChanged(SheetQuizSelection? draft) {
    setState(() {
      _quizDraft = draft;
      if (draft != null) _quizValidationError = null;
    });
  }

  /// Carries the picked spreadsheet rows into the API, then builds the quiz
  /// that serves them.
  ///
  /// Three writes, in an order the later ones depend on:
  ///   1. the sheet's subject/topic names resolve to database ids
  ///      (POST /api/subjects, POST /api/subjects/:id/topics when missing)
  ///   2. each picked row becomes a question    POST /api/questions
  ///   3. a quiz filters that subject + topic   POST /api/quizzes
  /// The lesson then links the quiz, which is what makes it reachable to a
  /// student. Returns null when any step failed, so the save aborts instead of
  /// writing a quiz lesson that serves nothing.
  Future<int?> _syncAndCreateQuiz(
      SheetQuizSelection selection, String lessonTitle) async {
    setState(() {
      _isCreatingQuiz = true;
      _syncStatus = 'Reading "${selection.tab}" and saving its questions...';
      _quizValidationError = null;
    });

    final sync = await _syncService.sync(
      subjectName: selection.subject,
      topicName: selection.topic,
      rows: selection.questions,
    );

    if (!mounted) return null;

    if (!sync.isSuccess) {
      setState(() {
        _isCreatingQuiz = false;
        _syncStatus = null;
        _quizValidationError = sync.errorMessage;
      });
      return null;
    }

    // Every row was rejected, so the quiz would filter over nothing.
    if (sync.total == 0) {
      setState(() {
        _isCreatingQuiz = false;
        _syncStatus = null;
        _quizValidationError = sync.skipped.isEmpty
            ? 'No questions were saved, so this quiz would serve nothing.'
            : 'None of the selected rows could be saved:\n'
                '${sync.skipped.take(3).join('\n')}';
      });
      return null;
    }

    setState(() => _syncStatus =
        '${sync.created} saved, ${sync.alreadyPresent} already there. '
        'Creating the quiz...');

    final result = await _quizService.create(Quiz(
      id: 0, // server-assigned; toPayload() never sends it
      title: lessonTitle.isEmpty ? selection.tab : lessonTitle,
      subjectId: sync.subjectId!,
      topicId: sync.topicId!,
      questionCount: sync.total,
    ));

    if (!mounted) return null;
    setState(() {
      _isCreatingQuiz = false;
      _syncStatus = null;
    });

    if (result.isSuccess && result.quiz != null) {
      if (sync.skipped.isNotEmpty) {
        _showSkipped(sync.skipped);
      }
      return result.quiz!.id;
    }

    setState(() => _quizValidationError =
        result.errorMessage ?? 'Failed to create the quiz');
    return null;
  }

  /// Rows the API refused. The lesson still saved, so this is a notice rather
  /// than an error - but a silently missing question is invisible.
  void _showSkipped(List<String> skipped) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        backgroundColor: LmsColors.error,
        content: Text(
          '${skipped.length} sheet row${skipped.length == 1 ? '' : 's'} '
          'could not be saved:\n${skipped.take(3).join('\n')}'
          '${skipped.length > 3 ? '\n...and ${skipped.length - 3} more' : ''}',
          style: const TextStyle(fontSize: 12.5),
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isUploadingThumbnail || _isUploadingNote) return;

    if (_isCreatingQuiz) return;

    final provider = context.read<LessonUpdateProvider>();
    final title = _titleController.text.trim();

    // A quiz-type lesson still has to point at a quiz — that is the whole of
    // what it serves. On any other type the quiz is an extra, so an empty
    // picker is not an error.
    if (_isQuiz && _quizDraft == null && _linkedQuizId == null) {
      setState(() => _quizValidationError =
          'Pick a subject and topic with at least one active question.');
      return;
    }
    // Built whenever the picker has something, whatever the lesson leads
    // with: a video lesson can carry a quiz now.
    final draft = _quizDraft;
    if (draft != null) {
      final quizId = await _syncAndCreateQuiz(draft, title);
      if (quizId == null) return; // message already on screen
      _linkedQuizId = quizId;
    }
    // Free on a premium course is a free preview: same tick, and the server
    // reads two fields. Sent on every save, true and false alike - omitting it
    // on an edit would leave a lesson open after it was switched to premium.
    final bool freePreview = lessonFreePreview(
      coursePremium: widget.coursePremium,
      isFree: _accessType == LessonAccessType.free,
      current: _isFreePreview,
    );

    final description = _descriptionController.text.trim();

    final bool removeDescription =
        _isEditMode && _hadInitialDescription && description.isEmpty;

    // Media and the quiz are no longer mutually exclusive — a lesson holds
    // its videos, its quiz and its decks together. The link is nulled only
    // when the admin actually cleared it.
    final bool removeQuiz = _hadQuiz && _linkedQuizId == null;

    final bool success = _isEditMode
        ? await provider.updateLesson(
      chapterId: widget.chapterId,
      lessonId: widget.lessonId!,
      title: title,
      description: description.isEmpty ? null : description,
      removeDescription: removeDescription,
      type: _type,
      // Always the whole list: the section is on screen on every save, so
      // what it shows is what the lesson should end up with.
      videos: _videoPayload,
      thumbnailUrl: _thumbnailUrl,
      thumbnailPublicId: _thumbnailPublicId,
      removeThumbnail: _thumbnailRemoved,
      noteUrl: _noteUrl,
      notePublicId: _notePublicId,
      noteFileType: _noteFileType,
      removeNote: _noteRemoved,
      isFreePreview: freePreview,
      accessType: _accessType,
      status: _status,
      planIds: _planIds.toList(),
      quizId: _linkedQuizId,
      removeQuiz: removeQuiz,
      subjectId: _subjectId,
      // Cleared rather than omitted: an absent key leaves the old subject.
      removeSubject: _subjectId == null && widget.initialSubjectId != null,
    )
        : await provider.createLesson(
      chapterId: widget.chapterId,
      title: title,
      description: description.isEmpty ? null : description,
      type: _type,
      videos: _videoPayload,
      thumbnailUrl: _thumbnailUrl,
      thumbnailPublicId: _thumbnailPublicId,
      noteUrl: _noteUrl,
      notePublicId: _notePublicId,
      noteFileType: _noteFileType,
      displayOrder: widget.initialDisplayOrder,
      isFreePreview: freePreview,
      accessType: _accessType,
      status: _status,
      planIds: _planIds.toList(),
      quizId: _linkedQuizId,
      subjectId: _subjectId,
    );

    if (!mounted) return;
    if (success) {
      // Persisted onto the lesson — dispose() must not delete them. Media is
      // sent on every type now, so there is no case left where an upload made
      // here ends up unreferenced.
      _freshThumbnailPublicId = null;
      _freshNotePublicId = null;
      Navigator.pop(context, true);
    }
  }

  /// One row of the Videos list: an optional name, the link, and the three
  /// things you can do to it.
  Widget _videoRow(int index) {
    final draft = _videos[index];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
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
              Text(
                'Video ${index + 1}',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: LmsColors.textGrey),
              ),
              if (draft.durationSeconds != null) ...[
                const SizedBox(width: 8),
                Text(
                  LessonVideo(
                    videoUrl: '',
                    durationSeconds: draft.durationSeconds,
                  ).lengthLabel ?? '',
                  style: const TextStyle(
                      fontSize: 11.5, color: LmsColors.textGrey),
                ),
              ],
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                tooltip: 'Move up',
                visualDensity: VisualDensity.compact,
                onPressed: index == 0 ? null : () => _moveVideo(index, -1),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_downward_rounded, size: 16),
                tooltip: 'Move down',
                visualDensity: VisualDensity.compact,
                onPressed: index == _videos.length - 1
                    ? null
                    : () => _moveVideo(index, 1),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 16, color: LmsColors.error),
                tooltip: 'Remove video',
                visualDensity: VisualDensity.compact,
                onPressed: () => _removeVideo(index),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: draft.title,
            decoration: _inputDecoration('Title · optional, e.g. "Part 1"'),
            style: const TextStyle(fontSize: 13.5),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: draft.url,
            keyboardType: TextInputType.url,
            decoration: _inputDecoration(
              'https://youtube.com/watch?v=... or https://.../video.mp4',
              icon: Icons.link_rounded,
            ),
            style: const TextStyle(fontSize: 13.5),
            validator: (value) {
              final v = value?.trim() ?? '';
              // A row left completely blank is dropped on save, so it is not
              // worth refusing. One with a name but no link is a mistake.
              if (v.isEmpty) {
                return draft.title.text.trim().isEmpty
                    ? null
                    : 'Add the link, or remove this row';
              }
              final uri = Uri.tryParse(v);
              if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
                return 'Enter a valid link, starting with https://';
              }
              return null;
            },
          ),
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LessonUpdateProvider>();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bool canSave = !provider.isUpdating &&
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
                  // Notes lessons can no longer be created here. A lesson that
                  // already is one keeps its chip, so editing it shows what it
                  // is instead of quietly turning it into a video lesson.
                  children: LessonType.values
                      .where((t) =>
                          t != LessonType.text ||
                          widget.initialType == LessonType.text)
                      .map((t) {
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
                const SizedBox(height: 18),

                // Reads as one decision about this lesson, not a pricing
                // model: which plan opens it is the plan's business.
                _FreeSwitch(
                  isFree: _accessType == LessonAccessType.free,
                  type: _type,
                  coursePremium: widget.coursePremium ?? false,
                  onChanged: (free) => setState(() => _accessType =
                      free ? LessonAccessType.free : LessonAccessType.premium),
                ),

                // Only on a quiz lesson. A video lesson is a video and its
                // cover - the picker in the middle of that form was a question
                // nobody adding a class wanted to answer.
                if (_isQuiz) ...[
                  const SizedBox(height: 18),
                  _FieldLabel(_isQuiz ? 'Quiz' : 'Quiz (optional)'),
                  const SizedBox(height: 2),
                  Text(
                    _isQuiz
                        ? 'The questions this lesson serves.'
                        : 'A quiz students take inside this lesson, after the '
                            'videos.',
                    style: const TextStyle(
                        fontSize: 11.5, color: LmsColors.textGrey),
                  ),
                  if (_linkedQuizId != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.quiz_outlined,
                            size: 16, color: LmsColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.initialQuizTitle ?? 'Quiz #$_linkedQuizId',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              setState(() => _linkedQuizId = null),
                          child: const Text('Remove',
                              style: TextStyle(
                                  fontSize: 12.5, color: LmsColors.error)),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  SheetQuizPicker(
                    onChanged: _onQuizDraftChanged,
                    validationError: _quizValidationError,
                  ),
                  if (_syncStatus != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _syncStatus!,
                            style: const TextStyle(
                                fontSize: 12, color: LmsColors.textGrey),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                ],

                // Not on a quiz lesson. What a quiz serves is its questions;
                // a cover image and a video link in the same form are two
                // more fields to scroll past and leave empty.
                if (!_isQuiz) ...[
                // The chips above end flush; without this the next label sat
                // right against them.
                const SizedBox(height: 18),
                const _FieldLabel('Cover image (optional)'),
                const SizedBox(height: 2),
                const Text(
                  'Shown on the lesson card students tap. A wide 16:9 image '
                  'looks best.',
                  style: TextStyle(fontSize: 11.5, color: LmsColors.textGrey),
                ),
                const SizedBox(height: 8),
                _UploadTile(
                  icon: Icons.add_photo_alternate_outlined,
                  color: const Color(0xFF14A38B),
                  isUploading: _isUploadingThumbnail,
                  hasFile: _thumbnailUrl != null,
                  fileLabel: _pickedThumbnailName ??
                      (_thumbnailUrl != null ? 'Current cover image' : null),
                  title: 'Add a cover image',
                  subtitle: 'JPG, PNG or WebP',
                  errorMessage: _thumbnailUploadError,
                  onPick: _pickThumbnail,
                  onRetry: _pickThumbnail,
                  onRemove: _removeThumbnail,
                  previewImage: _thumbnailUrl != null
                      ? Image.network(
                          _thumbnailUrl!,
                          fit: BoxFit.cover,
                          // Rendered through an <img> element, so a host without
                          // CORS headers still shows the picture.
                          webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                          errorBuilder: (_, _, _) => const Center(
                            child: Icon(Icons.broken_image_outlined,
                                size: 28, color: LmsColors.textGrey),
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 18),

                // Videos are added by link only - there is no file upload.
                // A lesson whose video was uploaded before keeps it: the row
                // opens filled with that video's address and resends its
                // publicId.
                Row(
                  children: [
                    const Expanded(child: _FieldLabel('Videos (optional)')),
                    TextButton.icon(
                      onPressed: _addVideo,
                      icon: const Icon(Icons.add_rounded, size: 17),
                      label: const Text('Add video',
                          style: TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w700)),
                      style: TextButton.styleFrom(
                          foregroundColor: LmsColors.primary),
                    ),
                  ],
                ),
                const Text(
                  'Paste a YouTube link or a direct link to the video file. '
                  'Add as many as the lesson needs — the order here is the '
                  'order students get.',
                  style: TextStyle(fontSize: 11.5, color: LmsColors.textGrey),
                ),
                const SizedBox(height: 8),
                if (_videos.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: LmsColors.bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: LmsColors.border),
                    ),
                    child: const Text(
                      'No videos yet. A lesson can be quiz-only.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, color: LmsColors.textGrey),
                    ),
                  )
                else
                  for (int i = 0; i < _videos.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _videoRow(i),
                    ),
                // No notes upload here any more. A lesson that already has a
                // note keeps it: _noteUrl is resent unchanged on save.
                const SizedBox(height: 16),

                // Read-only: a deck is created on the Rapid Recall screen,
                // which already asks which lesson it belongs to. Shown even
                // when empty so an admin knows the slot exists.
                const _FieldLabel('Rapid Recall decks'),
                const SizedBox(height: 2),
                const Text(
                  'Filed against this lesson on the Rapid Recall screen.',
                  style: TextStyle(fontSize: 11.5, color: LmsColors.textGrey),
                ),
                const SizedBox(height: 8),
                if (widget.initialRapidRecalls.isEmpty)
                  const Text(
                    'No revision decks filed against this lesson yet.',
                    style: TextStyle(fontSize: 12.5, color: LmsColors.textGrey),
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final deck in widget.initialRapidRecalls)
                        LessonBadge(
                          icon: Icons.style_outlined,
                          label: deck.title,
                          color: deck.status == 'published'
                              ? LmsColors.success
                              : LmsColors.textGrey,
                          compact: true,
                        ),
                    ],
                  ),
                const SizedBox(height: 16),
                ],

                // Everything about who can see this lesson - access type, the
                // required plans and the free-preview exception - is decided
                // once, on the course. None of it is per video, per quiz or
                // per note any more.

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

