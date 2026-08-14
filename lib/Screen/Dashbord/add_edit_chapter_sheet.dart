import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theam/theam_dart.dart';
import '../../provider/chapter_provider.dart';

Future<bool?> showAddEditChapterSheet(
    BuildContext context, {
      required int courseTypeId,
      int? chapterId,
      String? initialTitle,
      int? initialDisplayOrder, // only used when creating - places new chapter at the end
    }) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return ChangeNotifierProvider(
        create: (_) => ChapterUpdateProvider(),
        child: _AddEditChapterSheet(
          courseTypeId: courseTypeId,
          chapterId: chapterId,
          initialTitle: initialTitle,
          initialDisplayOrder: initialDisplayOrder,
        ),
      );
    },
  );
}

class _AddEditChapterSheet extends StatefulWidget {
  final int courseTypeId;
  final int? chapterId;
  final String? initialTitle;
  final int? initialDisplayOrder;

  const _AddEditChapterSheet({
    required this.courseTypeId,
    this.chapterId,
    this.initialTitle,
    this.initialDisplayOrder,
  });

  @override
  State<_AddEditChapterSheet> createState() => _AddEditChapterSheetState();
}

class _AddEditChapterSheetState extends State<_AddEditChapterSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;

  bool get _isEditMode => widget.chapterId != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<ChapterUpdateProvider>();
    final title = _titleController.text.trim();

    final bool success = _isEditMode
        ? await provider.updateChapter(
      courseTypeId: widget.courseTypeId,
      chapterId: widget.chapterId!,
      title: title,
    )
        : await provider.createChapter(
      courseTypeId: widget.courseTypeId,
      title: title,
      displayOrder: widget.initialDisplayOrder,
    );

    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChapterUpdateProvider>();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: LmsColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
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
                  decoration: BoxDecoration(
                    color: LmsColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _isEditMode ? 'Edit Syllabus' : 'Add Syllabus',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: LmsColors.textDark,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Chapter Title',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: LmsColors.textGrey,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _titleController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'e.g. Anatomy Basics',
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
                    borderSide: BorderSide(color: LmsColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: LmsColors.primary, width: 1.5),
                  ),
                ),
                validator: (value) =>
                (value == null || value.trim().isEmpty) ? 'Title is required' : null,
              ),
              if (provider.errorMessage != null) ...[
                const SizedBox(height: 14),
                Text(
                  provider.errorMessage!,
                  style: const TextStyle(color: LmsColors.error, fontSize: 13),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: provider.isUpdating ? null : _handleSave,
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
                    _isEditMode ? 'Save Changes' : 'Add Chapter',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}