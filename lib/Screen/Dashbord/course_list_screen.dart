import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theam/theam_dart.dart';
import '../../models/course_get_model.dart';
import '../../provider/course_get_provider.dart';
import '../../provider/course_provider.dart'; // adjust path to your CourseProvider (update/delete)
import 'add_course_screen.dart';
import 'course_details_screen.dart';

class CourseListScreen extends StatefulWidget {
  const CourseListScreen({super.key});

  @override
  State<CourseListScreen> createState() => _CourseListScreenState();
}

class _CourseListScreenState extends State<CourseListScreen> {
  bool _showAddForm = false;

  final _searchController = TextEditingController();
  String? _statusFilter;
  String? _accessTypeFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CourseListGetProvider>().fetchCourses();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    context.read<CourseListGetProvider>().fetchCourses(
      status: _statusFilter,
      accessType: _accessTypeFilter,
      search: _searchController.text.trim(),
    );
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _statusFilter = null;
      _accessTypeFilter = null;
    });
    context.read<CourseListGetProvider>().fetchCourses();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                "",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: LmsColors.textDark,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                setState(() => _showAddForm = !_showAddForm);
              },
              icon: Icon(_showAddForm ? Icons.close : Icons.add),
              label: Text(_showAddForm ? "Close" : "Add Course"),
              style: ElevatedButton.styleFrom(
                backgroundColor: LmsColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        if (_showAddForm) ...[
          CourseListAddForm(
            onCreated: () {
              setState(() => _showAddForm = false);
              _applyFilters();
            },
          ),
          const SizedBox(height: 24),
        ],

        _FiltersBar(
          searchController: _searchController,
          statusFilter: _statusFilter,
          accessTypeFilter: _accessTypeFilter,
          onStatusChanged: (v) => setState(() => _statusFilter = v),
          onAccessTypeChanged: (v) => setState(() => _accessTypeFilter = v),
          onSearchSubmitted: (_) => _applyFilters(),
          onApply: _applyFilters,
          onClear: _clearFilters,
        ),

        const SizedBox(height: 20),

        Consumer<CourseListGetProvider>(
          builder: (context, provider, child) {
            if (provider.isLoadingCourses) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (provider.coursesErrorMessage != null) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: LmsColors.errorBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: LmsColors.errorBorder),
                ),
                child: Text(
                  provider.coursesErrorMessage!,
                  style: const TextStyle(color: LmsColors.error),
                ),
              );
            }

            if (provider.courses.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: Text(
                    "No courses found. Try adjusting your filters.",
                    style: TextStyle(color: LmsColors.textGrey),
                  ),
                ),
              );
            }

            return Column(
              children: provider.courses
                  .map((course) => _CourseRow(
                course: course,
                onChanged: _applyFilters,
              ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

// ── Filters bar (unchanged) ─────────────────────────────────────────
class _FiltersBar extends StatelessWidget {
  final TextEditingController searchController;
  final String? statusFilter;
  final String? accessTypeFilter;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onAccessTypeChanged;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onApply;
  final VoidCallback onClear;

  const _FiltersBar({
    required this.searchController,
    required this.statusFilter,
    required this.accessTypeFilter,
    required this.onStatusChanged,
    required this.onAccessTypeChanged,
    required this.onSearchSubmitted,
    required this.onApply,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LmsColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LmsColors.border),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 220,
            child: TextField(
              controller: searchController,
              onSubmitted: onSearchSubmitted,
              decoration: InputDecoration(
                hintText: "Search by title...",
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                filled: true,
                fillColor: LmsColors.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: LmsColors.border),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 160,
            child: DropdownButtonFormField<String>(
              initialValue: statusFilter,
              hint: const Text("Status", style: TextStyle(fontSize: 13)),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: LmsColors.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: LmsColors.border),
                ),
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text("All statuses")),
                DropdownMenuItem(value: "draft", child: Text("Draft")),
                DropdownMenuItem(value: "published", child: Text("Published")),
                DropdownMenuItem(value: "archived", child: Text("Archived")),
              ],
              onChanged: onStatusChanged,
            ),
          ),
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<String>(
              initialValue: accessTypeFilter,
              hint: const Text("Access type", style: TextStyle(fontSize: 13)),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: LmsColors.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: LmsColors.border),
                ),
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text("All access types")),
                DropdownMenuItem(value: "free", child: Text("Free")),
                DropdownMenuItem(value: "premium", child: Text("Premium")),
              ],
              onChanged: onAccessTypeChanged,
            ),
          ),
          ElevatedButton(
            onPressed: onApply,
            style: ElevatedButton.styleFrom(
              backgroundColor: LmsColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text("Apply"),
          ),
          OutlinedButton(
            onPressed: onClear,
            style: OutlinedButton.styleFrom(
              foregroundColor: LmsColors.textDark,
              side: const BorderSide(color: LmsColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text("Clear"),
          ),
        ],
      ),
    );
  }
}

// ── Individual course row, now with Edit + Delete actions ───────────
class _CourseRow extends StatelessWidget {
  final CourseListGetModel course;
  final VoidCallback onChanged; // called after successful edit/delete to refresh the list

  const _CourseRow({
    super.key,
    required this.course,
    required this.onChanged,
  });

  Color _statusColor(String status) {
    switch (status) {
      case 'published':
        return LmsColors.success;
      case 'archived':
        return LmsColors.textGrey;
      default:
        return Colors.orange;
    }
  }

