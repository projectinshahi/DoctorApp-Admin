import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/const/responsive_const.dart';
import '../../core/theam/theam_dart.dart';
import '../../models/course_get_model.dart';
import '../../provider/course_get_provider.dart';
import '../../provider/course_provider.dart'; // adjust path to your CourseProvider (update/delete)
import 'add_course_screen.dart';
import 'course_details_screen.dart';
import 'edit_course_type_sheet.dart';
import '../../widget/shimmer_loading.dart';

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
            Expanded(
              child: Consumer<CourseListGetProvider>(
                builder: (context, provider, _) {
                  final count = provider.courses.length;
                  if (count == 0) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "$count course${count == 1 ? '' : 's'}",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: LmsColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        "Expand a course to see its exam types, or use + Exam to add one.",
                        style: TextStyle(fontSize: 12, color: LmsColors.textGrey),
                      ),
                    ],
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() => _showAddForm = !_showAddForm);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: LmsColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              ),
              child: Text(
                _showAddForm ? "Close" : "Add course",
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700),
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
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: ShimmerListSkeleton(rowCount: 4),
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
/// One course, rendered as a group header with its exam types nested
/// underneath. Tapping the card still opens the course; the chevron expands
/// the group in place, so the Course -> Exam Type shape is visible from the
/// list without navigating into each course to find out.
class _CourseRow extends StatefulWidget {
  final CourseListGetModel course;
  final VoidCallback onChanged; // called after a successful edit/delete/add to refresh the list

  const _CourseRow({
    required this.course,
    required this.onChanged,
  });

  @override
  State<_CourseRow> createState() => _CourseRowState();
}

class _CourseRowState extends State<_CourseRow> {
  /// Courses that already have exam types start expanded - that's the
  /// structure the admin came here to see. Empty ones stay collapsed so the
  /// list doesn't fill with "nothing here" rows.
  late bool _expanded = widget.course.courseTypes.isNotEmpty;

