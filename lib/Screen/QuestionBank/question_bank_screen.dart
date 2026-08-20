import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/const/responsive_const.dart';
import '../../core/theam/theam_dart.dart';
import '../../models/question_bank_model.dart';
import '../../provider/question_bank_provider.dart';
import '../../widget/breadcrumb_widget.dart';
import '../../widget/empty_row.dart';
import 'add_edit_question_sheet.dart';
import 'subject_topic_manager_screen.dart';

/// What the delete endpoint can't do yet, said up front instead of being
/// discovered through a 409. The server's own message is still what the
/// snackbar shows after a failed attempt.
const String kDeleteBlockedCopy = "Deactivate instead — quiz usage can't be verified yet";

/// Sort options the list offers. Values are passed straight through as the
/// `sort` query param.
const Map<String, String> kSortOptions = {
  'newest': 'Newest first',
  'oldest': 'Oldest first',
  'difficulty': 'Difficulty',
  'subject': 'Subject',
};

/// The Question Bank list. Owns its own scrolling so the bulk action bar and
/// pagination can pin to the bottom instead of scrolling away with the rows.
class QuestionBankScreen extends StatefulWidget {
  const QuestionBankScreen({super.key});

  @override
  State<QuestionBankScreen> createState() => _QuestionBankScreenState();
}

