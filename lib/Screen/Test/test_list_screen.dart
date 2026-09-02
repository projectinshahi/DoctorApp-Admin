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
import 'edit_test_sheet.dart';
import 'test_attempts_tab.dart';
import 'test_results_screen.dart';
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

class _TestListScreenState extends State<TestListScreen>
    with SingleTickerProviderStateMixin {
  /// Tests and attempts are separate tabs, not one scroll: building a paper
  /// and reading who sat it are different jobs, done at different times.
  late final TabController _tabs = TabController(length: 3, vsync: this);

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

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
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
    // Creating needs an exam type; reopening an existing test does not.
    if (test == null && _courseTypeId == null) return;
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
  /// A plain delete first, always.
  ///
  /// The 409 that comes back when attempts exist is the confirmation step, not
  /// an error: it names the counts and says a forced delete is possible. The
  /// flag is never sent on a first click - there is no undo, no soft delete
  /// and no archive.
  Future<void> _confirmDelete(AdminTest test) async {
    final result = await _service.deleteTest(test.id);
    if (!mounted) return;

    if (result.isSuccess) {
      await _loadTests();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.message)));
      return;
    }

    if (!result.needsConfirmation) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: LmsColors.error,
          duration: const Duration(seconds: 6),
        ),
      );
      await _loadTests();
      return;
    }

    final choice = await showDialog<String>(
      context: context,
      builder: (_) => _DeleteTestDialog(test: test, refusal: result),
    );
    if (choice == null || !mounted) return;

    if (choice == 'unpublish') {
      final unpublished = await _service.unpublish(test.id);
      if (!mounted) return;
      await _loadTests();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(unpublished.isSuccess
              ? '"${test.title}" is no longer visible to students. Every '
                  'result is kept.'
              : unpublished.errorMessage ?? 'Could not unpublish'),
          backgroundColor: unpublished.isSuccess ? null : LmsColors.error,
        ),
      );
      return;
    }

    final forced = await _service.deleteTest(test.id, deleteAttempts: true);
    if (!mounted) return;
    await _loadTests();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(forced.message),
        backgroundColor: forced.isSuccess ? null : LmsColors.error,
        duration: const Duration(seconds: 7),
      ),
    );
  }

  Future<void> _openEdit(AdminTest test) async {
    final outcome = await showDialog<String>(
      context: context,
      builder: (_) => EditTestSheet(test: test, courseTypes: _types),
    );
    if (outcome == null || !mounted) return;

    await _loadTests();
    if (!mounted) return;

    // The server drops a published test to draft on any edit. Said out loud -
    // a live paper going dark unnoticed is a support ticket.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(outcome == 'unpublished'
            ? 'Saved — "${test.title}" is back to draft and no longer visible '
                'to students. Publish it again when you are ready.'
            : 'Saved.'),
        duration: Duration(seconds: outcome == 'unpublished' ? 7 : 3),
      ),
    );
  }

  void _openResults(AdminTest test) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TestResultsScreen(test: test)),
    );
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
              // A test belongs to an exam, so there is nothing to create
              // until one is chosen.
              if (_courseTypeId != null)
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
          const SizedBox(height: 18),

          TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: LmsColors.primary,
            unselectedLabelColor: LmsColors.textGrey,
            indicatorColor: LmsColors.primary,
            labelStyle:
                const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
            tabs: const [
              Tab(text: 'CREATED'),
              Tab(text: 'DRAFTS'),
              Tab(text: 'ATTEMPTED'),
            ],
          ),
          const SizedBox(height: 20),

          AnimatedBuilder(
            animation: _tabs,
            builder: (context, _) => switch (_tabs.index) {
              1 => _testsTab(drafts: true),
              2 => TestAttemptsTab(tests: _tests),
              _ => _testsTab(drafts: false),
            },
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// One tab body for both lists.
  ///
  /// Split on isPublished - what the server says is live - rather than on what
  /// the wizard started. A paper only leaves Drafts when students can see it.
  Widget _testsTab({required bool drafts}) {
    final tests =
        _tests.where((t) => t.isPublished != drafts).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_courseId == null)
          const SizedBox.shrink()
        else if (_isLoading)
          const ShimmerListSkeleton(rowCount: 3, padding: EdgeInsets.zero)
        else if (_error != null)
          _Notice(
            icon: Icons.error_outline_rounded,
            color: LmsColors.error,
            text: _error!,
            action:
                TextButton(onPressed: _loadTests, child: const Text('Retry')),
          )
        else if (tests.isEmpty)
          _Notice(
            icon: drafts
                ? Icons.edit_note_rounded
                : Icons.assignment_turned_in_outlined,
            color: drafts ? LmsColors.primary : LmsColors.success,
            text: drafts
                ? _courseTypeId == null
                    ? 'No drafts. Pick an exam type above to start one.'
                    : 'No drafts on this exam type — everything here is live.'
                : 'Nothing is published on this exam type yet. '
                    'Finish a draft to put it in front of students.',
          )
        else ...[
          if (drafts) ...[
            const Text(
              'Tap a draft to pick up where it stopped — the wizard opens at '
              'the step it still needs.',
              style: TextStyle(fontSize: 11.5, color: LmsColors.textGrey),
            ),
            const SizedBox(height: 12),
          ],
          for (final test in tests)
            _TestRow(
              test: test,
              // Only a draft resumes: a published paper has no step left, and
              // tapping it would reopen a wizard with nothing to do.
              onTap: drafts ? () => _resume(test) : null,
              onUpload: () => _openWizard(test: test, startAt: TestStep.upload),
              onReview: () => _openWizard(test: test, startAt: TestStep.review),
              onTogglePublish: () => _togglePublish(test),
              onClear: () => _confirmClear(test),
              onDelete: () => _confirmDelete(test),
              onResults: () => _openResults(test),
              onEdit: () => _openEdit(test),
              onQuestions: () => _openResults(test),
            ),
        ],
      ],
    );
  }

  /// Reopens a draft at the step it has not finished.
  ///
  /// Read off the test's own numbers rather than remembered anywhere: an
  /// empty paper needs its CSV, a partial or complete one needs reviewing
  /// before anyone publishes it.
  void _resume(AdminTest test) {
    final step =
        test.questionCount == 0 ? TestStep.upload : TestStep.review;
    _openWizard(test: test, startAt: step);
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
        // A view filter only. New papers are always written for one exam, so
        // this brings back every type's tests plus any older row that was
        // saved without one.
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
  final VoidCallback onResults;
  final VoidCallback onEdit;
  final VoidCallback onQuestions;

  /// Set on drafts only: tapping the row resumes the wizard. A published paper
  /// has no step left, so it stays inert rather than reopening a wizard with
  /// nothing to do.
  final VoidCallback? onTap;

  const _TestRow({
    required this.test,
    required this.onUpload,
    required this.onReview,
    required this.onTogglePublish,
    required this.onClear,
    required this.onDelete,
    required this.onResults,
    required this.onEdit,
    required this.onQuestions,
    this.onTap,
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
      decoration: BoxDecoration(
        color: LmsColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LmsColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
        padding: const EdgeInsets.all(16),
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
              if (test.attemptCount > 0)
                _Meta(Icons.people_outline_rounded,
                    '${test.attemptCount} attempt'
                    '${test.attemptCount == 1 ? '' : 's'}'),
              _Meta(Icons.check_circle_outline_rounded, '+${test.marksCorrect}'),
              if (test.marksIncorrect != 0)
                _Meta(Icons.remove_circle_outline_rounded, '${test.marksIncorrect}'),
              if (test.durationMinutes != null)
                _Meta(Icons.timer_outlined, '${test.durationMinutes} min'),
            ],
          ),
          const SizedBox(height: 14),

          Wrap(
            spacing: 0,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Always available: name and instructions stay editable
              // whatever the locks say.
              _Action('Edit', Icons.edit_outlined, onEdit),
              const SizedBox(width: 6),
              _Action(
                locked ? 'View questions' : 'Questions',
                Icons.list_alt_rounded,
                onQuestions,
              ),
              const SizedBox(width: 6),
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
                      Text('Questions locked',
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
                  // Publish is a filled commitment; unpublish is an outline
                  // you can take back. Rendering both as the same flat action
                  // made a live paper one indistinguishable click from dark.
                  if (test.isPublished)
                    OutlinedButton.icon(
                      onPressed: onTogglePublish,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: LmsColors.textGrey,
                        side: const BorderSide(color: LmsColors.border),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 13, vertical: 9),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9)),
                      ),
                      icon: const Icon(Icons.visibility_off_outlined, size: 15),
                      label: const Text('Unpublish',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700)),
                    )
                  else
                    Tooltip(
                      message: test.readyToPublish
                          ? 'Make this paper live to students'
                          : 'The server has not marked this test ready — the '
                              'paper is not complete yet.',
                      child: FilledButton.icon(
                        // readyToPublish gates it directly - no speculative
                        // publish, no 409 as the "not ready" signal.
                        onPressed:
                            test.readyToPublish ? onTogglePublish : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: LmsColors.success,
                          disabledBackgroundColor: LmsColors.border,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9)),
                        ),
                        icon: const Icon(Icons.rocket_launch_rounded, size: 15),
                        label: const Text('Publish',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  const SizedBox(width: 6),
                  _Action('Clear', Icons.delete_outline_rounded, onClear,
                      danger: true),
                ],
              ],
              if (test.attemptCount > 0) ...[
                const SizedBox(width: 6),
                _Action('Results', Icons.leaderboard_outlined, onResults),
              ],
              const SizedBox(width: 6),
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
        ),
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

