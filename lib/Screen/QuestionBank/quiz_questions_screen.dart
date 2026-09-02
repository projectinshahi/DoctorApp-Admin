import 'package:flutter/material.dart';

import '../../core/theam/theam_dart.dart';
import '../../models/quiz_model.dart';
import '../../services/quiz_service.dart';
import '../../widget/question_image_view.dart';
import '../../widget/shimmer_loading.dart';

/// The questions pinned to one quiz, in the order students will see them.
///
/// A quiz has two modes and only one of them has an order:
///
///   manual - the admin pinned exactly these questions, in this order
///   filter - drawn from the quiz's subject and topic afresh per student
///
/// Drag handles appear only in manual mode. Dragging a filter quiz would look
/// like it worked and change nothing anyone sees, because "question 3" is a
/// different question for every student.
class QuizQuestionsScreen extends StatefulWidget {
  final Quiz quiz;

  const QuizQuestionsScreen({super.key, required this.quiz});

  @override
  State<QuizQuestionsScreen> createState() => _QuizQuestionsScreenState();
}

class _QuizQuestionsScreenState extends State<QuizQuestionsScreen> {
  final _service = QuizService();

  QuizQuestionSet? _set;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await _service.getQuestionSet(widget.quiz.id);
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.isSuccess) {
        _set = result.set;
      } else {
        _error = result.errorMessage;
      }
    });
  }

  /// Sends the whole array in its new order.
  ///
  /// displayOrder comes from the array index server-side, so the list posted
  /// is exactly the list shown - no target-position arithmetic here.
  Future<void> _reorder(int oldIndex, int newIndex) async {
    final current = _set;
    if (current == null || _isSaving) return;

    final moved = [...current.questions];
    // ReorderableListView reports the target as if the dragged row were still
    // in place, so a downward move is one too high.
    if (newIndex > oldIndex) newIndex -= 1;
    moved.insert(newIndex, moved.removeAt(oldIndex));

    final previous = current;
    setState(() {
      _set = QuizQuestionSet(
        quizId: current.quizId,
        mode: current.mode,
        totalQuestions: current.totalQuestions,
        questions: moved,
      );
      _isSaving = true;
    });

    final result = await _service.setQuestionSet(
      quizId: widget.quiz.id,
      questionIds: moved.map((q) => q.id).toList(),
    );

    if (!mounted) return;

    if (result.isSuccess) {
      // The PUT response carries ids, not full questions, so the saved order
      // is re-read rather than guessed at.
      setState(() => _isSaving = false);
      await _load();
    } else {
      setState(() {
        _isSaving = false;
        // Put it back: a row that stays moved while the server disagrees is
        // worse than one that snaps back.
        _set = previous;
      });
      if (!mounted) return;
      _toast(result.errorMessage ?? 'Could not save the order', isError: true);
    }
  }

  /// Pins whatever the quiz currently draws, switching filter -> manual.
  Future<void> _pinCurrent() async {
    final ids = _set?.questionIds ?? const <int>[];
    if (ids.isEmpty) {
      _toast('There are no questions to pin yet.', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    final result =
        await _service.setQuestionSet(quizId: widget.quiz.id, questionIds: ids);
    if (!mounted) return;

    setState(() => _isSaving = false);
    if (result.isSuccess) {
      await _load();
      if (!mounted) return;
      _toast('These questions are pinned. You can reorder them now.');
    } else {
      _toast(result.errorMessage ?? 'Could not pin the questions',
          isError: true);
    }
  }

  /// Switches manual -> filter by sending an empty array.
  ///
  /// Confirmed, because an empty array is a MODE CHANGE, not an empty quiz -
  /// it must never be what happens by accident after the last row is removed.
  Future<void> _useAutomatic() async {
    final count = _set?.questions.length ?? 0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Use automatic selection?'),
        content: Text(
          'This unpins ${count == 0 ? 'the' : 'all $count'} question'
          '${count == 1 ? '' : 's'} and lets the quiz draw from its subject '
          'and topic instead.\n\n'
          'Each student then gets a different set, so there is no order to '
          'arrange. Nothing is deleted from the question bank.',
          style: const TextStyle(fontSize: 13.5, height: 1.45),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep this order')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: LmsColors.primary),
            child: const Text('Use automatic'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);
    final result = await _service
        .setQuestionSet(quizId: widget.quiz.id, questionIds: const []);
    if (!mounted) return;

    setState(() => _isSaving = false);
    if (result.isSuccess) {
      await _load();
      if (!mounted) return;
      _toast('This quiz now draws its questions automatically.');
    } else {
      _toast(result.errorMessage ?? 'Could not switch modes', isError: true);
    }
  }

  void _toast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? LmsColors.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final set = _set;

    return Scaffold(
      backgroundColor: LmsColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        foregroundColor: LmsColors.textDark,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(widget.quiz.title,
                style: const TextStyle(
                    fontSize: 15.5, fontWeight: FontWeight.w800),
                overflow: TextOverflow.ellipsis),
            Text(
              [
                if (widget.quiz.subjectName != null) widget.quiz.subjectName!,
                if (widget.quiz.topicName != null) widget.quiz.topicName!,
              ].join(' · '),
              style:
                  const TextStyle(fontSize: 11.5, color: LmsColors.textGrey),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _load,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Reload',
          ),
        ],
      ),
      body: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: ShimmerListSkeleton(rowCount: 5, padding: EdgeInsets.zero),
            )
          : _error != null
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: _Notice(
                    icon: Icons.error_outline_rounded,
                    color: LmsColors.error,
                    text: _error!,
                    action: TextButton(
                        onPressed: _load, child: const Text('Retry')),
                  ),
                )
              : set == null
                  ? const SizedBox.shrink()
                  : _body(set),
    );
  }

  Widget _body(QuizQuestionSet set) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (set.isManual) _manualHeader(set) else _filterBanner(set),
              const SizedBox(height: 18),

              if (set.questions.isEmpty)
                _Notice(
                  icon: Icons.quiz_outlined,
                  text: set.isManual
                      ? 'No questions are pinned to this quiz.'
                      : 'No question in the bank matches this quiz\'s subject '
                          'and topic yet, so students would see nothing.',
                  color: set.isManual
                      ? LmsColors.primary
                      : const Color(0xFFB8860B),
                )
              else if (set.isManual)
                ReorderableListView.builder(
                  shrinkWrap: true,
                  buildDefaultDragHandles: false,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: set.questions.length,
                  onReorder: _reorder,
                  itemBuilder: (context, index) {
                    final question = set.questions[index];
                    return ReorderableDragStartListener(
                      key: ValueKey(question.id),
                      index: index,
                      child: _QuestionRow(
                        question: question,
                        position: index + 1,
                        draggable: true,
                      ),
                    );
                  },
                )
              else
                // Filter mode: a preview of what the bank currently holds.
                // No handles, because the set is sampled per student.
                for (var i = 0; i < set.questions.length; i++)
                  _QuestionRow(
                    question: set.questions[i],
                    position: i + 1,
                    draggable: false,
                  ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _manualHeader(QuizQuestionSet set) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Notice(
          icon: Icons.push_pin_outlined,
          color: LmsColors.primary,
          text: '${set.questions.length} question'
              '${set.questions.length == 1 ? '' : 's'} pinned in this order. '
              'Drag to rearrange — every student sees the same sequence.',
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            if (_isSaving) ...[
              const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 9),
              const Text('Saving the new order…',
                  style: TextStyle(fontSize: 11.5, color: LmsColors.textGrey)),
            ],
            const Spacer(),
            TextButton.icon(
              onPressed: _isSaving ? null : _useAutomatic,
              icon: const Icon(Icons.auto_awesome_outlined, size: 16),
              label: const Text('Use automatic selection',
                  style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: LmsColors.textGrey),
            ),
          ],
        ),
      ],
    );
  }

  Widget _filterBanner(QuizQuestionSet set) {
    final where = [
      if (widget.quiz.subjectName != null) widget.quiz.subjectName!,
      if (widget.quiz.topicName != null) widget.quiz.topicName!,
    ].join(' / ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Notice(
          icon: Icons.auto_awesome_outlined,
          color: const Color(0xFFB8860B),
          text: where.isEmpty
              ? 'Questions are drawn automatically from the question bank. '
                  'Each student gets a different set, so there is no order to '
                  'arrange.'
              : 'Questions are drawn automatically from $where. Each student '
                  'gets a different set, so there is no order to arrange.',
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            if (_isSaving) ...[
              const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 9),
            ],
            const Spacer(),
            FilledButton.icon(
              onPressed: _isSaving || set.questions.isEmpty ? null : _pinCurrent,
              style: FilledButton.styleFrom(
                backgroundColor: LmsColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.push_pin_outlined, size: 16),
              label: const Text('Pin these questions',
                  style:
                      TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuestionRow extends StatelessWidget {
  final QuizSetQuestion question;

  /// Position in the list as shown. Only rendered in manual mode, where the
  /// sequence is a real property of the quiz rather than a listing artefact.
  final int position;

  final bool draggable;

  const _QuestionRow({
    required this.question,
    required this.position,
    required this.draggable,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: LmsColors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: LmsColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (draggable) ...[
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(Icons.drag_indicator_rounded,
                  size: 16, color: LmsColors.border),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 22,
              child: Text('$position.',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: LmsColors.textGrey)),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.only(right: 10, top: 1),
              child: Icon(Icons.shuffle_rounded,
                  size: 15, color: LmsColors.textGrey),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question.questionText.trim().isEmpty
                      ? '(image only)'
                      : question.questionText,
                  style: const TextStyle(fontSize: 13, height: 1.4),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                if (question.hasImage) ...[
                  const SizedBox(height: 8),
                  QuestionImageView(
                      url: question.questionImageUrl!, maxHeight: 170),
                ],
                if (question.difficulty != null ||
                    question.options.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    [
                      if (question.difficulty != null)
                        question.difficulty!.toUpperCase(),
                      if (question.options.isNotEmpty)
                        '${question.options.length} options',
                    ].join(' · '),
                    style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: LmsColors.textGrey),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final Widget? action;

  const _Notice({
    required this.icon,
    required this.text,
    this.color = LmsColors.primary,
    this.action,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style:
                      TextStyle(fontSize: 12.5, height: 1.4, color: color)),
            ),
            if (action != null) action!,
          ],
        ),
      );
}
