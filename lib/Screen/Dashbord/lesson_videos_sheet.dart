import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/theam/theam_dart.dart';
import '../../services/question_image_service.dart';
import '../../widget/video_access_switch.dart';
import '../../models/lesson_detail_model.dart';
import '../../provider/lesson_upload_provider.dart';

/// Adding videos to a lesson without opening the lesson form.
///
/// The same list the lesson sheet edits and the same request behind it - this
/// just asks the one question, the way Add Lesson asks one question of a
/// chapter.
Future<bool?> showLessonVideosSheet(
  BuildContext context, {
  required int chapterId,
  required int lessonId,
  required String lessonTitle,
  List<LessonVideo> initialVideos = const [],
  bool coursePremium = false,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LessonVideosSheet(
      chapterId: chapterId,
      lessonId: lessonId,
      lessonTitle: lessonTitle,
      initialVideos: initialVideos,
      coursePremium: coursePremium,
    ),
  );
}

class _LessonVideosSheet extends StatefulWidget {
  final int chapterId;
  final int lessonId;
  final String lessonTitle;
  final List<LessonVideo> initialVideos;
  final bool coursePremium;

  const _LessonVideosSheet({
    required this.chapterId,
    required this.lessonId,
    required this.lessonTitle,
    required this.initialVideos,
    required this.coursePremium,
  });

  @override
  State<_LessonVideosSheet> createState() => _LessonVideosSheetState();
}

class _VideoRow {
  final TextEditingController title;
  final TextEditingController url;
  final TextEditingController description;

  /// The still students see before they press play. Uploaded here, so a part
  /// can have its own rather than borrowing the lesson's cover.
  final TextEditingController thumbnail;

  /// Free parts are the sample a paid lesson sells itself with. New rows
  /// start premium: a video must never open itself by default.
  bool free;

  /// Carried through untouched: re-saving must not orphan a video that was
  /// uploaded rather than linked, or lose a length the server already knows.
  final String? videoPublicId;
  final int? durationSeconds;

  _VideoRow({
    String? title,
    String? url,
    String? description,
    String? thumbnail,
    this.videoPublicId,
    this.durationSeconds,
    this.free = false,
  })  : title = TextEditingController(text: title ?? ''),
        url = TextEditingController(text: url ?? ''),
        description = TextEditingController(text: description ?? ''),
        thumbnail = TextEditingController(text: thumbnail ?? '');

  factory _VideoRow.from(LessonVideo v) => _VideoRow(
        title: v.title,
        url: v.videoUrl,
        description: v.description,
        thumbnail: v.thumbnailUrl,
        videoPublicId: v.videoPublicId,
        durationSeconds: v.durationSeconds,
        free: v.isFree,
      );

  /// Null for a row with no link. A row someone added and left alone is
  /// dropped rather than failing the save.
  Map<String, dynamic>? toJson() {
    final link = url.text.trim();
    if (link.isEmpty) return null;
    final name = title.text.trim();
    final blurb = description.text.trim();
    final still = thumbnail.text.trim();
    return {
      'videoUrl': link,
      if (name.isNotEmpty) 'title': name,
      if (blurb.isNotEmpty) 'description': blurb,
      if (still.isNotEmpty) 'thumbnailUrl': still,
      if (videoPublicId != null && videoPublicId!.isNotEmpty)
        'videoPublicId': videoPublicId,
      if (durationSeconds != null) 'durationSeconds': durationSeconds,
      'accessType': free ? 'free' : 'premium',
    };
  }

  void dispose() {
    title.dispose();
    url.dispose();
    description.dispose();
    thumbnail.dispose();
  }
}

class _LessonVideosSheetState extends State<_LessonVideosSheet> {
  final _rows = <_VideoRow>[];

  /// Row keys that no edit can change - a key derived from the row's content
  /// would rebuild the field mid-word and take focus with it.
  final _keys = <_VideoRow, ValueKey<int>>{};
  int _nextKey = 0;

  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _rows.addAll(widget.initialVideos.map(_VideoRow.from));
    // Always one empty row at the bottom, titled for the part it will be.
    // The sheet opens where the work is: paste, save.
    _rows.add(_newRow());
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  ValueKey<int> _keyFor(_VideoRow row) =>
      _keys.putIfAbsent(row, () => ValueKey(_nextKey++));

  /// One tint per part, cycled. Four identical grey cards are a wall; a
  /// different wash on each makes "the third one" findable.
  static const _tints = [
    Color(0xFFEFF4FF),
    Color(0xFFF1FAF4),
    Color(0xFFFFF6EC),
    Color(0xFFF7F0FF),
    Color(0xFFFFF0F3),
  ];
  static const _edges = [
    Color(0xFFBFD3FF),
    Color(0xFFBFE3CC),
    Color(0xFFF2D6AE),
    Color(0xFFDCC8F5),
    Color(0xFFF5C2CD),
  ];

  /// "Part 3" on a lesson that already has two, so the parts number
  /// themselves and the title is one less thing to type.
  _VideoRow _newRow() => _VideoRow(
        title: 'Part ${_rows.length + 1}',
        free: VideoAccessSwitch.defaultFree(
            coursePremium: widget.coursePremium),
      );

  void _add() => setState(() => _rows.add(_newRow()));

  /// Which row's thumbnail is uploading, so only that one shows a spinner.
  int? _uploadingThumbAt;

