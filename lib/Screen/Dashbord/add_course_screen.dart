import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'plan_card_editor.dart';
import 'package:provider/provider.dart';

import '../../core/theam/theam_dart.dart';
import '../../models/Course_model.dart';
import '../../provider/course_provider.dart';

class CourseListAddForm extends StatefulWidget {
  final VoidCallback onCreated;
  const CourseListAddForm({required this.onCreated});

  @override
  State<CourseListAddForm> createState() => _CourseListAddFormState();
}

// Local mutable holder for one course-type row in the form
class _CourseTypeFormEntry {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final displayOrderController = TextEditingController();
  String status = "draft";

  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    displayOrderController.dispose();
  }
}

class _CourseListAddFormState extends State<CourseListAddForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _displayOrderController = TextEditingController(text: "0");

  final List<_CourseTypeFormEntry> _courseTypeEntries = [];

  String _accessType = "free";
  String _status = "draft";

  /// Only ever sent on a premium course - a free course has nothing to sell.
  final List<PlanDraft> _plans = [];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _displayOrderController.dispose();
    for (final entry in _courseTypeEntries) {
      entry.dispose();
    }
    for (final plan in _plans) {
      plan.dispose();
    }
    super.dispose();
  }

  void _addCourseType() {
    setState(() {
      _courseTypeEntries.add(_CourseTypeFormEntry());
    });
  }

  void _removeCourseType(int index) {
    setState(() {
      _courseTypeEntries[index].dispose();
      _courseTypeEntries.removeAt(index);
    });
  }

  bool get _isPremium => _accessType == 'premium';

  List<PlanDraft> get _usablePlans =>
      _plans.where((p) => !p.isBlank).toList();

  Future<void> _handleCreate(CourseProvider courseProvider) async {
    if (!_formKey.currentState!.validate()) return;

    if (_isPremium) {
      // A premium course with no plans is locked to everyone with no way to
      // buy it - the worst state this panel can produce, and one forgotten
      // step away. It is refused here rather than explained afterwards.
      if (_usablePlans.isEmpty) {
        _toast('A premium course needs at least one plan, or nobody can buy '
            'it.', isError: true);
        return;
      }
      for (var i = 0; i < _usablePlans.length; i++) {
        final problem = _usablePlans[i].problem;
        if (problem != null) {
          // Named by position, the way the server names plans[2].
          _toast('Plan ${i + 1} $problem.', isError: true);
          return;
        }
      }
    }

    // Build courseTypes list, skipping empty rows (no title entered)
    final courseTypes = _courseTypeEntries
        .where((e) => e.titleController.text.trim().isNotEmpty)
        .map((e) => CourseTypeModel(
      title: e.titleController.text.trim(),
      description: e.descriptionController.text.trim().isEmpty
          ? null
          : e.descriptionController.text.trim(),
      status: e.status,
      // Access is decided once, on the course. An exam type under a premium
      // course is premium; there is no case where one of them is sold
      // separately, and two places to set it meant two places to get it wrong.
      accessType: _accessType,
      displayOrder: int.tryParse(e.displayOrderController.text.trim()),
    ))
        .toList();

    final success = await courseProvider.createCourse(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      accessType: _accessType,
      displayOrder: int.tryParse(_displayOrderController.text.trim()) ?? 0,
      status: _status,
      courseTypes: courseTypes,
      // courseId is 0 here: the course does not exist yet, and the server
      // attaches these to whatever id it creates.
      plans: _isPremium
          ? [for (final p in _usablePlans) p.toModel(0)]
          : const [],
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Course "${courseProvider.createdCourse?.title}" created!',
          ),
          backgroundColor: LmsColors.success,
        ),
      );
      widget.onCreated();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(courseProvider.errorMessage ?? 'Failed to create course'),
          backgroundColor: LmsColors.error,
        ),
      );
    }
  }

  void _toast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? LmsColors.error : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: LmsColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LmsColors.border),
      ),
      child: Form(
        key: _formKey,
        child: Consumer<CourseProvider>(
          builder: (context, courseProvider, child) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Add a new course",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: LmsColors.textDark,
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _titleController,
                  enabled: !courseProvider.isLoading,
                  decoration: const InputDecoration(
                    labelText: "Title *",
                    hintText: "e.g. Gulf license exam (GP)",
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                  (v == null || v.trim().isEmpty) ? "Title is required" : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descriptionController,
                  enabled: !courseProvider.isLoading,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: "Description",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Status",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    RadioListTile<String>(
                      title: const Text("Draft"),
                      value: "draft",
                      groupValue: _status,
                      onChanged: (value) => setState(() => _status = value!),
                    ),
                    RadioListTile<String>(
                      title: const Text("Published"),
                      value: "published",
                      groupValue: _status,
                      onChanged: (value) => setState(() => _status = value!),
                    ),
                    RadioListTile<String>(
                      title: const Text("Archived"),
                      value: "archived",
                      groupValue: _status,
                      onChanged: (value) => setState(() => _status = value!),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _accessType,
                        decoration: const InputDecoration(
                          labelText: "Access type",
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: "free", child: Text("Free")),
                          DropdownMenuItem(value: "premium", child: Text("Premium")),
                        ],
                        onChanged: courseProvider.isLoading
                            ? null
                            : (v) => setState(() => _accessType = v ?? "free"),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextFormField(
                        controller: _displayOrderController,
                        enabled: !courseProvider.isLoading,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Display order",
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (int.tryParse(v?.trim() ?? '') == null)
                            ? "Must be a number"
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const Divider(),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Exam types under this course",
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    TextButton.icon(
                      onPressed: courseProvider.isLoading ? null : _addCourseType,
                      icon: const Icon(Icons.add),
                      label: const Text("Add exam type"),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_courseTypeEntries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      "No exam types added — this course will show as a single selectable card.",
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ),
                ...List.generate(_courseTypeEntries.length, (index) {
                  final entry = _courseTypeEntries[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: LmsColors.surface,
                      border: Border.all(color: LmsColors.border),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Exam type ${index + 1}",
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                              onPressed: () => _removeCourseType(index),
                            ),
                          ],
                        ),
                        TextFormField(
                          controller: entry.titleController,
                          decoration: const InputDecoration(
                            labelText: "Title *",
                            hintText: "e.g. DHA Exam",
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: entry.descriptionController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: "Description",
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: entry.status,
                                decoration: const InputDecoration(
                                  labelText: "Status",
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(value: "draft", child: Text("Draft")),
                                  DropdownMenuItem(value: "published", child: Text("Published")),
                                  DropdownMenuItem(value: "archived", child: Text("Archived")),
                                ],
                                onChanged: (v) => setState(() => entry.status = v ?? "draft"),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: entry.displayOrderController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "Display order (optional)",
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                // ── Pricing ────────────────────────────────────────────
                //
                // Hidden on a free course: there is nothing to sell, and an
                // empty pricing step invites someone to fill it in anyway.
                if (_isPremium) ...[
                  const SizedBox(height: 24),
                  const Divider(height: 1, color: LmsColors.border),
                  const SizedBox(height: 18),
                  const Text('Pricing',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text(
                    'Every lesson in this course will be locked until a '
                    'student subscribes. Mark a lesson as free preview to '
                    'leave it open.',
                    style: TextStyle(
                        fontSize: 12, height: 1.45, color: LmsColors.textGrey),
                  ),
                  const SizedBox(height: 14),
                  PlanCardEditor(
                    plans: _plans,
                    enabled: !courseProvider.isLoading,
                    onChanged: (plans) => setState(() {
                      _plans
                        ..clear()
                        ..addAll(plans);
                    }),
                  ),
                ],

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: courseProvider.isLoading
                        ? null
                        : () => _handleCreate(courseProvider),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LmsColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: courseProvider.isLoading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Text("Create course"),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}