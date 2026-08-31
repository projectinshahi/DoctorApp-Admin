import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theam/theam_dart.dart';
import '../../models/admin_test_model.dart';
import '../../models/course_get_model.dart';
import '../../models/course_types_model.dart';
import '../../provider/course_get_provider.dart';
import '../../services/admin_test_service.dart';
import '../../services/course_details_service.dart';
import '../../widget/shimmer_loading.dart';
import 'test_wizard_screen.dart';

/// Tests for one exam type, with each row driven purely by the server's flags.
///
/// A paper belongs to a course type, not to a course: "Prelims" and "Mains"
/// under the same course are different exams with different papers. The course
/// rail only narrows down which types to offer.
///
/// The state a row shows is read off `isLocked` / `isPublished` /
/// `readyToPublish` and nothing else. Inferring it client-side - "it has
/// questions so it must be ready" - would drift from the server's own rules
/// the moment those rules changed.
class TestListScreen extends StatefulWidget {
  const TestListScreen({super.key});

  @override
  State<TestListScreen> createState() => _TestListScreenState();
}

class _TestListScreenState extends State<TestListScreen> {
  final _service = AdminTestService();
  final _courseDetails = CourseDetailsService();

  int? _courseId;
  int? _courseTypeId;

  List<CourseTypeSummary> _types = [];
  bool _isLoadingTypes = false;
  String? _typeError;