  CourseListGetModel get course => widget.course;

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

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? LmsColors.error : LmsColors.success,
      ),
    );
  }

  void _openCourse() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CourseDetailsScreen(courseId: course.id)),
    );
  }

  /// Adds an exam type straight from the list. The course is implied by the
  /// row, so this reuses the same sheet the course details screen opens with
  /// no extra "which course?" step.
  Future<void> _openAddExamSheet() async {
    final created = await showEditCourseTypeSheet(context, courseId: course.id);

    if (created == true && mounted) {
      _showSnack('Exam type added to "${course.title}"');
      setState(() => _expanded = true); // show what was just created
      widget.onChanged();
    }
  }

  Future<void> _openEditDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditCourseDialog(course: course),
    );

    if (result == true) widget.onChanged();
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text("Delete course?", style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
          'This will permanently delete "${course.title}" and all of its chapters, '
          'lessons, and exam types. This cannot be undone.',
          style: const TextStyle(color: LmsColors.textGrey, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancel", style: TextStyle(color: LmsColors.textDark)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: LmsColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final courseProvider = context.read<CourseProvider>();
    final success = await courseProvider.deleteCourse(courseId: course.id);

    if (!mounted) return;
    if (success) {
      _showSnack('"${course.title}" was deleted');
      widget.onChanged();
    } else {
      _showSnack(
        courseProvider.deleteErrorMessage ?? 'Failed to delete course',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final examTypes = course.courseTypes;
    final isMobile = LmsResponsive.isMobile(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: LmsColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LmsColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Course header ─────────────────────────────────────────
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _openCourse,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _CourseThumbnail(url: course.thumbnail),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            course.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: LmsColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _MetaBadge(
                                text: course.status,
                                color: _statusColor(course.status),
                              ),
                              _MetaBadge(
                                text: course.accessType == 'free' ? 'Free' : 'Premium',
                                color: course.accessType == 'free'
                                    ? LmsColors.textGrey
                                    : LmsColors.primary,
                              ),
                              _MetaBadge(
                                text: examTypes.isEmpty
                                    ? 'No exam types'
                                    : '${examTypes.length} exam type'
                                        '${examTypes.length == 1 ? '' : 's'}',
                                color: examTypes.isEmpty
                                    ? LmsColors.textGrey
                                    : LmsColors.textDark,
                              ),
                              _MetaBadge(
                                text: '${course.lessonCount} lesson'
                                    '${course.lessonCount == 1 ? '' : 's'}',
                                color: LmsColors.textGrey,
                              ),
                              _MetaBadge(
                                text: '${course.enrolledCount} enrolled',
                                color: LmsColors.textGrey,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Add-exam sits on the row itself, so the course it
                    // belongs to is never ambiguous.
                    if (isMobile)
                      IconButton(
                        onPressed: _openAddExamSheet,
                        icon: const Icon(Icons.playlist_add_rounded, size: 20),
                        color: LmsColors.primary,
                        tooltip: 'Add exam type',
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: _openAddExamSheet,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: LmsColors.primary,
                          side: const BorderSide(color: LmsColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text(
                          'Exam',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                      ),

                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded,
                          size: 20, color: LmsColors.textGrey),
                      tooltip: 'Course actions',
                      onSelected: (value) {
                        switch (value) {
                          case 'open':
                            _openCourse();
                          case 'edit':
                            _openEditDialog();
                          case 'delete':
                            _confirmDelete();
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'open', child: Text('Open course')),
                        PopupMenuItem(value: 'edit', child: Text('Edit course')),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete', style: TextStyle(color: LmsColors.error)),
                        ),
                      ],
                    ),

                    // Expand is its own target - tapping the card still opens
                    // the course, which is the behaviour that already existed.
                    IconButton(
                      onPressed: () => setState(() => _expanded = !_expanded),
                      icon: AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 150),
                        child: const Icon(Icons.expand_more_rounded, size: 22),
                      ),
                      color: LmsColors.textGrey,
                      tooltip: _expanded ? 'Hide exam types' : 'Show exam types',
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Nested exam types ─────────────────────────────────────
          if (_expanded) ...[
            const Divider(height: 1, color: LmsColors.border),
            if (examTypes.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'No exam types in this course yet.',
                        style: TextStyle(fontSize: 12.5, color: LmsColors.textGrey),
                      ),
                    ),
                    TextButton(
                      onPressed: _openAddExamSheet,
                      child: const Text(
                        'Add the first one',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...examTypes.map(
                (examType) => _ExamTypeRow(
                  examType: examType,
                  statusColor: _statusColor(examType.status),
                  onTap: _openCourse, // exam types have no screen of their own
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// One exam type nested under its course. Indented and tinted so it reads as
/// a child of the row above rather than another course.
class _ExamTypeRow extends StatelessWidget {
  final CourseType examType;
  final Color statusColor;
  final VoidCallback onTap;

  const _ExamTypeRow({
    required this.examType,
    required this.statusColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: LmsColors.bg,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 11, 14, 11),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      examType.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: LmsColors.textDark,
                      ),
                    ),
                    if (examType.description != null &&
                        examType.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        examType.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: LmsColors.textGrey),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _MetaBadge(text: examType.status, color: statusColor),
              const SizedBox(width: 6),
              _MetaBadge(
                text: examType.accessType == 'free' ? 'Free' : 'Premium',
                color: examType.accessType == 'free'
                    ? LmsColors.textGrey
                    : LmsColors.primary,
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, size: 18, color: LmsColors.textGrey),
            ],
          ),
        ),
      ),
    );
  }
}

/// Course thumbnail with a placeholder, so a missing or broken image doesn't
/// leave a hole in the row.
class _CourseThumbnail extends StatelessWidget {
  final String? url;

  const _CourseThumbnail({required this.url});

  @override
  Widget build(BuildContext context) {
    const double size = 46;

    Widget placeholder() => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: LmsColors.primarySoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.menu_book_rounded, size: 20, color: LmsColors.primary),
        );

    if (url == null || url!.trim().isEmpty) return placeholder();

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder(),
      ),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _MetaBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
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