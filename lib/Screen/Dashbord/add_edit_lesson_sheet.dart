import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theam/theam_dart.dart';
import '../../provider/lesson_upload_provider.dart';
import '../../services/lesson_services.dart';
import '../../services/lesson_upload_service.dart';

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
  final Widget? previewImage; // NEW - optional thumbnail preview shown instead of an icon+label

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
      String? initialContent, // quiz reference
      bool? initialIsFreePreview,
      LessonAccessType? initialAccessType,
      int? initialDisplayOrder,
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
          initialIsFreePreview: initialIsFreePreview,
          initialAccessType: initialAccessType,
          initialDisplayOrder: initialDisplayOrder,
        ),
      );
    },
  );
}

/// How the video source is being provided for this lesson.
enum _VideoSourceMode { upload, url }

class _AddEditLessonSheet extends StatefulWidget {
  final int chapterId;
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
  final bool? initialIsFreePreview;
  final LessonAccessType? initialAccessType;
  final int? initialDisplayOrder;

  const _AddEditLessonSheet({
    required this.chapterId,
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
    this.initialIsFreePreview,
    this.initialAccessType,
    this.initialDisplayOrder,
  });

  @override
  State<_AddEditLessonSheet> createState() => _AddEditLessonSheetState();
}

class _AddEditLessonSheetState extends State<_AddEditLessonSheet> {
  final _formKey = GlobalKey<FormState>();
  final _uploadService = LessonUploadService();

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController; // NEW
  late final TextEditingController _quizRefController;
  late final TextEditingController _videoUrlController;
  LessonType _type = LessonType.video;
  late bool _isFreePreview;
  late LessonAccessType _accessType;

  // ── Video state ──
  _VideoSourceMode _videoSourceMode = _VideoSourceMode.upload;
  String? _videoUrl;
  String? _videoPublicId;
  String? _pickedVideoName;
  bool _isUploadingVideo = false;
  String? _videoUploadError;
  bool _videoRemoved = false;

  // ── Thumbnail state (NEW) ──
  String? _thumbnailUrl;
  String? _thumbnailPublicId;
  String? _pickedThumbnailName;
  bool _isUploadingThumbnail = false;
  String? _thumbnailUploadError;
  bool _thumbnailRemoved = false;

  // ── Note upload state (PDF / DOC / DOCX) ──
  String? _noteUrl;
  String? _notePublicId;
  String? _noteFileType;
  String? _pickedNoteName;
  bool _isUploadingNote = false;
  String? _noteUploadError;
  bool _noteRemoved = false;

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
    _quizRefController = TextEditingController(text: widget.initialContent ?? '');
    _type = widget.initialType ?? LessonType.video;
    _isFreePreview = widget.initialIsFreePreview ?? false;
    _accessType = widget.initialAccessType ?? LessonAccessType.free;

    _videoUrl = widget.initialVideoUrl;
    _videoPublicId = widget.initialVideoPublicId;
    _videoUrlController = TextEditingController(text: widget.initialVideoUrl ?? '');

    // If a lesson already has a video URL but no publicId (i.e. it wasn't
    // uploaded through this picker — it was pasted or came from elsewhere),
    // default the toggle to URL mode so editing feels natural.
    if (widget.initialVideoUrl != null && widget.initialVideoPublicId == null) {
      _videoSourceMode = _VideoSourceMode.url;
    }

    _thumbnailUrl = widget.initialThumbnailUrl;
    _thumbnailPublicId = widget.initialThumbnailPublicId;

