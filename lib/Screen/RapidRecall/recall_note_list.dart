import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/theam/theam_dart.dart';
import '../../models/rapid_recall_model.dart';
import '../../services/question_image_service.dart';
import '../../widget/question_image_view.dart';

/// The revision notes in a deck, as reorderable rows.
///
/// Every note can carry an image, typed text, or both.
/// **The image is optional** - only a note with nothing in it at all is empty,
/// and an empty row is simply dropped on save.
///
/// They are written and saved together, never one at a time: one Save sends
/// the whole set, so `displayOrder` is the row index and nothing is diffed.
///
/// The position is always named when something is wrong, because a deck of
/// forty is unfixable from a message that only says one note is bad.
///
/// There is no per-card save. Add, edit, remove and reorder all mutate this
/// list and one Save sends the whole array, so `displayOrder` is the index and
/// nothing has to be diffed.
class RecallNoteList extends StatefulWidget {
  final List<RapidRecallCard> cards;
  final ValueChanged<List<RapidRecallCard>> onChanged;
  final bool enabled;

  const RecallNoteList({
    super.key,
    required this.cards,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<RecallNoteList> createState() => _RecallNoteListState();
}

class _RecallNoteListState extends State<RecallNoteList> {
  final _imageService = QuestionImageService();

  /// A title and a description controller per row, keyed by identity rather
  /// than index so a reorder moves the text with its card instead of leaving
  /// it behind.
  final _fields =
      <RapidRecallCard, ({TextEditingController title, TextEditingController body})>{};

  int? _uploadingAt;

  @override
  void dispose() {
    for (final pair in _fields.values) {
      pair.title.dispose();
      pair.body.dispose();
    }
    super.dispose();
  }

  ({TextEditingController title, TextEditingController body}) _fieldsFor(
          RapidRecallCard card) =>
      _fields.putIfAbsent(
        card,
        () => (
          title: TextEditingController(text: card.noteTitle),
          body: TextEditingController(text: card.noteBody),
        ),
      );

  /// Both halves go back into the single `note` field - see composeNote.
  void _onTextChanged(int index) {
    final card = widget.cards[index];
    final pair = _fieldsFor(card);
    _replace(
      index,
      card.copyWith(
        note: RapidRecallCard.composeNote(pair.title.text, pair.body.text),
      ),
    );
  }

  void _replace(int index, RapidRecallCard card) {
    final next = [...widget.cards];
    final old = next[index];
    // The controllers follow the card object, which copyWith replaces.
    final pair = _fields.remove(old);
    if (pair != null) _fields[card] = pair;
    next[index] = card;
    widget.onChanged(next);
  }

  /// A new note goes on TOP.
  ///
  /// Someone adding to a deck of forty is writing the newest thing, and the
  /// one they just made should not be waiting for them at the bottom of a long
  /// scroll. Drag still reorders, so a deliberate order is one drag away.
  void _add() {
    widget.onChanged([const RapidRecallCard(), ...widget.cards]);
  }

  void _remove(int index) {
    final next = [...widget.cards];
    final pair = _fields.remove(next[index]);
    pair?.title.dispose();
    pair?.body.dispose();
    next.removeAt(index);
    widget.onChanged(next);
  }

  void _reorder(int oldIndex, int newIndex) {
    // ReorderableListView reports the target as if the dragged row were still
    // in place, so a downward move is one too far.
    if (newIndex > oldIndex) newIndex -= 1;
    final next = [...widget.cards];
    next.insert(newIndex, next.removeAt(oldIndex));
    widget.onChanged(next);
  }

  Future<void> _pickImage(int index) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: QuestionImageService.allowedExtensions,
      withData: true, // web has no file path to read from
    );
    if (picked == null || picked.files.single.bytes == null) return;

    setState(() => _uploadingAt = index);
    final result = await _imageService.upload(
      bytes: picked.files.single.bytes!,
      filename: picked.files.single.name,
    );
    if (!mounted) return;
    setState(() => _uploadingAt = null);

    if (!result.isSuccess || result.image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'That upload failed')),
      );
      return;
    }
    _replace(
      index,
      widget.cards[index].copyWith(
        imageUrl: result.image!.url,
        imagePublicId: result.image!.publicId,
      ),
    );
  }

  Future<void> _clearImage(int index) async {
    final card = widget.cards[index];
    // Only files uploaded in this session can be deleted - the API returns a
    // URL but no publicId, so an older image is unreferenced rather than gone.
    final publicId = card.imagePublicId;
    _replace(index, card.copyWith(clearImage: true));
    if (publicId != null) await _imageService.delete(publicId);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.cards.isEmpty
                    ? 'No notes yet'
                    : '${widget.cards.length} note'
                        '${widget.cards.length == 1 ? '' : 's'}',
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w800),
              ),
            ),
            TextButton.icon(
              onPressed: widget.enabled ? _add : null,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add note'),
            ),
          ],
        ),
        const SizedBox(height: 6),

        if (widget.cards.isEmpty)
          const _Notice(
            'No notes yet. Each one can be an image, some text, or both.',
            isError: false,
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            buildDefaultDragHandles: false,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.cards.length,
            onReorder: _reorder,
            itemBuilder: (context, index) {
              final card = widget.cards[index];
              return Padding(
                key: ValueKey(identityHashCode(card)),
                padding: const EdgeInsets.only(bottom: 10),
                child: _NoteRow(
                  index: index,
                  card: card,
                  enabled: widget.enabled,
                  uploading: _uploadingAt == index,
                  titleController: _fieldsFor(card).title,
                  bodyController: _fieldsFor(card).body,
                  onTextChanged: () => _onTextChanged(index),
                  onPickImage: () => _pickImage(index),
                  onClearImage: () => _clearImage(index),
                  onDelete: () => _remove(index),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _NoteRow extends StatelessWidget {
  final int index;
  final RapidRecallCard card;
  final bool enabled;
  final bool uploading;
  final TextEditingController titleController;
  final TextEditingController bodyController;
  final VoidCallback onTextChanged;
  final VoidCallback onPickImage;
  final VoidCallback onClearImage;
  final VoidCallback onDelete;

  const _NoteRow({
    required this.index,
    required this.card,
    required this.enabled,
    required this.uploading,
    required this.titleController,
    required this.bodyController,
    required this.onTextChanged,
    required this.onPickImage,
    required this.onClearImage,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: LmsColors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: LmsColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (enabled)
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.drag_indicator_rounded,
                        size: 18, color: LmsColors.border),
                  ),
                ),
              Text('Note ${index + 1}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: LmsColors.textGrey)),
              const Spacer(),
              IconButton(
                onPressed: enabled ? onDelete : null,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                color: LmsColors.error,
                tooltip: 'Remove note',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 6),

          LayoutBuilder(
            builder: (context, constraints) {
              final imageSlot = _ImageSlot(
                card: card,
                enabled: enabled,
                uploading: uploading,
                onPick: onPickImage,
                onClear: onClearImage,
              );

              final noteField = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LabelledField(
                    label: 'Title  ·  optional',
                    controller: titleController,
                    enabled: enabled,
                    onChanged: onTextChanged,
                    hint: 'Pseudo gout',
                    minLines: 1,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  _LabelledField(
                    label: 'Description  ·  optional',
                    controller: bodyController,
                    enabled: enabled,
                    onChanged: onTextChanged,
                    hint: 'Type the answer here. Leave blank if the image '
                        'says it all.',
                    minLines: 4,
                    maxLines: 8,
                  ),
                ],
              );

              final imageColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Image  ·  optional',
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: LmsColors.textDark)),
                  const SizedBox(height: 6),
                  imageSlot,
                ],
              );

              // Stacked, always: the figure is read first, then what it
              // means. Side by side put the text at eye level and the
              // image off to one edge.
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  imageColumn,
                  const SizedBox(height: 14),
                  noteField,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LabelledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onChanged;
  final String hint;
  final int minLines;
  final int maxLines;

  const _LabelledField({
    required this.label,
    required this.controller,
    required this.enabled,
    required this.onChanged,
    required this.hint,
    required this.minLines,
    required this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: LmsColors.textGrey)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          minLines: minLines,
          maxLines: maxLines,
          onChanged: (_) => onChanged(),
          style: const TextStyle(fontSize: 13, height: 1.4),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(fontSize: 12.5, color: LmsColors.textGrey),
            filled: true,
            fillColor: LmsColors.bg,
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: const BorderSide(color: LmsColors.border),
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

class _ImageSlot extends StatelessWidget {
  final RapidRecallCard card;
  final bool enabled;
  final bool uploading;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _ImageSlot({
    required this.card,
    required this.enabled,
    required this.uploading,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    if (uploading) {
      return Container(
        height: 110,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: LmsColors.bg,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: LmsColors.border),
        ),
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (card.hasImage) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QuestionImageView(url: card.imageUrl!, maxHeight: 150),
          const SizedBox(height: 4),
          Row(
            children: [
              TextButton(
                onPressed: enabled ? onPick : null,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Replace', style: TextStyle(fontSize: 12)),
              ),
              TextButton(
                onPressed: enabled ? onClear : null,
                style: TextButton.styleFrom(
                  foregroundColor: LmsColors.error,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Remove', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      );
    }

    // An invitation, not a requirement: a note can be text alone.
    return InkWell(
      onTap: enabled ? onPick : null,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        height: 130,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: LmsColors.bg,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: LmsColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.add_photo_alternate_outlined,
                size: 24, color: LmsColors.primary),
            SizedBox(height: 7),
            Text('Add image',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: LmsColors.primary)),
            SizedBox(height: 2),
            Text('optional · JPG, PNG, WebP, SVG',
                style: TextStyle(fontSize: 10.5, color: LmsColors.textGrey)),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final String text;
  final bool isError;

  const _Notice(this.text, {this.isError = true});

  @override
  Widget build(BuildContext context) {
    final color = isError ? LmsColors.error : LmsColors.textGrey;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 12.5, height: 1.35, color: color)),
    );
  }
}