/// The confirmation the server's 409 asked for.
///
/// Unpublish is primary because it is what is wanted nine times out of ten:
/// it hides the paper and keeps every result. Delete sits behind a
/// destructive-styled button that will not enable until the test name is typed
/// out - there is no undo behind it.
class _DeleteTestDialog extends StatefulWidget {
  final AdminTest test;
  final TestDeleteResult refusal;

  const _DeleteTestDialog({required this.test, required this.refusal});

  @override
  State<_DeleteTestDialog> createState() => _DeleteTestDialogState();
}

class _DeleteTestDialogState extends State<_DeleteTestDialog> {
  final _typed = TextEditingController();

  @override
  void initState() {
    super.initState();
    _typed.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  bool get _nameMatches =>
      _typed.text.trim() == widget.test.title.trim();

  @override
  Widget build(BuildContext context) {
    final attempts = widget.refusal.attemptCount ?? 0;
    final submitted = widget.refusal.submittedCount;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('"${widget.test.title}" has been sat'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$attempts student attempt${attempts == 1 ? '' : 's'}'
              '${submitted == null ? '' : ', $submitted of them completed'}.',
              style: const TextStyle(fontSize: 13.5, height: 1.45),
            ),
            const SizedBox(height: 10),
            const Text(
              'Unpublishing hides the test from students and keeps every '
              'result. Deleting erases the results permanently — there is no '
              'undo and no archive.',
              style: TextStyle(fontSize: 12.5, height: 1.45,
                  color: LmsColors.textGrey),
            ),
            const SizedBox(height: 18),
            Text('To delete anyway, type the test name:',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: LmsColors.error)),
            const SizedBox(height: 8),
            TextField(
              controller: _typed,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: widget.test.title,
                hintStyle: const TextStyle(
                    fontSize: 12.5, color: LmsColors.textGrey),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: LmsColors.border),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _nameMatches ? () => Navigator.pop(context, 'delete') : null,
          style: TextButton.styleFrom(foregroundColor: LmsColors.error),
          child: const Text('Delete test and results'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, 'unpublish'),
          style: FilledButton.styleFrom(backgroundColor: LmsColors.primary),
          child: const Text('Unpublish instead'),
        ),
      ],
    );
  }
}

