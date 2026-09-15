import 'package:flutter/material.dart';

import '../../core/theam/theam_dart.dart';
import '../../models/rapid_recall_model.dart';
import '../../services/rapid_recall_service.dart';
import '../../widget/shimmer_loading.dart';
import 'recall_note_list.dart';
import 'recall_scope_picker.dart';

/// Create or edit one deck.
///
/// Saving is two calls, always in this order: the deck itself, then its cards.
/// The cards endpoint is addressed by id, so a new deck has to exist before it
/// can hold anything - and a scope the server rejects must fail before any
/// card work is done rather than after.
class RapidRecallEditorScreen extends StatefulWidget {
  /// Null creates a new deck.
  final int? recallId;

  const RapidRecallEditorScreen({super.key, this.recallId});

  @override
  State<RapidRecallEditorScreen> createState() =>
      _RapidRecallEditorScreenState();
}

class _RapidRecallEditorScreenState extends State<RapidRecallEditorScreen> {
  final _service = RapidRecallService();

  final _title = TextEditingController();
  final _description = TextEditingController();

  RapidRecall? _recall;
  RecallScope _scope = const RecallScope();
  /// A new deck opens with one note already on screen. A deck cannot be saved
  /// without one, so making the admin find "Add note" first was a step that
  /// only ever had one answer.
  List<RapidRecallCard> _cards = const [RapidRecallCard()];

  /// What the admin wants the status to be.
  ///
  /// Held separately from [_recall] because the switch has to work on a deck
  /// that does not exist yet: publishing is PATCH /:id, so on a new deck the
  /// switch records the intent and [_save] applies it straight after create.
  /// Disabling it instead made the control look broken.
  bool _wantPublished = false;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  String? _courseError;

  bool get _isNew => widget.recallId == null;