class _QuestionBankScreenState extends State<QuestionBankScreen> {
  final _searchController = TextEditingController();
  final _tagController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QuestionListProvider>().fetchQuestions();
      context.read<SubjectTopicProvider>().loadSubjects();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _refresh() => context.read<QuestionListProvider>().fetchQuestions();

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? LmsColors.error : LmsColors.textDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(message),
      ),
    );
  }

  // ── Filters ──────────────────────────────────────────────────────

  Future<void> _onSubjectFilterChanged(int? subjectId) async {
    final list = context.read<QuestionListProvider>();
    final taxonomy = context.read<SubjectTopicProvider>();

    if (subjectId == null) {
      taxonomy.clearTopics();
      await list.applyFilters(clearSubject: true);
      return;
    }
    await taxonomy.loadTopics(subjectId: subjectId);
    await list.applyFilters(subjectId: subjectId);
  }

  Future<void> _clearFilters() async {
    _searchController.clear();
    _tagController.clear();
    context.read<SubjectTopicProvider>().clearTopics();
    await context.read<QuestionListProvider>().clearFilters();
  }

  // ── Row actions ──────────────────────────────────────────────────

  Future<void> _openAddSheet() async {
    final list = context.read<QuestionListProvider>();
    final created = await showAddEditQuestionSheet(
      context,
      initialSubjectId: list.subjectId,
      initialTopicId: list.topicId,
    );
    if (created == true && mounted) {
      _showSnack('Question added');
      await _refresh();
    }
  }

  Future<void> _openEditSheet(Question question) async {
    final updated = await showAddEditQuestionSheet(context, question: question);
    if (updated == true && mounted) {
      _showSnack('Question updated');
      await _refresh();
    }
  }

  Future<void> _duplicate(Question question) async {
    final provider = QuestionUpdateProvider();
    final success = await provider.duplicateQuestion(question.id);

    if (!mounted) return;
    if (success) {
      _showSnack('Duplicated as an inactive copy — review it before activating');
      await _refresh();
    } else {
      _showSnack(provider.errorMessage ?? 'Failed to duplicate question', isError: true);
    }
  }

  Future<void> _toggleStatus(Question question) async {
    final next = question.status == QuestionStatus.active
        ? QuestionStatus.inactive
        : QuestionStatus.active;

    final provider = QuestionUpdateProvider();
    final success = await provider.updateStatus(question.id, next);

    if (!mounted) return;
    if (success) {
      _showSnack('Question ${next == QuestionStatus.active ? 'activated' : 'deactivated'}');
      await _refresh();
    } else {
      _showSnack(provider.errorMessage ?? 'Failed to update status', isError: true);
    }
  }

  /// The delete action stays visible. The dialog leads with why it will very
  /// likely fail; a failed attempt surfaces the backend's own message.
  Future<void> _confirmDelete(Question question) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete question?'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(kDeleteBlockedCopy,
                style: TextStyle(fontWeight: FontWeight.w700, color: LmsColors.error)),
            SizedBox(height: 10),
            Text(
              'Until the quiz module ships the server refuses deletes, so this '
              'will almost certainly fail. Deactivating hides the question '
              'everywhere without risking a quiz that already uses it.',
              style: TextStyle(fontSize: 13.5, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: LmsColors.error),
            child: const Text('Delete anyway'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final provider = QuestionUpdateProvider();
    final success = await provider.deleteQuestion(question.id);

    if (!mounted) return;
    if (success) {
      _showSnack('Question deleted');
      await _refresh();
    } else {
      _showSnack(provider.errorMessage ?? kDeleteBlockedCopy, isError: true);
    }
  }

  Future<void> _bulkStatus(QuestionStatus status) async {
    final list = context.read<QuestionListProvider>();
    final ids = list.selectedIds.toList();
    if (ids.isEmpty) return;

    final provider = QuestionUpdateProvider();
    final success = await provider.bulkUpdateStatus(ids, status);

    if (!mounted) return;
    if (success) {
      _showSnack('${ids.length} question${ids.length == 1 ? '' : 's'} '
          '${status == QuestionStatus.active ? 'activated' : 'deactivated'}');
      list.clearSelection();
      await _refresh();
    } else {
      _showSnack(provider.errorMessage ?? 'Failed to update questions', isError: true);
    }
  }

  Future<void> _openTaxonomyManager() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SubjectTopicManagerScreen()),
    );
    if (!mounted) return;
    // Subjects or topics may have been renamed or deactivated in there.
    await context.read<SubjectTopicProvider>().loadSubjects();
  }

  @override
  Widget build(BuildContext context) {
    final list = context.watch<QuestionListProvider>();
    final padding = LmsResponsive.value<double>(context, mobile: 16, tablet: 24, desktop: 32);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(padding, 20, padding, 20),
            children: [
              LmsResponsiveCenter(
                maxWidth: 1100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LmsBreadcrumb(path: ['Question Bank', 'Questions']),
                    const SizedBox(height: 12),
                    _Header(
                      total: list.total,
                      onAdd: _openAddSheet,
                      onManageTaxonomy: _openTaxonomyManager,
                    ),
                    const SizedBox(height: 16),
                    _FilterBar(
                      searchController: _searchController,
                      tagController: _tagController,
                      onSubjectChanged: _onSubjectFilterChanged,
                      onClear: _clearFilters,
                    ),
                    const SizedBox(height: 14),
                    ..._buildList(list),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (list.selectedIds.isNotEmpty)
          _BulkActionBar(
            count: list.selectedIds.length,
            onActivate: () => _bulkStatus(QuestionStatus.active),
            onDeactivate: () => _bulkStatus(QuestionStatus.inactive),
            onClear: list.clearSelection,
          ),
        if (list.questions.isNotEmpty)
          _Pagination(
            page: list.page,
            totalPages: list.totalPages,
            total: list.total,
            isBusy: list.isLoading,
            onPrev: () => list.goToPage(list.page - 1),
            onNext: () => list.goToPage(list.page + 1),
          ),
      ],
    );
  }

  List<Widget> _buildList(QuestionListProvider list) {
    if (list.isLoading && list.questions.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 60),
          child: Center(child: CircularProgressIndicator(color: LmsColors.primary)),
        ),
      ];
    }

    if (list.errorMessage != null && list.questions.isEmpty) {
      return [_ErrorPanel(message: list.errorMessage!, onRetry: _refresh)];
    }

    if (list.questions.isEmpty) {
      return [
        Container(
          decoration: BoxDecoration(
            color: LmsColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: LmsColors.border),
          ),
          child: EmptyRow(
            text: list.hasFilters
                ? 'No questions match these filters.'
                : 'No questions yet. Add your first one.',
          ),
        ),
      ];
    }

    return [
      Row(
        children: [
          Checkbox(
            value: list.isPageFullySelected,
            onChanged: (_) => list.selectAll(),
            activeColor: LmsColors.primary,
          ),
          Text(
            list.isPageFullySelected ? 'Deselect all on page' : 'Select all on page',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: LmsColors.textGrey,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      ...list.questions.map(
        (question) => _QuestionRow(
          question: question,
          isSelected: list.selectedIds.contains(question.id),
          onToggleSelected: () => list.toggleSelected(question.id),
          onEdit: () => _openEditSheet(question),
          onDuplicate: () => _duplicate(question),
          onToggleStatus: () => _toggleStatus(question),
          onDelete: () => _confirmDelete(question),
        ),
      ),
    ];
  }
}

// ── Header ──────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final int total;
  final VoidCallback onAdd;
  final VoidCallback onManageTaxonomy;

  const _Header({
    required this.total,
    required this.onAdd,
    required this.onManageTaxonomy,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '$total question${total == 1 ? '' : 's'}',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: LmsColors.textDark,
          ),
        ),
        const SizedBox(width: 4),
        OutlinedButton.icon(
          onPressed: onManageTaxonomy,
          style: OutlinedButton.styleFrom(
            foregroundColor: LmsColors.textDark,
            side: const BorderSide(color: LmsColors.border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.account_tree_outlined, size: 16),
          label: const Text('Subjects & Topics',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
        ),
        ElevatedButton.icon(
          onPressed: onAdd,
          style: ElevatedButton.styleFrom(
            backgroundColor: LmsColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.add_rounded, size: 17),
          label: const Text('Add Question',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

// ── Filter bar ──────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final TextEditingController tagController;
  final Future<void> Function(int? subjectId) onSubjectChanged;
  final VoidCallback onClear;

  const _FilterBar({
    required this.searchController,
    required this.tagController,
    required this.onSubjectChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final list = context.watch<QuestionListProvider>();
    final taxonomy = context.watch<SubjectTopicProvider>();
    final isMobile = LmsResponsive.isMobile(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LmsColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: LmsColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: subject -> topic -> sort
          LayoutBuilder(
            builder: (context, constraints) {
              final fieldWidth =
                  isMobile ? constraints.maxWidth : (constraints.maxWidth - 20) / 3;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: fieldWidth,
                    child: DropdownButtonFormField<int?>(
                      initialValue: list.subjectId,
                      isExpanded: true,
                      decoration: _filterDecoration('Subject'),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('All subjects')),
                        ...taxonomy.subjects
                            .map((s) => DropdownMenuItem<int?>(value: s.id, child: Text(s.name))),
                      ],
                      onChanged: onSubjectChanged,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: DropdownButtonFormField<int?>(
                      initialValue: list.topicId,
                      isExpanded: true,
                      // Disabled until a subject is picked - a topic id means
                      // nothing outside its subject.
                      decoration: _filterDecoration(
                        list.subjectId == null ? 'Topic (pick a subject)' : 'Topic',
                      ),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('All topics')),
                        ...taxonomy.topics
                            .map((t) => DropdownMenuItem<int?>(value: t.id, child: Text(t.name))),
                      ],
                      onChanged: list.subjectId == null
                          ? null
                          : (value) => value == null
                              ? list.applyFilters(clearTopic: true)
                              : list.applyFilters(topicId: value),
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: DropdownButtonFormField<String?>(
                      initialValue: list.sort,
                      isExpanded: true,
                      decoration: _filterDecoration('Sort'),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('Default')),
                        ...kSortOptions.entries.map(
                          (e) => DropdownMenuItem<String?>(value: e.key, child: Text(e.value)),
                        ),
                      ],
                      onChanged: (value) => value == null
                          ? list.applyFilters(clearSort: true)
                          : list.applyFilters(sort: value),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),

          // Row 2: difficulty chips
          const _FilterLabel('Difficulty'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              _FilterChip(
                label: 'Any',
                isSelected: list.difficulty == null,
                onTap: () => list.applyFilters(clearDifficulty: true),
              ),
              ...Difficulty.values.map(
                (d) => _FilterChip(
                  label: d.label,
                  isSelected: list.difficulty == d,
                  onTap: () => list.applyFilters(difficulty: d),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Row 3: status chips
          const _FilterLabel('Status'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              _FilterChip(
                label: 'Any',
                isSelected: list.status == null,
                onTap: () => list.applyFilters(clearStatus: true),
              ),
              ...QuestionStatus.values.map(
                (s) => _FilterChip(
                  label: s.label,
                  isSelected: list.status == s,
                  onTap: () => list.applyFilters(status: s),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Row 4: tag + free-text search
          LayoutBuilder(
            builder: (context, constraints) {
              final fieldWidth =
                  isMobile ? constraints.maxWidth : (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: fieldWidth,
                    child: TextField(
                      controller: tagController,
                      decoration: _filterDecoration('Tag').copyWith(
                        prefixIcon:
                            const Icon(Icons.sell_outlined, size: 17, color: LmsColors.textGrey),
                      ),
                      // Submit, not onChanged: one request per finished term
                      // rather than one per keystroke.
                      onSubmitted: (value) => list.applyFilters(tag: value),
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: TextField(
                      controller: searchController,
                      decoration: _filterDecoration('Search question text').copyWith(
                        prefixIcon:
                            const Icon(Icons.search_rounded, size: 18, color: LmsColors.textGrey),
                      ),
                      onSubmitted: (value) => list.applyFilters(search: value),
                    ),
                  ),
                ],
              );
            },
          ),
          if (list.hasFilters)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded, size: 15),
                label: const Text('Clear filters',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }
}

InputDecoration _filterDecoration(String label) => InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12.5, color: LmsColors.textGrey),
      isDense: true,
      filled: true,
      fillColor: LmsColors.bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
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

class _FilterLabel extends StatelessWidget {
  final String text;
  const _FilterLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: LmsColors.textGrey,
        ),
      );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: LmsColors.primarySoft,
      backgroundColor: LmsColors.bg,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: isSelected ? LmsColors.primary : LmsColors.textDark,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isSelected ? LmsColors.primary : LmsColors.border),
      ),
    );
  }
}

// ── Bulk action bar ─────────────────────────────────────────────────

/// Pinned to the bottom of the screen and only rendered when at least one
/// row is ticked. Kept out of the row itself - bulk is a separate mode from
/// the per-row actions.
class _BulkActionBar extends StatelessWidget {
  final int count;
  final VoidCallback onActivate;
  final VoidCallback onDeactivate;
  final VoidCallback onClear;

  const _BulkActionBar({
    required this.count,
    required this.onActivate,
    required this.onDeactivate,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: LmsColors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: LmsColors.primarySoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count selected',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: LmsColors.primary,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: onActivate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: LmsColors.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                label: const Text('Activate',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
              OutlinedButton.icon(
                onPressed: onDeactivate,
                style: OutlinedButton.styleFrom(
                  foregroundColor: LmsColors.textDark,
                  side: const BorderSide(color: LmsColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.pause_circle_outline_rounded, size: 16),
                label: const Text('Deactivate',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
              TextButton(
                onPressed: onClear,
                style: TextButton.styleFrom(foregroundColor: LmsColors.textGrey),
                child: const Text('Clear',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Row ─────────────────────────────────────────────────────────────

class _QuestionRow extends StatelessWidget {
  final Question question;
  final bool isSelected;
  final VoidCallback onToggleSelected;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;

  const _QuestionRow({
    required this.question,
    required this.isSelected,
    required this.onToggleSelected,
    required this.onEdit,
    required this.onDuplicate,
    required this.onToggleStatus,
    required this.onDelete,
  });

  Color get _difficultyColor => switch (question.difficulty) {
        Difficulty.easy => LmsColors.success,
        Difficulty.medium => LmsColors.primary,
        Difficulty.hard => LmsColors.error,
      };

  @override
  Widget build(BuildContext context) {
    final isActive = question.status == QuestionStatus.active;
    final optionCount = question.options.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: LmsColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isSelected ? LmsColors.primary : LmsColors.border),
      ),
      padding: const EdgeInsets.fromLTRB(6, 12, 6, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: isSelected,
            onChanged: (_) => onToggleSelected(),
            activeColor: LmsColors.primary,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (question.isUnreviewedCopy) ...[
                  const _CopyFlag(),
                  const SizedBox(height: 6),
                ],
                Text(
                  question.questionText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    color: isActive ? LmsColors.textDark : LmsColors.textGrey,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (question.subjectName != null)
                      _Badge(text: question.subjectName!, color: LmsColors.textDark),
                    if (question.topicName != null)
                      _Badge(text: question.topicName!, color: LmsColors.textGrey),
                    _Badge(text: question.difficulty.label, color: _difficultyColor),
                    _Badge(
                      text: question.status.label,
                      color: isActive ? LmsColors.success : LmsColors.textGrey,
                    ),
                    _Badge(
                      text: '$optionCount option${optionCount == 1 ? '' : 's'}',
                      color: LmsColors.textGrey,
                    ),
                    _Badge(
                      text: '+${question.marksCorrect} / ${question.marksIncorrect}',
                      color: LmsColors.textGrey,
                    ),
                    ...question.tagNames.map(
                      (tag) => _Badge(text: '#$tag', color: LmsColors.primary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 18, color: LmsColors.textGrey),
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  onEdit();
                case 'duplicate':
                  onDuplicate();
                case 'status':
                  onToggleStatus();
                case 'delete':
                  onDelete();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
              PopupMenuItem(
                value: 'status',
                child: Text(isActive ? 'Deactivate' : 'Activate'),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete', style: TextStyle(color: LmsColors.error)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A duplicate arrives inactive and "(Copy)"-suffixed. Saying so in the row
/// is the point - otherwise it just looks like a stray inactive question.
class _CopyFlag extends StatelessWidget {
  const _CopyFlag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: LmsColors.errorBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: LmsColors.errorBorder),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.content_copy_rounded, size: 12, color: LmsColors.error),
          SizedBox(width: 5),
          Text(
            'Unreviewed copy — check it before activating',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: LmsColors.error),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;

  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

// ── Pagination ──────────────────────────────────────────────────────

class _Pagination extends StatelessWidget {
  final int page;
  final int totalPages;
  final int total;
  final bool isBusy;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _Pagination({
    required this.page,
    required this.totalPages,
    required this.total,
    required this.isBusy,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: LmsColors.surface,
        border: Border(top: BorderSide(color: LmsColors.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: page > 1 && !isBusy ? onPrev : null,
              icon: const Icon(Icons.chevron_left_rounded),
              color: LmsColors.textDark,
            ),
            Text(
              'Page $page of $totalPages  ·  $total total',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: LmsColors.textGrey,
              ),
            ),
            IconButton(
              onPressed: page < totalPages && !isBusy ? onNext : null,
              icon: const Icon(Icons.chevron_right_rounded),
              color: LmsColors.textDark,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorPanel({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: LmsColors.errorBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LmsColors.errorBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: LmsColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: const TextStyle(color: LmsColors.error, fontSize: 13.5)),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