  List<AdminTest> _tests = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<CourseListGetProvider>();
      await provider.fetchCourses(limit: 100);
      if (mounted && provider.courses.isNotEmpty && _courseId == null) {
        _selectCourse(provider.courses.first.id);
      }
    });
  }

  Future<void> _selectCourse(int courseId) async {
    setState(() {
      _courseId = courseId;
      _courseTypeId = null;
      _types = [];
      _tests = [];
      _isLoadingTypes = true;
      _typeError = null;
    });

    try {
      final response = await _courseDetails.fetchCourseTypes(courseId);
      if (!mounted || _courseId != courseId) return;
      setState(() {
        _isLoadingTypes = false;
        _types = response.courseTypes;
      });
      // Defaults to "All types" rather than the first one: a paper with no
      // course type belongs to the whole course, and starting on a single
      // type would hide those.
      await _loadTests();
    } catch (e) {
      if (!mounted || _courseId != courseId) return;
      setState(() {
        _isLoadingTypes = false;
        _typeError = '$e'.replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _selectType(int? courseTypeId) async {
    setState(() => _courseTypeId = courseTypeId);
    await _loadTests();
  }

  Future<void> _loadTests() async {
    if (_courseId == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await _service.listTests(
      courseId: _courseId,
      courseTypeId: _courseTypeId,
    );
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result.isSuccess) {
        _tests = result.tests;
      } else {
        _error = result.errorMessage;
      }
    });
  }

  String get _courseTitle {
    final courses = context.read<CourseListGetProvider>().courses;
    for (final c in courses) {
      if (c.id == _courseId) return c.title;
    }
    return '';
  }


  Future<void> _openWizard({AdminTest? test, TestStep startAt = TestStep.shell}) async {
    if (_courseId == null) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TestWizardScreen(
          courseId: _courseId!,
          courseTitle: _courseTitle,
          courseTypes: _types,
          initialCourseTypeId: _courseTypeId,
          existing: test,
          startAt: startAt,
        ),
      ),
    );
    if (changed == true) await _loadTests();
  }

  Future<void> _togglePublish(AdminTest test) async {
    final result = test.isPublished
        ? await _service.unpublish(test.id)
        : await _service.publish(test.id);

    if (!mounted) return;
    if (result.isSuccess) {
      await _loadTests();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'That did not work')),
      );
    }
  }

  /// DELETE /questions also unpublishes, so both consequences are spelled out
  /// with the real count before anything is sent.
  Future<void> _confirmClear(AdminTest test) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove all questions?'),
        content: Text(
          'This removes all ${test.questionCount} question'
          '${test.questionCount == 1 ? '' : 's'}'
          '${test.isPublished ? ' and unpublishes the test' : ''}.',
          style: const TextStyle(fontSize: 13.5, height: 1.45),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: LmsColors.error),
            child: const Text('Remove questions'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final result = await _service.clearQuestions(test.id);
    if (!mounted) return;
    if (result.isSuccess) {
      await _loadTests();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'That did not work')),
      );
    }
  }

  /// Delete cascades to questions, images AND attempts, so unpublish leads.
  ///
  /// The server refuses with 409 once anyone has sat the paper; the button is
  /// disabled from [AdminTest.canDelete] first so an admin does not reach a
  /// confirm dialog for something that cannot happen.
  Future<void> _confirmDelete(AdminTest test) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete "${test.title}"?'),
        content: Text(
          'This permanently removes the test, its ${test.questionCount} '
          'question${test.questionCount == 1 ? '' : 's'} and every image '
          'uploaded with it.\n\n'
          'Unpublishing hides it from students and can be undone. Deleting '
          'cannot.',
          style: const TextStyle(fontSize: 13.5, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'delete'),
            style: TextButton.styleFrom(foregroundColor: LmsColors.error),
            child: const Text('Delete anyway'),
          ),
          // Primary, and last so it sits where the eye lands.
          if (test.isPublished)
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'unpublish'),
              style: FilledButton.styleFrom(backgroundColor: LmsColors.primary),
              child: const Text('Unpublish instead'),
            ),
        ],
      ),
    );

    if (choice == null || !mounted) return;

    if (choice == 'unpublish') {
      await _togglePublish(test);
      return;
    }

    final result = await _service.deleteTest(test.id);
    if (!mounted) return;

    if (result.isSuccess) {
      await _loadTests();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.message)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: LmsColors.error,
          duration: const Duration(seconds: 6),
        ),
      );
      // A 409 means the server knows about attempts this list did not - reload
      // so the delete button disables itself.
      if (result.attemptCount != null) await _loadTests();
    }
  }

  @override
  Widget build(BuildContext context) {
    final courseProvider = context.watch<CourseListGetProvider>();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tests',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    const Text(
                      'Fixed papers uploaded as CSV, one set per exam type. '
                      'Every student sits the same questions, timed by the server.',
                      style: TextStyle(fontSize: 12.5, color: LmsColors.textGrey),
                    ),
                  ],
                ),
              ),
              if (_courseId != null)
                FilledButton.icon(
                  onPressed: () => _openWizard(),
                  style: FilledButton.styleFrom(
                    backgroundColor: LmsColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11)),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 17),
                  label: const Text('New test',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 18),

          _coursePicker(courseProvider),
          if (_courseId != null) ...[
            const SizedBox(height: 14),
            _typePicker(),
          ],
          const SizedBox(height: 20),

          if (_courseId == null)
            const SizedBox.shrink()
          else if (_isLoading)
            const ShimmerListSkeleton(rowCount: 3, padding: EdgeInsets.zero)
          else if (_error != null)
            _Notice(
              icon: Icons.error_outline_rounded,
              color: LmsColors.error,
              text: _error!,
              action: TextButton(onPressed: _loadTests, child: const Text('Retry')),
            )
          else if (_tests.isEmpty)
            _Notice(
              icon: Icons.assignment_outlined,
              text: _courseTypeId == null
                  ? 'No tests on this course yet.'
                  : 'No tests on this exam type yet.',
            )
          else
            for (final test in _tests)
              _TestRow(
                test: test,
                onUpload: () => _openWizard(test: test, startAt: TestStep.upload),
                onReview: () => _openWizard(test: test, startAt: TestStep.review),
                onTogglePublish: () => _togglePublish(test),
                onClear: () => _confirmClear(test),
                onDelete: () => _confirmDelete(test),
              ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _coursePicker(CourseListGetProvider provider) {
    if (provider.isLoadingCourses && provider.courses.isEmpty) {
      return const LmsShimmer(
        child: Row(
          children: [
            ShimmerBox(width: 140, height: 36, radius: 18),
            SizedBox(width: 8),
            ShimmerBox(width: 110, height: 36, radius: 18),
          ],
        ),
      );
    }

    if (provider.courses.isEmpty) {
      return const _Notice(
        icon: Icons.menu_book_outlined,
        text: 'No courses yet, so there is nothing to add a test to.',
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final CourseListGetModel course in provider.courses)
          _Chip(
            title: course.title,
            selected: course.id == _courseId,
            onTap: () => _selectCourse(course.id),
          ),
      ],
    );
  }

  /// The rail that actually scopes the list. Only published exam types come
  /// back from /courses/:id/course-types, so a draft type is absent here -
  /// that is the endpoint's behaviour, not an empty course.
  Widget _typePicker() {
    if (_isLoadingTypes) {
      return const LmsShimmer(
        child: Row(
          children: [
            ShimmerBox(width: 120, height: 32, radius: 16),
            SizedBox(width: 8),
            ShimmerBox(width: 96, height: 32, radius: 16),
          ],
        ),
      );
    }

    if (_typeError != null) {
      return _Notice(
        icon: Icons.error_outline_rounded,
        color: LmsColors.error,
        text: _typeError!,
        action: TextButton(
          onPressed: () => _selectCourse(_courseId!),
          child: const Text('Retry'),
        ),
      );
    }

    if (_types.isEmpty) {
      return const _Notice(
        icon: Icons.category_outlined,
        text: 'This course has no published exam type. Tests can still be '
            'created - they will be visible to every student on the course.',
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // "All types" is a filter, not an absence: it also brings back the
        // papers that were deliberately left unscoped.
        _Chip(
          title: 'All types',
          selected: _courseTypeId == null,
          onTap: () => _selectType(null),
        ),
        for (final CourseTypeSummary type in _types)
          _Chip(
            title: type.title,
            selected: type.id == _courseTypeId,
            onTap: () => _selectType(type.id),
          ),
      ],
    );
  }
}

