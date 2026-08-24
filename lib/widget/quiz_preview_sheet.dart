import 'package:flutter/material.dart';

import '../core/theam/theam_dart.dart';
import '../models/quiz_model.dart';
import '../services/quiz_service.dart';
import 'shimmer_loading.dart';

/// Shows the admin quiz preview - the exact questions a student would be
/// served, WITH the answer key. Admin-only by definition, so it is only ever
/// reachable from admin screens.
Future<void> showQuizPreviewSheet(BuildContext context, int quizId) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _QuizPreviewSheet(quizId: quizId),
  );
}

class _QuizPreviewSheet extends StatefulWidget {
  final int quizId;
  const _QuizPreviewSheet({required this.quizId});

  @override
  State<_QuizPreviewSheet> createState() => _QuizPreviewSheetState();
}

class _QuizPreviewSheetState extends State<_QuizPreviewSheet> {
  final _service = QuizService();

  bool _isLoading = true;
  String? _errorMessage;
  QuizPreview? _preview;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _service.previewQuiz(widget.quizId);

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result.isSuccess) {
        _preview = result.preview;
      } else {
        _errorMessage = result.errorMessage;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: LmsColors.bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _header(),
              const Divider(height: 1, color: LmsColors.border),
              Expanded(child: _body(scrollController)),
            ],
          ),
        );
      },
    );
  }

  Widget _header() {
    final preview = _preview;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preview?.quiz.title ?? 'Quiz preview',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: LmsColors.textDark),
                ),
                if (preview != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${preview.totalQuestions} question'
                    '${preview.totalQuestions == 1 ? '' : 's'} · '
                    '${_trimMarks(preview.totalMarks)} marks · '
                    '${preview.availableQuestions} available',
                    style: const TextStyle(fontSize: 12, color: LmsColors.textGrey),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, size: 22),
            color: LmsColors.textGrey,
          ),
        ],
      ),
    );
  }

  static String _trimMarks(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toString();

  Widget _body(ScrollController controller) {
    if (_isLoading) {
      return const ShimmerListSkeleton(rowCount: 3);
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 30, color: LmsColors.error),
              const SizedBox(height: 10),
              Text(_errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: LmsColors.error)),
              const SizedBox(height: 12),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final preview = _preview!;
    if (preview.questions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No questions match this quiz.\nStudents would see an empty quiz.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: LmsColors.error),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      itemCount: preview.questions.length,
      itemBuilder: (_, index) => _QuestionCard(
        question: preview.questions[index],
        number: index + 1,
      ),
    );
  }
}

/// The quiz's questions rendered straight into the page that owns them.
///
/// Same data and same cards as the modal sheet, minus the sheet: an admin
/// looking at a quiz lesson wants to see the questions, not to be asked to
/// open them. Reuses [_QuestionCard] rather than growing a second renderer.
class QuizQuestionsInline extends StatefulWidget {
  final int quizId;

  const QuizQuestionsInline({super.key, required this.quizId});

  @override
  State<QuizQuestionsInline> createState() => _QuizQuestionsInlineState();
}

class _QuizQuestionsInlineState extends State<QuizQuestionsInline> {
  final _service = QuizService();

  bool _isLoading = true;
  String? _errorMessage;
  QuizPreview? _preview;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(QuizQuestionsInline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quizId != widget.quizId) _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _service.previewQuiz(widget.quizId);

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result.isSuccess) {
        _preview = result.preview;
      } else {
        _errorMessage = result.errorMessage;
      }
    });
  }

  static String _trimMarks(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toString();

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const ShimmerListSkeleton(rowCount: 3, padding: EdgeInsets.zero);
    }

    if (_errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: LmsColors.errorBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: LmsColors.errorBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded, size: 18, color: LmsColors.error),
            const SizedBox(width: 10),
            Expanded(
              child: Text(_errorMessage!,
                  style: const TextStyle(fontSize: 12.5, color: LmsColors.error)),
            ),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final preview = _preview;
    if (preview == null || preview.questions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: LmsColors.errorBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: LmsColors.errorBorder),
        ),
        child: const Text(
          'No questions match this quiz - students would see an empty quiz.',
          style: TextStyle(fontSize: 12.5, color: LmsColors.error),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${preview.totalQuestions} question'
          '${preview.totalQuestions == 1 ? '' : 's'} · '
          '${_trimMarks(preview.totalMarks)} marks · '
          '${preview.availableQuestions} available',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: LmsColors.textGrey,
          ),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < preview.questions.length; i++)
          _QuestionCard(question: preview.questions[i], number: i + 1),
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final QuizQuestion question;
  final int number;

  const _QuestionCard({required this.question, required this.number});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LmsColors.surface,
        borderRadius: BorderRadius.circular(14),
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
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: LmsColors.textGrey)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(question.questionText,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: LmsColors.textDark)),
              ),
            ],
          ),
          if (question.questionImageUrl != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                question.questionImageUrl!,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ],
          const SizedBox(height: 10),

          ...question.options.map((option) => _OptionRow(option: option)),

          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Tag(label: question.difficulty.toUpperCase()),
              _Tag(label: question.marksLabel),
              ...question.tagNames.map((t) => _Tag(label: t)),
            ],
          ),

          if (question.explanation != null && question.explanation!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: LmsColors.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('Explanation: ${question.explanation}',
                  style: const TextStyle(fontSize: 11.5, color: LmsColors.textDark)),
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final QuizOption option;
  const _OptionRow({required this.option});

  @override
  Widget build(BuildContext context) {
    // isCorrect is null when the answer key was stripped - that is "unknown",
    // and must not render as "wrong".
    final isCorrect = option.isCorrect == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCorrect ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 16,
            color: isCorrect ? LmsColors.success : LmsColors.textGrey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              option.optionText,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isCorrect ? FontWeight.w700 : FontWeight.w500,
                color: isCorrect ? LmsColors.success : LmsColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  const _Tag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: LmsColors.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: LmsColors.border),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 10.5, fontWeight: FontWeight.w700, color: LmsColors.textGrey)),
    );
  }
}