  Future<void> _pickThumbnail(int index) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: QuestionImageService.allowedExtensions,
      withData: true, // web has no file path to read from
    );
    final file = picked?.files.single;
    if (file == null || file.bytes == null) return;

    setState(() => _uploadingThumbAt = index);
    final result = await QuestionImageService()
        .upload(bytes: file.bytes!, filename: file.name);

    if (!mounted) return;
    setState(() {
      _uploadingThumbAt = null;
      if (result.isSuccess) {
        _rows[index].thumbnail.text = result.image!.url;
        _error = null;
      } else {
        _error = result.errorMessage;
      }
    });
  }

  void _remove(int index) => setState(() {
        final row = _rows.removeAt(index);
        _keys.remove(row);
        row.dispose();
      });

  /// The order on screen is the order students get - the server numbers the
  /// rows from the array it is sent.
  void _move(int index, int by) {
    final target = index + by;
    if (target < 0 || target >= _rows.length) return;
    setState(() => _rows.insert(target, _rows.removeAt(index)));
  }

  /// Rows that actually hold a link - the empty one at the bottom is not a
  /// video until something is pasted into it.
  int get _filledCount =>
      _rows.where((r) => r.url.text.trim().isNotEmpty).length;

  Future<void> _save() async {
    final videos = [for (final r in _rows) r.toJson()]
        .whereType<Map<String, dynamic>>()
        .toList();

    setState(() {
      _isSaving = true;
      _error = null;
    });

    final provider = LessonUpdateProvider();
    // Only the list is sent. Every other field is absent from the body, so
    // nothing else about the lesson changes from here by accident.
    final ok = await provider.updateLesson(
      chapterId: widget.chapterId,
      lessonId: widget.lessonId,
      videos: videos,
    );

    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _isSaving = false;
      _error = provider.errorMessage ?? 'Could not save the videos';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: LmsColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const Text('Videos',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(
              widget.lessonTitle,
              style: const TextStyle(fontSize: 12.5, color: LmsColors.textGrey),
            ),
            const SizedBox(height: 4),
            const Text(
              'Paste a YouTube link or a direct link to the video file. The '
              'order here is the order students get.',
              style: TextStyle(fontSize: 11.5, color: LmsColors.textGrey),
            ),
            const SizedBox(height: 14),

            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [for (var i = 0; i < _rows.length; i++) _row(i)],
                ),
              ),
            ),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isSaving ? null : _add,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add another part',
                    style:
                        TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: LmsColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: const BorderSide(
                      color: LmsColors.primary, style: BorderStyle.solid),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),


            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(_error!,
                  style:
                      const TextStyle(fontSize: 12.5, color: LmsColors.error)),
            ],
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _isSaving ? null : () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      side: const BorderSide(color: LmsColors.border),
                      foregroundColor: LmsColors.textDark,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel',
                        style:
                            TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LmsColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text('Save $_filledCount video'
                            '${_filledCount == 1 ? '' : 's'}',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(int index) {
    final row = _rows[index];

    return Container(
      key: _keyFor(row),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: _tints[index % _tints.length],
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _edges[index % _edges.length]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Part ${index + 1}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: LmsColors.textGrey)),
              const Spacer(),
              IconButton(
                tooltip: 'Move up',
                visualDensity: VisualDensity.compact,
                onPressed: index == 0 ? null : () => _move(index, -1),
                icon: const Icon(Icons.arrow_upward_rounded, size: 16),
              ),
              IconButton(
                tooltip: 'Move down',
                visualDensity: VisualDensity.compact,
                onPressed:
                    index == _rows.length - 1 ? null : () => _move(index, 1),
                icon: const Icon(Icons.arrow_downward_rounded, size: 16),
              ),
              IconButton(
                tooltip: 'Remove',
                visualDensity: VisualDensity.compact,
                onPressed: _rows.length == 1 ? null : () => _remove(index),
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 16, color: LmsColors.error),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6, bottom: 8),
            child: VideoAccessSwitch(
              free: row.free,
              coursePremium: widget.coursePremium,
              enabled: !_isSaving,
              onChanged: (free) => setState(() => row.free = free),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Column(
                    children: [
                      TextField(
                        controller: row.url,
                        autofocus: index == _rows.length - 1 &&
                            row.url.text.trim().isEmpty,
                        // Keeps the Save button's count honest as the link
                        // is pasted.
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(fontSize: 13),
                        decoration: _decoration('Paste the video link'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: row.title,
                        style: const TextStyle(fontSize: 13),
                        decoration: _decoration('Title (optional)'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: row.description,
                        minLines: 2,
                        maxLines: null,
                        style: const TextStyle(fontSize: 13),
                        decoration:
                            _decoration('Description (optional)'),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: row.thumbnail,
                              style: const TextStyle(fontSize: 13),
                              decoration: _decoration(
                                  'Thumbnail link, or upload one'),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _uploadingThumbAt == index
                              ? const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                )
                              : IconButton(
                                  tooltip: 'Upload a thumbnail',
                                  onPressed: _isSaving
                                      ? null
                                      : () => _pickThumbnail(index),
                                  icon: const Icon(
                                      Icons.add_photo_alternate_outlined,
                                      size: 19,
                                      color: LmsColors.primary),
                                ),
                        ],
                      ),
                      if (row.thumbnail.text.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            row.thumbnail.text.trim(),
                            height: 70,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            // Through an <img> element, so a host with no
                            // CORS headers still shows the picture.
                            webHtmlElementStrategy:
                                WebHtmlElementStrategy.prefer,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12.5, color: LmsColors.textGrey),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
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
          borderSide: const BorderSide(color: LmsColors.primary, width: 1.4),
        ),
      );
}