class _TestRow extends StatelessWidget {
  final AdminTest test;
  final VoidCallback onUpload;
  final VoidCallback onReview;
  final VoidCallback onTogglePublish;
  final VoidCallback onClear;
  final VoidCallback onDelete;

  const _TestRow({
    required this.test,
    required this.onUpload,
    required this.onReview,
    required this.onTogglePublish,
    required this.onClear,
    required this.onDelete,
  });

  ({String label, Color color}) get _badge => switch (test.state) {
        TestState.locked => (label: 'LOCKED', color: LmsColors.textDark),
        TestState.published => (label: 'PUBLISHED', color: LmsColors.success),
        TestState.ready => (label: 'READY', color: LmsColors.primary),
        TestState.draft => (label: 'DRAFT', color: LmsColors.textGrey),
      };

  static const _lockedReason =
      'Locked — a student has already attempted this test';

  @override
  Widget build(BuildContext context) {
    final badge = _badge;
    final locked = test.isLocked;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LmsColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LmsColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(test.title,
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w800)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: badge.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (locked) ...[
                      Icon(Icons.lock_rounded, size: 11, color: badge.color),
                      const SizedBox(width: 4),
                    ],
                    Text(badge.label,
                        style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: badge.color)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              // questionCount / totalQuestions: a bare count hides the
              // shortfall and a percentage hides how many rows are missing.
              _Meta(Icons.list_alt_rounded, test.progressLabel),
              // Which students see this paper. "All exam types" is a real
              // scope - the whole course - not a missing value.
              _Meta(
                test.isScopedToType
                    ? Icons.category_outlined
                    : Icons.groups_outlined,
                test.scopeLabel,
              ),
              _Meta(Icons.check_circle_outline_rounded, '+${test.marksCorrect}'),
              if (test.marksIncorrect != 0)
                _Meta(Icons.remove_circle_outline_rounded, '${test.marksIncorrect}'),
              if (test.durationMinutes != null)
                _Meta(Icons.timer_outlined, '${test.durationMinutes} min'),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              if (locked)
                // The reason lives on hover so the admin learns it before
                // clicking, rather than discovering it as a 409.
                Tooltip(
                  message: _lockedReason,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.lock_outline_rounded,
                          size: 15, color: LmsColors.textGrey),
                      SizedBox(width: 7),
                      Text('Editing disabled',
                          style: TextStyle(
                              fontSize: 12, color: LmsColors.textGrey)),
                    ],
                  ),
                )
              else ...[
                if (test.questionCount == 0)
                  _Action('Upload questions', Icons.upload_file_rounded, onUpload)
                else ...[
                  _Action('Review & publish', Icons.fact_check_outlined, onReview),
                  const SizedBox(width: 6),
                  _Action(
                    test.isPublished ? 'Unpublish' : 'Publish',
                    test.isPublished
                        ? Icons.unpublished_outlined
                        : Icons.publish_rounded,
                    // readyToPublish gates it directly - no speculative
                    // publish, no 409 as the "not ready" signal.
                    test.isPublished || test.readyToPublish
                        ? onTogglePublish
                        : null,
                  ),
                  const SizedBox(width: 6),
                  _Action('Clear', Icons.delete_outline_rounded, onClear,
                      danger: true),
                ],
              ],
              const Spacer(),
              // Disabled rather than hidden, with the reason on hover: an
              // admin should learn why the paper is undeletable before
              // clicking, not from a 409 afterwards.
              Tooltip(
                message: test.canDelete
                    ? 'Delete this test permanently'
                    : 'Cannot delete — ${test.attemptCount > 0 ? '${test.attemptCount} student attempt${test.attemptCount == 1 ? '' : 's'} exist' : 'a student has already attempted this test'}. '
                        'Deleting would erase their results. Unpublish instead.',
                child: _Action(
                  'Delete',
                  Icons.delete_forever_outlined,
                  test.canDelete ? onDelete : null,
                  danger: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool danger;

  const _Action(this.label, this.icon, this.onPressed, {this.danger = false});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: danger ? LmsColors.error : LmsColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        minimumSize: const Size(0, 34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(icon, size: 15),
      label: Text(label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Meta(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: LmsColors.textGrey),
          const SizedBox(width: 5),
          Text(text,
              style: const TextStyle(fontSize: 12, color: LmsColors.textGrey)),
        ],
      );
}

class _Chip extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({required this.title, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? LmsColors.primary : LmsColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? LmsColors.primary : LmsColors.border),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : LmsColors.textDark,
              ),
            ),
          ),
        ),
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
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.26)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 19, color: color),
            const SizedBox(width: 11),
            Expanded(
                child: Text(text,
                    style: TextStyle(fontSize: 12.5, color: color))),
            if (action != null) action!,
          ],
        ),
      );
}
