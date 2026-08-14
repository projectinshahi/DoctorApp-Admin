import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theam/theam_dart.dart';
import '../../provider/course_type_provider.dart';


Future<bool?> showEditCourseTypeSheet(
    BuildContext context, {
      required int courseId,
      int? courseTypeId,
      String initialTitle = '',
      String? initialDescription,
      String initialStatus = 'draft',      // 'draft' | 'published' | 'archived'
      String initialAccessType = 'free',   // 'free' | 'premium'
    }) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChangeNotifierProvider(
      create: (_) => CourseTypeUpdateProvider(),
      child: _EditCourseTypeSheet(
        courseId: courseId,
        courseTypeId: courseTypeId,
        initialTitle: initialTitle,
        initialDescription: initialDescription,
        initialStatus: initialStatus,
        initialAccessType: initialAccessType,
      ),
    ),
  );
}

class _EditCourseTypeSheet extends StatefulWidget {
  final int courseId;
  final int? courseTypeId;
  final String initialTitle;
  final String? initialDescription;
  final String initialStatus;
  final String initialAccessType;

  const _EditCourseTypeSheet({
    required this.courseId,
    required this.courseTypeId,
    required this.initialTitle,
    required this.initialDescription,
    required this.initialStatus,
    required this.initialAccessType,
  });

  bool get isCreateMode => courseTypeId == null;

  @override
  State<_EditCourseTypeSheet> createState() => _EditCourseTypeSheetState();
}

class _EditCourseTypeSheetState extends State<_EditCourseTypeSheet> {
  static const _statusOptions = ['draft', 'published', 'archived'];
  static const _accessOptions = ['free', 'premium'];

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late String _status;
  late String _accessType;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _descriptionController = TextEditingController(text: widget.initialDescription ?? '');
    _status = widget.initialStatus;
    _accessType = widget.initialAccessType;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'published':
        return LmsColors.success;
      case 'archived':
        return LmsColors.textGrey;
      default:
        return LmsColors.primary;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<CourseTypeUpdateProvider>();
    final description = _descriptionController.text.trim().isEmpty
        ? null
        : _descriptionController.text.trim();

    final success = widget.isCreateMode
        ? await provider.createCourseType(
      courseId: widget.courseId,
      title: _titleController.text.trim(),
      status: _status,
      description: description,
      accessType: _accessType,
    )
        : await provider.updateCourseType(
      courseId: widget.courseId,
      courseTypeId: widget.courseTypeId!,
      title: _titleController.text.trim(),
      status: _status,
      description: description,
      accessType: _accessType,
    );

    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CourseTypeUpdateProvider>();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: LmsColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: LmsColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: LmsColors.primarySoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      widget.isCreateMode ? Icons.add_rounded : Icons.workspace_premium_rounded,
                      color: LmsColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.isCreateMode ? 'Add Exam Type' : 'Edit Exam Type',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: LmsColors.textDark,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              _FieldLabel('Title'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _titleController,
                decoration: _inputDecoration(hint: 'e.g. DHA Exam'),
                validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Title is required' : null,
              ),
              const SizedBox(height: 18),

              _FieldLabel('Description (optional)'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: _inputDecoration(hint: 'Short description shown to students'),
              ),
              const SizedBox(height: 18),

              _FieldLabel('Status'),
              const SizedBox(height: 6),
              _PremiumDropdown(
                value: _status,
                items: _statusOptions,
                colorFor: _statusColor,
                onChanged: (v) => setState(() => _status = v),
              ),
              const SizedBox(height: 18),

              _FieldLabel('Access Type (optional)'),
              const SizedBox(height: 6),
              _PremiumDropdown(
                value: _accessType,
                items: _accessOptions,
                colorFor: (v) => v == 'premium' ? LmsColors.primary : const Color(0xFF4C6FFF),
                onChanged: (v) => setState(() => _accessType = v),
              ),

              if (provider.errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: LmsColors.errorBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: LmsColors.errorBorder),
                  ),
                  child: Text(
                    provider.errorMessage!,
                    style: const TextStyle(color: LmsColors.error, fontSize: 13),
                  ),
                ),
              ],

              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: provider.isUpdating ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LmsColors.textDark,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: provider.isUpdating
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                      : Text(
                    widget.isCreateMode ? 'Create Exam Type' : 'Save Changes',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: LmsColors.textGrey),
      filled: true,
      fillColor: LmsColors.bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: LmsColors.primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: LmsColors.error, width: 1.2),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: LmsColors.textGrey,
        letterSpacing: 0.2,
      ),
    );
  }
}

/// A rounded, chip-styled dropdown so status/access edits feel consistent
/// with the rest of the app instead of a stock Material dropdown.
class _PremiumDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final Color Function(String) colorFor;
  final ValueChanged<String> onChanged;

  const _PremiumDropdown({
    required this.value,
    required this.items,
    required this.colorFor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: LmsColors.bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          borderRadius: BorderRadius.circular(14),
          items: items.map((item) {
            final color = colorFor(item);
            return DropdownMenuItem(
              value: item,
              child: Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    item[0].toUpperCase() + item.substring(1),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}