    _noteUrl = widget.initialNoteUrl;
    _notePublicId = widget.initialNotePublicId;
    _noteFileType = widget.initialNoteFileType;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _quizRefController.dispose();
    _videoUrlController.dispose();
    super.dispose();
  }

  // ── Video: pick + upload ──
  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: true, // REQUIRED on web (Chrome) — gives bytes instead of a path
    );
    if (result == null || result.files.single.bytes == null) return;

    final Uint8List bytes = result.files.single.bytes!;
    final String name = result.files.single.name;

    setState(() {
      _pickedVideoName = name;
      _isUploadingVideo = true;
      _videoUploadError = null;
      _videoRemoved = false;
    });

    final uploadResult = await _uploadService.uploadVideo(bytes, name);

    if (!mounted) return;
    setState(() {
      _isUploadingVideo = false;
      if (uploadResult.isSuccess) {
        _videoUrl = uploadResult.url;
        _videoPublicId = uploadResult.publicId;
      } else {
        _videoUploadError = uploadResult.errorMessage;
      }
    });
  }

  void _removeVideo() {
    setState(() {
      _videoUrl = null;
      _videoPublicId = null;
      _pickedVideoName = null;
      _videoUploadError = null;
      _videoUrlController.clear();
      _videoRemoved = _isEditMode && _hadInitialVideo;
    });
  }

  void _setVideoSourceMode(_VideoSourceMode mode) {
    if (mode == _videoSourceMode) return;
    setState(() {
      _videoSourceMode = mode;
      _videoUrl = null;
      _videoPublicId = null;
      _pickedVideoName = null;
      _videoUploadError = null;
      _videoUrlController.clear();
      _videoRemoved = _isEditMode && _hadInitialVideo;
    });
  }

  void _onVideoUrlChanged(String value) {
    final trimmed = value.trim();
    setState(() {
      _videoUrl = trimmed.isEmpty ? null : trimmed;
      _videoPublicId = null;
      _videoRemoved = trimmed.isEmpty && _isEditMode && _hadInitialVideo;
    });
  }

  // ── Thumbnail: pick + upload (NEW) ──
  Future<void> _pickThumbnail() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true, // REQUIRED on web (Chrome) — gives bytes instead of a path
    );
    if (result == null || result.files.single.bytes == null) return;

    final Uint8List bytes = result.files.single.bytes!;
    final String name = result.files.single.name;

    setState(() {
      _pickedThumbnailName = name;
      _isUploadingThumbnail = true;
      _thumbnailUploadError = null;
      _thumbnailRemoved = false;
    });

    final uploadResult = await _uploadService.uploadThumbnail(bytes, name);

    if (!mounted) return;
    setState(() {
      _isUploadingThumbnail = false;
      if (uploadResult.isSuccess) {
        _thumbnailUrl = uploadResult.url;
        _thumbnailPublicId = uploadResult.publicId;
      } else {
        _thumbnailUploadError = uploadResult.errorMessage;
      }
    });
  }

  void _removeThumbnail() {
    setState(() {
      _thumbnailUrl = null;
      _thumbnailPublicId = null;
      _pickedThumbnailName = null;
      _thumbnailUploadError = null;
      _thumbnailRemoved = _isEditMode && _hadInitialThumbnail;
    });
  }

  // ── Note: pick + upload (PDF / DOC / DOCX) ──
  Future<void> _pickNote() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    final Uint8List bytes = result.files.single.bytes!;
    final String name = result.files.single.name;

    setState(() {
      _pickedNoteName = name;
      _isUploadingNote = true;
      _noteUploadError = null;
      _noteRemoved = false;
    });

    final uploadResult = await _uploadService.uploadNote(bytes, name);

    if (!mounted) return;
    setState(() {
      _isUploadingNote = false;
      if (uploadResult.isSuccess) {
        _noteUrl = uploadResult.url;
        _notePublicId = uploadResult.publicId;
        _noteFileType = uploadResult.fileType;
      } else {
        _noteUploadError = uploadResult.errorMessage;
      }
    });
  }

  void _removeNote() {
    setState(() {
      _noteUrl = null;
      _notePublicId = null;
      _noteFileType = null;
      _pickedNoteName = null;
      _noteUploadError = null;
      _noteRemoved = _isEditMode && _hadInitialNote;
    });
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isUploadingVideo || _isUploadingThumbnail || _isUploadingNote) return; // block save mid-upload

    final provider = context.read<LessonUpdateProvider>();
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final quizRef = _quizRefController.text.trim();

    // Only mark description for removal if it existed before and is now empty.
    final bool removeDescription =
        _isEditMode && _hadInitialDescription && description.isEmpty;

    final bool success = _isEditMode
        ? await provider.updateLesson(
      chapterId: widget.chapterId,
      lessonId: widget.lessonId!,
      title: title,
      description: description.isEmpty ? null : description,
      removeDescription: removeDescription,
      type: _type,
      videoUrl: _videoUrl,
      videoPublicId: _videoPublicId,
      removeVideo: _videoRemoved,
      thumbnailUrl: _thumbnailUrl,
      thumbnailPublicId: _thumbnailPublicId,
      removeThumbnail: _thumbnailRemoved,
      noteUrl: _noteUrl,
      notePublicId: _notePublicId,
      noteFileType: _noteFileType,
      removeNote: _noteRemoved,
      content: quizRef.isEmpty ? null : quizRef,
      isFreePreview: _isFreePreview,
      accessType: _accessType,
    )
        : await provider.createLesson(
      chapterId: widget.chapterId,
      title: title,
      description: description.isEmpty ? null : description,
      type: _type,
      videoUrl: _videoUrl,
      videoPublicId: _videoPublicId,
      thumbnailUrl: _thumbnailUrl,
      thumbnailPublicId: _thumbnailPublicId,
      noteUrl: _noteUrl,
      notePublicId: _notePublicId,
      noteFileType: _noteFileType,
      content: quizRef.isEmpty ? null : quizRef,
      displayOrder: widget.initialDisplayOrder,
      isFreePreview: _isFreePreview,
      accessType: _accessType,
    );

    if (!mounted) return;
    if (success) Navigator.pop(context, true);
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

  /// Small segmented toggle used to pick "Upload" vs "Paste URL".
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

                // ── Description (NEW) ──
                const _FieldLabel('Description (optional)'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  minLines: 2,
                  decoration: _inputDecoration('Briefly describe what this lesson covers'),
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
                      onSelected: (_) => setState(() => _type = t),
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
                //const SizedBox(height: 18),

                //── Thumbnail (NEW) ──
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

                // ── Video: upload OR paste URL ──
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
                      if (v.isEmpty) return null; // video is optional
                      final uri = Uri.tryParse(v);
                      if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
                        return 'Enter a valid URL';
                      }
                      return null;
                    },
                  ),
                const SizedBox(height: 16),

                // ── Note upload (PDF / DOC / DOCX) ──
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

                if (_type == LessonType.quiz) ...[
                  const _FieldLabel('Quiz Reference'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _quizRefController,
                    decoration: _inputDecoration('Question bank / quiz ID', icon: Icons.quiz_outlined),
                  ),
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
                        onSelected: (_) => setState(() => _accessType = a),
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




/// Shows a confirmation dialog, then deletes the lesson via
/// [LessonUpdateProvider] if confirmed. Returns true if the lesson was
/// deleted, false/null otherwise — use the return value to remove the row
/// from your list or trigger a refresh.
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

/// Edit + Delete icon buttons for a lesson row in your listing UI.
class LessonRowActions extends StatefulWidget {
  final int chapterId;
  final int lessonId;
  final String title;
  final String? description;
  final LessonType type;
  final String? videoUrl;
  final String? videoPublicId;
  final String? thumbnailUrl;
  final String? thumbnailPublicId;
  final String? noteUrl;
  final String? notePublicId;
  final String? noteFileType;
  final String? content;
  final bool isFreePreview;
  final LessonAccessType accessType;
  final int displayOrder;

  /// Called after a successful edit or delete so the parent list can refresh.
  final VoidCallback onChanged;

  const LessonRowActions({
    super.key,
    required this.chapterId,
    required this.lessonId,
    required this.title,
    this.description,
    required this.type,
    this.videoUrl,
    this.videoPublicId,
    this.thumbnailUrl,
    this.thumbnailPublicId,
    this.noteUrl,
    this.notePublicId,
    this.noteFileType,
    this.content,
    required this.isFreePreview,
    required this.accessType,
    required this.displayOrder,
    required this.onChanged,
  });

  @override
  State<LessonRowActions> createState() => _LessonRowActionsState();
}

class _LessonRowActionsState extends State<LessonRowActions> {
  bool _isDeleting = false;

  Future<void> _handleEdit() async {
    final result = await showAddEditLessonSheet(
      context,
      chapterId: widget.chapterId,
      lessonId: widget.lessonId,
      initialTitle: widget.title,
      initialDescription: widget.description,
      initialType: widget.type,
      initialVideoUrl: widget.videoUrl,
      initialVideoPublicId: widget.videoPublicId,
      initialThumbnailUrl: widget.thumbnailUrl,
      initialThumbnailPublicId: widget.thumbnailPublicId,
      initialNoteUrl: widget.noteUrl,
      initialNotePublicId: widget.notePublicId,
      initialNoteFileType: widget.noteFileType,
      initialContent: widget.content,
      initialIsFreePreview: widget.isFreePreview,
      initialAccessType: widget.accessType,
      initialDisplayOrder: widget.displayOrder,
    );
    if (result == true) widget.onChanged();
  }

  Future<void> _handleDelete() async {
    setState(() => _isDeleting = true);
    final deleted = await confirmAndDeleteLesson(
      context,
      chapterId: widget.chapterId,
      lessonId: widget.lessonId,
      lessonTitle: widget.title,
    );
    if (!mounted) return;
    setState(() => _isDeleting = false);
    if (deleted) widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 19, color: LmsColors.textGrey),
          onPressed: _isDeleting ? null : _handleEdit,
          tooltip: 'Edit lesson',
        ),
        _isDeleting
            ? const SizedBox(
          width: 40,
          height: 40,
          child: Padding(
            padding: EdgeInsets.all(11),
            child: CircularProgressIndicator(strokeWidth: 2, color: LmsColors.error),
          ),
        )
            : IconButton(
          icon: const Icon(Icons.delete_outline_rounded, size: 19, color: LmsColors.error),
          onPressed: _handleDelete,
          tooltip: 'Delete lesson',
        ),
      ],
    );
  }
}