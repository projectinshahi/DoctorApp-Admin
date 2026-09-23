import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theam/theam_dart.dart';
import '../../models/rapid_recall_model.dart';
import '../../services/rapid_recall_service.dart';
import '../../widget/shimmer_loading.dart';
import 'rapid_recall_editor_screen.dart';
import 'recall_scope_picker.dart';

/// Every deck, filtered the same way the API scopes them.
class RapidRecallListScreen extends StatefulWidget {
  const RapidRecallListScreen({super.key});

  @override
  State<RapidRecallListScreen> createState() => _RapidRecallListScreenState();
}

class _RapidRecallListScreenState extends State<RapidRecallListScreen> {
  final _service = RapidRecallService();
  final _search = TextEditingController();

  RecallScope _scope = const RecallScope();
  String? _status;

  List<RapidRecall> _recalls = const [];
  bool _isLoading = true;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await _service.list(
      courseId: _scope.courseId,
      courseTypeId: _scope.courseTypeId,
      chapterId: _scope.chapterId,
      lessonId: _scope.lessonId,
      status: _status,
      search: _search.text,
    );
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _recalls = result.recalls;
      _error = result.isSuccess ? null : result.errorMessage;
    });
  }

  void _searchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  Future<void> _openEditor({int? id}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RapidRecallEditorScreen(recallId: id),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _confirmDelete(RapidRecall recall) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete "${recall.title}"?'),
        content: Text(
          'This removes the deck and its ${recall.cardCount} '
          'note${recall.cardCount == 1 ? '' : 's'}. It cannot be undone.',
          style: const TextStyle(fontSize: 13.5, height: 1.45),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: LmsColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final result = await _service.delete(recall.id);
    if (!mounted) return;

    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'That did not work')),
      );
      return;
    }
    // The count comes from the response, not from the row that was on screen.
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Deleted "${recall.title}" and its '
          '${result.count} note(s).'),
    ));
    await _load();
  }

  Future<void> _togglePublished(RapidRecall recall) async {
    final result =
        await _service.setStatus(recall.id, published: !recall.isPublished);
    if (!mounted) return;

    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'That did not work')),
      );
      return;
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Rapid Recall',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                  SizedBox(height: 2),
                  Text(
                    'Decks of revision notes. New decks start as drafts and '
                    'reach students only when published.',
                    style: TextStyle(fontSize: 12.5, color: LmsColors.textGrey),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('New deck'),
              style: FilledButton.styleFrom(
                backgroundColor: LmsColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        _FilterCard(
          scope: _scope,
          status: _status,
          searchController: _search,
          onScopeChanged: (scope) {
            setState(() => _scope = scope);
            _load();
          },
          onStatusChanged: (status) {
            setState(() => _status = status);
            _load();
          },
          onSearchChanged: _searchChanged,
        ),
        const SizedBox(height: 16),

        if (_isLoading)
          const ShimmerListSkeleton(rowCount: 4, padding: EdgeInsets.zero)
        else if (_error != null)
          _Empty(
            icon: Icons.error_outline_rounded,
            title: 'Could not load the decks',
            body: _error!,
            color: LmsColors.error,
            action: TextButton(onPressed: _load, child: const Text('Retry')),
          )
        else if (_recalls.isEmpty)
          _Empty(
            icon: Icons.style_outlined,
            title: 'No decks here',
            body: _scope.hasCourse || _status != null
                ? 'Nothing matches these filters.'
                : 'Create one to get started.',
            action: TextButton(
                onPressed: () => _openEditor(), child: const Text('New deck')),
          )
        else
          for (final recall in _recalls)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RecallRow(
                recall: recall,
                onOpen: () => _openEditor(id: recall.id),
                onDelete: () => _confirmDelete(recall),
                onTogglePublished: () => _togglePublished(recall),
              ),
            ),
      ],
    );
  }
}

class _FilterCard extends StatelessWidget {
  final RecallScope scope;
  final String? status;
  final TextEditingController searchController;
  final ValueChanged<RecallScope> onScopeChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String> onSearchChanged;

  const _FilterCard({
    required this.scope,
    required this.status,
    required this.searchController,
    required this.onScopeChanged,
    required this.onStatusChanged,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LmsColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LmsColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RecallScopePicker(value: scope, onChanged: onScopeChanged),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 240,
                child: TextField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search titles',
                    hintStyle: const TextStyle(
                        fontSize: 13, color: LmsColors.textGrey),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
              ),
              for (final option in const [
                (value: null, label: 'All'),
                (value: 'draft', label: 'Draft'),
                (value: 'published', label: 'Published'),
              ])
                _Toggle(
                  label: option.label,
                  selected: status == option.value,
                  onTap: () => onStatusChanged(option.value),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Toggle({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? LmsColors.primary : LmsColors.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? LmsColors.primary : LmsColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : LmsColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecallRow extends StatelessWidget {
  final RapidRecall recall;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final VoidCallback onTogglePublished;

  const _RecallRow({
    required this.recall,
    required this.onOpen,
    required this.onDelete,
    required this.onTogglePublished,
  });

  @override
  Widget build(BuildContext context) {
    final published = recall.isPublished;
    final statusColor = published ? LmsColors.success : const Color(0xFFB8860B);

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: LmsColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: LmsColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: LmsColors.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.style_rounded,
                  size: 18, color: LmsColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          recall.title.trim().isEmpty
                              ? 'Untitled deck'
                              : recall.title,
                          style: const TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: statusColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          published ? 'Published' : 'Draft',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: statusColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  // The scope the API already resolved, so the row needs no
                  // extra lookups to say where the deck is filed.
                  Text(
                    recall.breadcrumb,
                    style: const TextStyle(
                        fontSize: 12, color: LmsColors.textGrey),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _Meta(Icons.layers_outlined,
                          '${recall.cardCount} note${recall.cardCount == 1 ? '' : 's'}'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              tooltip: 'Deck actions',
              icon: const Icon(Icons.more_horiz_rounded,
                  size: 19, color: LmsColors.textGrey),
              onSelected: (value) {
                if (value == 'publish') onTogglePublished();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'publish',
                  child: Row(
                    children: [
                      Icon(
                        published
                            ? Icons.visibility_off_outlined
                            : Icons.rocket_launch_rounded,
                        size: 17,
                        color: published
                            ? LmsColors.textGrey
                            : LmsColors.success,
                      ),
                      const SizedBox(width: 10),
                      Text(published ? 'Unpublish' : 'Publish'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded,
                          size: 17, color: LmsColors.error),
                      SizedBox(width: 10),
                      Text('Delete deck',
                          style: TextStyle(color: LmsColors.error)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Meta(this.icon, this.label);

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: LmsColors.textGrey),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: LmsColors.textGrey)),
        ],
      );
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color color;
  final Widget? action;

  const _Empty({
    required this.icon,
    required this.title,
    required this.body,
    this.color = LmsColors.textGrey,
    this.action,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 20),
        decoration: BoxDecoration(
          color: LmsColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: LmsColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 30, color: color),
            const SizedBox(height: 12),
            Text(title,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 5),
            Text(body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12.5, color: LmsColors.textGrey)),
            if (action != null) ...[const SizedBox(height: 8), action!],
          ],
        ),
      );
}