  Future<void> _openEditDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditCourseDialog(course: course),
    );

    if (result == true) {
      onChanged();
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        title: const Text(
          "Delete course?",
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'This will permanently delete "${course.title}" and all of its chapters, lessons, and exam types. This cannot be undone.',
          style: const TextStyle(color: LmsColors.textGrey, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              "Cancel",
              style: TextStyle(color: LmsColors.textDark),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: LmsColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    final courseProvider = context.read<CourseProvider>();
    final success = await courseProvider.deleteCourse(courseId: course.id);

    if (!context.mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${course.title}" was deleted'),
          backgroundColor: LmsColors.success,
        ),
      );
      onChanged();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            courseProvider.deleteErrorMessage ?? 'Failed to delete course',
          ),
          backgroundColor: LmsColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasCourseTypes = course.courseTypes.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: LmsColors.surface,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CourseDetailsScreen(
                  courseId: course.id,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: LmsColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            course.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: LmsColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasCourseTypes
                                ? "${course.courseTypes.length} exam type${course.courseTypes.length == 1 ? '' : 's'}"
                                : "Standalone course",
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: LmsColors.textGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        "${course.lessonCount} lessons",
                        style: const TextStyle(
                          fontSize: 13,
                          color: LmsColors.textGrey,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        course.accessType == 'free' ? "Free" : "Premium",
                        style: const TextStyle(
                          fontSize: 13,
                          color: LmsColors.textGrey,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor(course.status).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          course.status,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _statusColor(course.status),
                          ),
                        ),
                      ),
                    ),
                    // ── Edit / Delete actions ──
                    IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          size: 20, color: LmsColors.textGrey),
                      tooltip: "Edit",
                      onPressed: () => _openEditDialog(context),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 20, color: LmsColors.error),
                      tooltip: "Delete",
                      onPressed: () => _confirmDelete(context),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: LmsColors.textGrey,
                    ),
                  ],
                ),

                if (hasCourseTypes) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: course.courseTypes.map((ct) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: LmsColors.bg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: LmsColors.border),
                        ),
                        child: Text(
                          ct.title,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: LmsColors.textDark,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Edit Course dialog ────────────────────────────────────────────
class _EditCourseDialog extends StatefulWidget {
  final CourseListGetModel course;
  const _EditCourseDialog({required this.course});

  @override
  State<_EditCourseDialog> createState() => _EditCourseDialogState();
}

class _EditCourseDialogState extends State<_EditCourseDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _displayOrderController;

  late String _status;
  late String _accessType;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.course.title);
    _displayOrderController = TextEditingController(
      text: widget.course.displayOrder.toString(),
    );
    _status = widget.course.status;
    _accessType = widget.course.accessType;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _displayOrderController.dispose();
    super.dispose();
  }

  Future<void> _handleSave(CourseProvider courseProvider) async {
    if (!_formKey.currentState!.validate()) return;

    final success = await courseProvider.updateCourse(
      courseId: widget.course.id,
      title: _titleController.text.trim(),
      status: _status,
      accessType: _accessType,
      displayOrder: int.tryParse(_displayOrderController.text.trim()),
    );

    if (!mounted) return;

    if (success) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            courseProvider.updateErrorMessage ?? 'Failed to update course',
          ),
          backgroundColor: LmsColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Consumer<CourseProvider>(
              builder: (context, courseProvider, child) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            "Edit course",
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: LmsColors.textDark,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: courseProvider.isUpdating
                              ? null
                              : () => Navigator.pop(context, false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    if (courseProvider.updateErrorMessage != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: LmsColors.errorBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: LmsColors.errorBorder),
                        ),
                        child: Text(
                          courseProvider.updateErrorMessage!,
                          style: const TextStyle(
                            color: LmsColors.error,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    const Text(
                      "Title",
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: LmsColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _titleController,
                      enabled: !courseProvider.isUpdating,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: LmsColors.bg,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: LmsColors.border),
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? "Title is required"
                          : null,
                    ),

                    const SizedBox(height: 18),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Status",
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: LmsColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                initialValue: _status,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: LmsColors.bg,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide:
                                    const BorderSide(color: LmsColors.border),
                                  ),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                      value: "draft", child: Text("Draft")),
                                  DropdownMenuItem(
                                      value: "published",
                                      child: Text("Published")),
                                  DropdownMenuItem(
                                      value: "archived",
                                      child: Text("Archived")),
                                ],
                                onChanged: courseProvider.isUpdating
                                    ? null
                                    : (v) => setState(
                                        () => _status = v ?? _status),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Access type",
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: LmsColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                initialValue: _accessType,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: LmsColors.bg,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide:
                                    const BorderSide(color: LmsColors.border),
                                  ),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                      value: "free", child: Text("Free")),
                                  DropdownMenuItem(
                                      value: "premium",
                                      child: Text("Premium")),
                                ],
                                onChanged: courseProvider.isUpdating
                                    ? null
                                    : (v) => setState(
                                        () => _accessType = v ?? _accessType),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      "Display order",
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: LmsColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _displayOrderController,
                      enabled: !courseProvider.isUpdating,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: LmsColors.bg,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: LmsColors.border),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return "Required";
                        if (int.tryParse(v.trim()) == null) {
                          return "Must be a number";
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 26),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: courseProvider.isUpdating
                                ? null
                                : () => Navigator.pop(context, false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: LmsColors.textDark,
                              side: const BorderSide(color: LmsColors.border),
                              padding:
                              const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text("Cancel"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: courseProvider.isUpdating
                                ? null
                                : () => _handleSave(courseProvider),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: LmsColors.primary,
                              foregroundColor: Colors.white,
                              padding:
                              const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: courseProvider.isUpdating
                                ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                                : const Text("Save changes"),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}