  @override
  void initState() {
    super.initState();
    if (!_isNew) _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final result = await _service.getOne(widget.recallId!);
    if (!mounted) return;

    if (!result.isSuccess || result.recall == null) {
      setState(() {
        _isLoading = false;
        _error = result.errorMessage;
      });
      return;
    }

    final recall = result.recall!;
    setState(() {
      _isLoading = false;
      _recall = recall;
      _title.text = recall.title;
      _description.text = recall.description ?? '';
      _cards = recall.cards.isEmpty
          ? const [RapidRecallCard()]
          : recall.cards;
      _wantPublished = recall.isPublished;
      _scope = RecallScope(
        courseId: recall.courseId,
        courseTypeId: recall.courseTypeId,
        subjectId: recall.subjectId,
        lessonId: recall.lessonId,
      );
    });
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    final courseId = _scope.courseId;
    setState(() {
      // The only required field. Everything below it narrows and may be empty.
      _courseError = courseId == null ? 'Pick the course this deck is for' : null;
      _error = null;
    });
    if (courseId == null) return;

    if (_title.text.trim().isEmpty) {
      _toast('The deck needs a title.');
      return;
    }
    if (_description.text.trim().isEmpty) {
      _toast('The deck needs a description.');
      return;
    }
    // A deck with no notes at all has nothing to show a student. Any note
    // counts - image, text or both; the image is optional.
    if (_cards.every((c) => c.isEmpty)) {
      _toast('Add at least one revision note.');
      return;
    }

    setState(() => _isSaving = true);
    final wasNew = _recall == null;

    final draft = RapidRecall(
      id: _recall?.id ?? 0,
      title: _title.text.trim(),
      description: _description.text.trim(),
      courseId: courseId,
      courseTypeId: _scope.courseTypeId,
      subjectId: _scope.subjectId,
      lessonId: _scope.lessonId,
      // The deck no longer carries its own file; each note holds its own.
      noteUrl: _recall?.noteUrl,
      notePublicId: _recall?.notePublicId,
      noteFileType: _recall?.noteFileType,
    );

    final saved = _isNew && _recall == null
        ? await _service.create(draft)
        : await _service.update(_recall!.id, draft.toWritePayload());

    if (!mounted) return;

    if (!saved.isSuccess) {
      setState(() {
        _isSaving = false;
        // A cross-course chain lands here as the server's own sentence, which
        // names which link is wrong - far more use than "save failed".
        _error = saved.errorMessage;
      });
      return;
    }

    final recall = saved.recall ?? _recall;
    if (recall == null) {
      setState(() {
        _isSaving = false;
        _error = 'The server did not return the deck.';
      });
      return;
    }
    setState(() => _recall = recall);

    // An untouched blank row is not an error - it is a row the admin did not
    // use. Only rows they started are kept and validated.
    final filled = _cards.where((c) => !c.isEmpty).toList();
    final cards = await _service.saveCards(recall.id, filled);
    if (!mounted) return;

    setState(() => _isSaving = false);

    if (!cards.isSuccess) {
      setState(() => _error = cards.errorMessage);
      return;
    }

    // The switch was flipped before the deck existed, so the status it asked
    // for is applied now that there is an id to address.
    if (_wantPublished && recall.isPublished != true) {
      final status = await _service.setStatus(recall.id, published: true);
      if (!mounted) return;
      if (status.recall != null) {
        setState(() => _recall = status.recall);
      } else if (!status.isSuccess) {
        // The deck and its notes are saved; only the publish failed. Staying
        // put is the point - popping would carry the admin back to a list
        // showing "Draft" with no idea why.
        setState(() {
          _wantPublished = false;
          _error = 'The deck saved, but publishing it did not: '
              '${status.errorMessage}';
        });
        return;
      }
    }

    // Toasted from here rather than after the pop, so the message survives the
    // navigation - the list screen shares this ScaffoldMessenger.
    final published = _recall?.isPublished == true;
    _toast('${wasNew ? 'Created' : 'Saved'}. '
        '${cards.count} note${cards.count == 1 ? '' : 's'}'
        '${published ? ', published.' : ', still a draft.'}');

    // Back to the list, new deck or not. Staying open was only ever a
    // workaround for a Publish switch that could not be used before saving,
    // and that switch now applies its own status as part of this save.
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _setPublished(bool published) async {
    setState(() => _wantPublished = published);

    final recall = _recall;
    // Nothing to PATCH yet - _save will apply this the moment the deck has an
    // id. The switch still moves, which is the whole point.
    if (recall == null || recall.isPublished == published) return;

    setState(() => _isSaving = true);
    final result = await _service.setStatus(recall.id, published: published);
    if (!mounted) return;

    setState(() {
      _isSaving = false;
      // Read back from the response rather than trusting the local flag.
      if (result.recall != null) {
        _recall = result.recall;
        _wantPublished = result.recall!.isPublished;
      }
    });

    if (!result.isSuccess) {
      _toast(result.errorMessage ?? 'That did not work');
      return;
    }
    _toast(_recall?.isPublished == true
        ? 'Published. Students can see this deck now.'
        : 'Back to draft. Students no longer see it.');
  }

  @override
  Widget build(BuildContext context) {
    final recall = _recall;

    return Scaffold(
      backgroundColor: LmsColors.bg,
      appBar: AppBar(
        backgroundColor: LmsColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _isNew && recall == null ? 'New rapid recall' : 'Edit rapid recall',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 14, 10),
            child: FilledButton(
              onPressed: _isSaving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: LmsColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save'),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: ShimmerListSkeleton(rowCount: 5),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_error != null) ...[
                          _ErrorBanner(_error!),
                          const SizedBox(height: 16),
                        ],

                        const _Label('Where this deck is filed'),
                        const SizedBox(height: 3),
                        const Text(
                          'Only the course is required. The exam type, the '
                          'subject and the lesson each narrow who sees the '
                          'deck, and any of them may be left empty.',
                          style: TextStyle(
                              fontSize: 12, color: LmsColors.textGrey),
                        ),
                        const SizedBox(height: 12),
                        RecallScopePicker(
                          value: _scope,
                          requireCourse: true,
                          courseError: _courseError,
                          enabled: !_isSaving,
                          onChanged: (scope) => setState(() {
                            _scope = scope;
                            _courseError = null;
                          }),
                        ),
                        const SizedBox(height: 24),

                        const _Label('The deck'),
                        const SizedBox(height: 3),
                        const Text(
                          'Both are required. The title is how the deck is '
                          'found; the description is what a student reads '
                          'before opening it.',
                          style: TextStyle(
                              fontSize: 12, color: LmsColors.textGrey),
                        ),
                        const SizedBox(height: 12),
                        _Field(
                          controller: _title,
                          label: 'Title *',
                          hint: 'ECG rapid recall',
                          enabled: !_isSaving,
                        ),
                        const SizedBox(height: 12),
                        _Field(
                          controller: _description,
                          label: 'Description *',
                          hint: 'Read these the night before.',
                          enabled: !_isSaving,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 22),

                        _StatusRow(
                          published: _wantPublished,
                          pending: recall == null && _wantPublished,
                          enabled: !_isSaving,
                          onChanged: _setPublished,
                        ),
                        const SizedBox(height: 22),

                        const _Label('Revision notes'),
                        const SizedBox(height: 3),
                        const Text(
                          'Write as many as the deck needs — they are all '
                          'created together when you save. Each note can have '
                          'an image, typed text, an attached PDF, or any mix; '
                          'the image is optional.\n'
                          'Drag to reorder. The order on screen is the order '
                          'students get.',
                          style: TextStyle(
                              fontSize: 12, height: 1.45,
                              color: LmsColors.textGrey),
                        ),
                        const SizedBox(height: 12),
                        RecallNoteList(
                          cards: _cards,
                          enabled: !_isSaving,
                          onChanged: (cards) => setState(() => _cards = cards),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Draft or Published, as one switch rather than two buttons.
///
/// A switch because this is a state the deck is *in*, not an action taken on
/// it - and because the two states are opposites, so a pair of buttons made
/// the reader work out which one was current.
///
/// Off until the deck has been saved once: publishing is
/// `PATCH /rapid-recalls/:id`, and a deck with no id cannot be addressed.
class _StatusRow extends StatelessWidget {
  final bool published;

  /// Switched on, but the deck has no id yet - so it will be published by the
  /// next Save rather than right now. Saying so beats a switch that looks like
  /// it already did something.
  final bool pending;

  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _StatusRow({
    required this.published,
    required this.enabled,
    required this.onChanged,
    this.pending = false,
  });

  @override
  Widget build(BuildContext context) {
    final live = published;
    final accent = live ? LmsColors.success : const Color(0xFFB8860B);

    return Container(
      padding: const EdgeInsets.fromLTRB(15, 13, 11, 13),
      decoration: BoxDecoration(
        color: enabled ? accent.withValues(alpha: 0.06) : LmsColors.bg,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: enabled ? accent.withValues(alpha: 0.3) : LmsColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            live ? Icons.rocket_launch_rounded : Icons.edit_note_rounded,
            size: 20,
            color: enabled ? accent : LmsColors.textGrey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pending
                      ? 'Publish on save'
                      : live
                          ? 'Published'
                          : 'Draft',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: enabled ? accent : LmsColors.textGrey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  pending
                      ? 'Students will see it as soon as you save.'
                      : live
                          ? 'Students can see this deck.'
                          : 'Only you can see this deck.',
                  style: const TextStyle(
                      fontSize: 12, color: LmsColors.textGrey),
                ),
              ],
            ),
          ),
          Switch(
            value: live,
            onChanged: enabled ? onChanged : null,
            activeThumbColor: Colors.white,
            activeTrackColor: LmsColors.success,
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.9,
          color: LmsColors.textGrey,
        ),
      );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool enabled;
  final int maxLines;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.enabled = true,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        enabled: enabled,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 13.5),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle:
              const TextStyle(fontSize: 13, color: LmsColors.textGrey),
          filled: true,
          fillColor: LmsColors.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: LmsColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: LmsColors.border),
          ),
        ),
      );
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);

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
            const Icon(Icons.error_outline_rounded,
                size: 18, color: LmsColors.error),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: const TextStyle(
                      fontSize: 12.5, height: 1.4, color: LmsColors.error)),
            ),
          ],
        ),
      );
}
