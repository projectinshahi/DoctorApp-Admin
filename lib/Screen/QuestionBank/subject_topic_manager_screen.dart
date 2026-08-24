import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/const/responsive_const.dart';
import '../../core/theam/theam_dart.dart';
import '../../models/question_bank_model.dart';
import '../../provider/question_bank_provider.dart';
import '../../widget/breadcrumb_widget.dart';
import '../../widget/empty_row.dart';
import '../../widget/shimmer_loading.dart';

/// Master-detail manager for the question bank taxonomy: pick a subject on
/// the left, manage its topics on the right. One subject is selected at a
/// time, which is exactly what a single TopicProvider can hold.
class SubjectTopicManagerScreen extends StatefulWidget {
  const SubjectTopicManagerScreen({super.key});

  @override
  State<SubjectTopicManagerScreen> createState() => _SubjectTopicManagerScreenState();
}

class _SubjectTopicManagerScreenState extends State<SubjectTopicManagerScreen> {
  int? _selectedSubjectId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // isActive: null - the manager is where you go to reactivate something,
      // so it has to show the inactive rows too.
      context.read<SubjectTopicProvider>().loadSubjects(isActive: null);
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: LmsColors.textDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(message),
      ),
    );
  }

  void _selectSubject(int subjectId) {
    setState(() => _selectedSubjectId = subjectId);
    context.read<SubjectTopicProvider>().loadTopics(subjectId: subjectId, isActive: null);
  }

  // ── Subject handlers ─────────────────────────────────────────────

  Future<void> _openSubjectSheet({int? subjectId, String? initialName}) async {
    final name = await showNameSheet(
      context,
      title: subjectId == null ? 'Add Subject' : 'Edit Subject',
      label: 'Subject Name',
      hint: 'e.g. Physiology',
      initialValue: initialName,
    );
    if (name == null || !mounted) return;

    final provider = context.read<SubjectTopicProvider>();
    final success = subjectId == null
        ? await provider.createSubject(name: name)
        : await provider.updateSubject(subjectId: subjectId, name: name);

    if (!mounted) return;
    if (success) {
      _showSnack(subjectId == null ? 'Subject added' : 'Subject updated');
      await provider.loadSubjects(isActive: null);
    } else {
      _showSnack(provider.errorMessage ?? 'Failed to save subject');
    }
  }

  Future<void> _toggleSubjectActive(int subjectId, bool isActive) async {
    final provider = context.read<SubjectTopicProvider>();
    final success = await provider.updateSubject(subjectId: subjectId, isActive: !isActive);

    if (!mounted) return;
    if (success) {
      _showSnack(isActive ? 'Subject deactivated' : 'Subject activated');
      await provider.loadSubjects(isActive: null);
    } else {
      _showSnack(provider.errorMessage ?? 'Failed to update subject');
    }
  }

  // ── Topic handlers ───────────────────────────────────────────────

  Future<void> _openTopicSheet({int? topicId, String? initialName}) async {
    final subjectId = _selectedSubjectId;
    if (subjectId == null) return;

    final name = await showNameSheet(
      context,
      title: topicId == null ? 'Add Topic' : 'Edit Topic',
      label: 'Topic Name',
      hint: 'e.g. Cardiac cycle',
      initialValue: initialName,
    );
    if (name == null || !mounted) return;

    final provider = context.read<SubjectTopicProvider>();
    final success = topicId == null
        ? await provider.createTopic(subjectId: subjectId, name: name)
        : await provider.updateTopic(topicId: topicId, name: name);

    if (!mounted) return;
    if (success) {
      _showSnack(topicId == null ? 'Topic added' : 'Topic updated');
      await provider.loadTopics(subjectId: subjectId, isActive: null);
    } else {
      _showSnack(provider.errorMessage ?? 'Failed to save topic');
    }
  }

  Future<void> _toggleTopicActive(int topicId, bool isActive) async {
    final subjectId = _selectedSubjectId;
    if (subjectId == null) return;

    final provider = context.read<SubjectTopicProvider>();
    final success = await provider.updateTopic(topicId: topicId, isActive: !isActive);

    if (!mounted) return;
    if (success) {
      _showSnack(isActive ? 'Topic deactivated' : 'Topic activated');
      await provider.loadTopics(subjectId: subjectId, isActive: null);
    } else {
      _showSnack(provider.errorMessage ?? 'Failed to update topic');
    }
  }

  @override
  Widget build(BuildContext context) {
    final taxonomy = context.watch<SubjectTopicProvider>();
    final selectedName = taxonomy.subjectNamesById[_selectedSubjectId];
    final isMobile = LmsResponsive.isMobile(context);

    final subjectsPanel = _SubjectsPanel(
      selectedSubjectId: _selectedSubjectId,
      onSelect: _selectSubject,
      onAdd: () => _openSubjectSheet(),
      onEdit: (subject) => _openSubjectSheet(subjectId: subject.id, initialName: subject.name),
      onToggleActive: _toggleSubjectActive,
    );

    final topicsPanel = _TopicsPanel(
      subjectId: _selectedSubjectId,
      subjectName: selectedName,
      onAdd: () => _openTopicSheet(),
      onEdit: (topic) => _openTopicSheet(topicId: topic.id, initialName: topic.name),
      onToggleActive: _toggleTopicActive,
    );

    return Scaffold(
      backgroundColor: LmsColors.bg,
      appBar: AppBar(
        backgroundColor: LmsColors.surface,
        elevation: 0,
        foregroundColor: LmsColors.textDark,
        title: const Text('Subjects & Topics',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: LmsResponsiveCenter(
          maxWidth: 1100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LmsBreadcrumb(path: ['Question Bank', 'Subjects', selectedName]),
              const SizedBox(height: 16),
              if (isMobile)
                Column(
                  children: [
                    subjectsPanel,
                    const SizedBox(height: 16),
                    topicsPanel,
                  ],
                )
              else
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: subjectsPanel),
                      const SizedBox(width: 16),
                      Expanded(child: topicsPanel),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubjectsPanel extends StatelessWidget {
  final int? selectedSubjectId;
  final void Function(int subjectId) onSelect;
  final VoidCallback onAdd;
  final void Function(Subject subject) onEdit;
  final Future<void> Function(int subjectId, bool isActive) onToggleActive;

  const _SubjectsPanel({
    required this.selectedSubjectId,
    required this.onSelect,
    required this.onAdd,
    required this.onEdit,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SubjectTopicProvider>();

    return _Panel(
      title: 'Subjects',
      count: provider.subjects.length,
      onAdd: onAdd,
      addLabel: 'Add Subject',
      child: provider.isLoading && provider.subjects.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: ShimmerListSkeleton(rowCount: 4, padding: EdgeInsets.zero),
            )
          : provider.subjects.isEmpty
              ? const EmptyRow(text: 'No subjects yet.')
              : Column(
                  children: provider.subjects.map((subject) {
                    return _TaxonomyRow(
                      name: subject.name,
                      isActive: subject.isActive,
                      subtitle: null,
                      isSelected: subject.id == selectedSubjectId,
                      onTap: () => onSelect(subject.id),
                      onEdit: () => onEdit(subject),
                      onToggleActive: () => onToggleActive(subject.id, subject.isActive),
                    );
                  }).toList(),
                ),
    );
  }
}

class _TopicsPanel extends StatelessWidget {
  final int? subjectId;
  final String? subjectName;
  final VoidCallback onAdd;
  final void Function(Topic topic) onEdit;
  final Future<void> Function(int topicId, bool isActive) onToggleActive;

  const _TopicsPanel({
    required this.subjectId,
    required this.subjectName,
    required this.onAdd,
    required this.onEdit,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SubjectTopicProvider>();
    final isLoaded = subjectId != null && provider.loadedSubjectId == subjectId;

    return _Panel(
      title: subjectName == null ? 'Topics' : 'Topics in $subjectName',
      count: isLoaded ? provider.topics.length : null,
      onAdd: subjectId == null ? null : onAdd,
      addLabel: 'Add Topic',
      child: subjectId == null
          ? const EmptyRow(text: 'Select a subject to see its topics.')
          : !isLoaded || provider.isLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: ShimmerListSkeleton(rowCount: 4, padding: EdgeInsets.zero),
                )
              : provider.topics.isEmpty
                  ? const EmptyRow(text: 'No topics in this subject yet.')
                  : Column(
                      children: provider.topics.map((topic) {
                        return _TaxonomyRow(
                          name: topic.name,
                          isActive: topic.isActive,
                          subtitle: null,
                          isSelected: false,
                          onTap: null,
                          onEdit: () => onEdit(topic),
                          onToggleActive: () => onToggleActive(topic.id, topic.isActive),
                        );
                      }).toList(),
                    ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final int? count;
  final VoidCallback? onAdd;
  final String addLabel;
  final Widget child;

  const _Panel({
    required this.title,
    required this.count,
    required this.onAdd,
    required this.addLabel,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: LmsColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: LmsColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    count == null ? title : '$title ($count)',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: LmsColors.textDark,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: Text(addLabel,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: LmsColors.border),
          child,
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _TaxonomyRow extends StatelessWidget {
  final String name;
  final bool isActive;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;

  const _TaxonomyRow({
    required this.name,
    required this.isActive,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    required this.onEdit,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: isSelected ? LmsColors.primarySoft : Colors.transparent,
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isActive ? LmsColors.textDark : LmsColors.textGrey,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        style: const TextStyle(fontSize: 12, color: LmsColors.textGrey)),
                  ],
                ],
              ),
            ),
            if (!isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: LmsColors.bg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: LmsColors.border),
                ),
                child: const Text('Inactive',
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700, color: LmsColors.textGrey)),
              ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, size: 18, color: LmsColors.textGrey),
              onSelected: (value) => value == 'edit' ? onEdit() : onToggleActive(),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Rename')),
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(isActive ? 'Deactivate' : 'Activate'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Single-text-field sheet, the same shape as showAddEditChapterSheet.
/// Subjects and topics have identical forms, so they share it rather than
/// carrying two near-identical files. Pops the trimmed name, or null on
/// cancel.
Future<String?> showNameSheet(
  BuildContext context, {
  required String title,
  required String label,
  required String hint,
  String? initialValue,
}) {
  final formKey = GlobalKey<FormState>();
  final controller = TextEditingController(text: initialValue ?? '');

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: LmsColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: LmsColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800, color: LmsColors.textDark)),
                const SizedBox(height: 20),
                Text(label,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700, color: LmsColors.textGrey)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(color: LmsColors.textGrey, fontSize: 13.5),
                    filled: true,
                    fillColor: LmsColors.bg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: LmsColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: LmsColors.primary, width: 1.5),
                    ),
                  ),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Name is required' : null,
                  onFieldSubmitted: (_) {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(ctx, controller.text.trim());
                    }
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      if (formKey.currentState!.validate()) {
                        Navigator.pop(ctx, controller.text.trim());
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LmsColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Save',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  ).whenComplete(controller.dispose);
}
