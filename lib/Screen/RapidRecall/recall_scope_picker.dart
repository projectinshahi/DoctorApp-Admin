import 'package:flutter/material.dart';

import '../../core/theam/theam_dart.dart';
import '../../models/course_details_model.dart' as details;
import '../../models/course_get_model.dart';
import '../../models/question_bank_model.dart';
import '../../services/course_details_service.dart';
import '../../services/courseget_service.dart';
import '../../services/subject_topic_service.dart';

/// Where a deck is filed.
///
/// **Course → exam type → subject → lesson.**
///
/// The exam types and lessons come from one `GET /courses/:id` - the same full
/// tree the Videos screen walks - rather than from `/course-types` plus a
/// chapters call per type. Two reasons that matters:
///
///   * some courses hang their chapters directly off the course and skip exam
///     types entirely, and those lessons are invisible to a chapters-by-exam
///     read;
///   * `/courses/:id/course-types` returns PUBLISHED exam types only, so a
///     draft one could not be picked at all.
///
/// Subject and lesson are siblings rather than a chain - a lesson does not sit
/// under a subject - so either, both or neither may be filled.
///
/// **A funnel, not a path.** Only the course is required; everything below it
/// narrows who sees the deck and may be left empty. A deck written for a whole
/// subject must not have to be attached to forty lessons.
///
/// Children clear when a parent changes. Not tidiness: the subject list is
/// fetched per exam, so one carried over from the previous exam is a subject
/// the new one may not have, and the server refuses the mismatch with a 400.
class RecallScope {
  final int? courseId;
  final int? courseTypeId;
  final int? subjectId;
  final int? lessonId;

  const RecallScope({
    this.courseId,
    this.courseTypeId,
    this.subjectId,
    this.lessonId,
  });

  bool get hasCourse => courseId != null;

  RecallScope withCourse(int? id) => RecallScope(courseId: id);

  /// Clears the subject and the lesson. Both lists are fetched per exam, so
  /// anything carried over from the previous one may not exist under the new
  /// exam - and the server refuses "That lesson belongs to a different exam
  /// under this course".
  RecallScope withCourseType(int? id) =>
      RecallScope(courseId: courseId, courseTypeId: id);

  /// Subject and lesson are two separate narrowings of the same exam, not a
  /// chain: a lesson does not live under a subject, so picking one leaves the
  /// other alone.
  RecallScope withSubject(int? id) => RecallScope(
        courseId: courseId,
        courseTypeId: courseTypeId,
        subjectId: id,
        lessonId: lessonId,
      );

  RecallScope withLesson(int? id) => RecallScope(
        courseId: courseId,
        courseTypeId: courseTypeId,
        subjectId: subjectId,
        lessonId: id,
      );
}

class RecallScopePicker extends StatefulWidget {
  final RecallScope value;
  final ValueChanged<RecallScope> onChanged;

  /// Filters may leave the course empty; the editor may not.
  final bool requireCourse;

  /// Shown on the course field when it is required and still empty.
  final String? courseError;

  final bool enabled;

  const RecallScopePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.requireCourse = false,
    this.courseError,
    this.enabled = true,
  });

  @override
  State<RecallScopePicker> createState() => _RecallScopePickerState();
}

class _RecallScopePickerState extends State<RecallScopePicker> {
  final _courseService = CourseListGetService();
  final _courseDetails = CourseDetailsService();
  final _subjectService = SubjectTopicService();

  List<CourseListGetModel> _courses = const [];
  details.CourseDetails? _tree;
  List<Subject> _subjects = const [];

  bool _loadingTypes = false;
  bool _loadingSubjects = false;

  /// The course has no subject linked to it, so the API offered every subject
  /// rather than an empty list. Said out loud under the dropdown - otherwise
  /// the list looks arbitrary and nobody can tell why.
  bool _subjectsAreFallback = false;

  @override
  void initState() {
    super.initState();
    _loadCourses();
    final courseId = widget.value.courseId;
    if (courseId != null) {
      _loadTree(courseId);
      _loadSubjects(courseId, widget.value.courseTypeId);
    }
  }

  @override
  void didUpdateWidget(RecallScopePicker old) {
    super.didUpdateWidget(old);

    final courseId = widget.value.courseId;
    final typeId = widget.value.courseTypeId;

    if (courseId != old.value.courseId) {
      if (courseId == null) {
        setState(() {
          _tree = null;
          _subjects = const [];
          _subjectsAreFallback = false;
        });
      } else {
        _loadTree(courseId);
        _loadSubjects(courseId, null);
      }
    }

    // The subject list is scoped by exam as well as by course, so a new exam
    // type has to refetch it - not merely clear the selection.
    if (typeId != old.value.courseTypeId) {
      // The lesson list is derived from the tree already in hand, so an exam
      // type change needs no second request.
      if (courseId != null) _loadSubjects(courseId, typeId);
    }
  }

  Future<void> _loadCourses() async {
    try {
      final courses = await _courseService.fetchCourses(limit: 100);
      if (mounted) setState(() => _courses = courses);
    } catch (_) {
      // A dropdown that fails to fill shows as an empty dropdown. Throwing
      // here would take the whole screen down with it.
    }
  }

  /// GET /api/admin/courses/:courseId/subjects?courseTypeId=
  ///
  /// Not /api/subjects, which returns every subject in the system regardless
  /// of course - a list an admin cannot tell apart from a relevant one.
  Future<void> _loadSubjects(int courseId, int? courseTypeId) async {
    setState(() => _loadingSubjects = true);
    final result = await _subjectService.getCourseSubjects(
      courseId: courseId,
      courseTypeId: courseTypeId,
    );
    // A slow response for a course or exam the admin has already moved off
    // must not overwrite the list for the one they are now on.
    if (!mounted ||
        widget.value.courseId != courseId ||
        widget.value.courseTypeId != courseTypeId) {
      return;
    }
    setState(() {
      _loadingSubjects = false;
      _subjects = result.isSuccess ? result.subjects : const [];
      _subjectsAreFallback = result.isSuccess && result.fallback;
    });
  }

  /// One read of the full course tree: exam types, their chapters, and the
  /// chapters that hang directly off the course.
  Future<void> _loadTree(int courseId) async {
    setState(() => _loadingTypes = true);
    try {
      final tree = await _courseDetails.fetchCourseDetails(courseId);
      // A slow response for a course the admin has already moved off must not
      // overwrite the tree for the course they are now on.
      if (!mounted || widget.value.courseId != courseId) return;
      setState(() {
        _loadingTypes = false;
        _tree = tree;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingTypes = false;
        _tree = null;
      });
    }
  }

  List<details.CourseType> get _types => _tree?.courseTypes ?? const [];

  /// The lessons a deck can be pinned to.
  ///
  /// With no exam type chosen this is every lesson on the course, including
  /// the ones under chapters that sit directly on the course rather than under
  /// an exam - those exist and would otherwise be unreachable. Choosing an
  /// exam type narrows to that exam's own chapters.
  List<({int id, String label})> get _lessons {
    final tree = _tree;
    if (tree == null) return const [];

    final typeId = widget.value.courseTypeId;
    final out = <({int id, String label})>[];

    void collect(details.Chapter chapter, String? examTitle) {
      for (final lesson in chapter.lessons) {
        out.add((
          id: lesson.id,
          label: examTitle == null
              ? '${chapter.title} › ${lesson.title}'
              : '$examTitle › ${chapter.title} › ${lesson.title}',
        ));
      }
    }

    if (typeId == null) {
      for (final chapter in tree.chapters) {
        collect(chapter, null);
      }
      for (final type in tree.courseTypes) {
        for (final chapter in type.chapters) {
          collect(chapter, type.title);
        }
      }
    } else {
      for (final type in tree.courseTypes) {
        if (type.id != typeId) continue;
        for (final chapter in type.chapters) {
          collect(chapter, null);
        }
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final scope = widget.value;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Four fields: across on an admin window, two on a tablet, stacked
        // on a phone.
        final columns = constraints.maxWidth >= 980
            ? 4
            : constraints.maxWidth >= 540
                ? 2
                : 1;
        const gap = 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;

        Widget cell(Widget child) => SizedBox(width: width, child: child);

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            cell(_Dropdown<int>(
              label: widget.requireCourse ? 'Course *' : 'Course',
              hint: 'Any course',
              value: scope.courseId,
              enabled: widget.enabled,
              errorText: widget.courseError,
              items: [for (final c in _courses) (value: c.id, label: c.title)],
              onChanged: (id) => widget.onChanged(scope.withCourse(id)),
            )),
            cell(_Dropdown<int>(
              label: 'Exam type',
              hint: _loadingTypes
                  ? 'Loading…'
                  : !scope.hasCourse
                      ? 'Pick a course first'
                      : _types.isEmpty
                          ? 'This course has no exam types'
                          : 'All exam types',
              value: scope.courseTypeId,
              enabled: widget.enabled && scope.hasCourse && !_loadingTypes,
              disabledMessage: !scope.hasCourse
                  ? 'Choose a course first — exam types are listed per course.'
                  : _loadingTypes
                      ? 'Still loading this course\'s exam types…'
                      : 'This course has no exam types yet.',
              items: [for (final t in _types) (value: t.id, label: t.title)],
              onChanged: (id) => widget.onChanged(scope.withCourseType(id)),
            )),
            cell(_Dropdown<int>(
              label: 'Subject',
              hint: _loadingSubjects
                  ? 'Loading…'
                  : !scope.hasCourse
                      ? 'Pick a course first'
                      : _subjects.isEmpty
                          ? 'No subjects on this course'
                          : 'No subject',
              // The API offers every subject in the system when a course has
              // none of its own. That list is not a choice an admin can make
              // sense of, so it is not shown - the reason is, instead.
              helperText: _subjectsAreFallback
                  ? 'No subjects are linked to this course yet.'
                  : null,
              helperIsWarning: _subjectsAreFallback,
              value: scope.subjectId,
              enabled: widget.enabled &&
                  scope.hasCourse &&
                  !_loadingSubjects &&
                  _subjects.isNotEmpty,
              disabledMessage: !scope.hasCourse
                  ? 'Choose a course first — subjects are listed per course.'
                  : _loadingSubjects
                      ? 'Still loading this course\'s subjects…'
                      : 'No subjects are linked to this course yet.',
              items: [for (final s in _subjects) (value: s.id, label: s.name)],
              onChanged: (id) => widget.onChanged(scope.withSubject(id)),
            )),
            cell(_Dropdown<int>(
              label: 'Lesson',
              // Available as soon as a course is chosen: an exam type narrows
              // the list, it is not a gate in front of it.
              hint: _loadingTypes
                  ? 'Loading…'
                  : !scope.hasCourse
                      ? 'Pick a course first'
                      : _lessons.isEmpty
                          ? 'No lessons on this course'
                          : 'No lesson',
              value: scope.lessonId,
              enabled: widget.enabled &&
                  scope.hasCourse &&
                  !_loadingTypes &&
                  _lessons.isNotEmpty,
              disabledMessage: !scope.hasCourse
                  ? 'Choose a course first — lessons are listed per course.'
                  : _loadingTypes
                      ? 'Still loading this course\'s lessons…'
                      : 'This course has no lessons yet.',
              items: [for (final l in _lessons) (value: l.id, label: l.label)],
              onChanged: (id) => widget.onChanged(scope.withLesson(id)),
            )),
          ],
        );
      },
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  final String label;
  final String hint;
  final T? value;
  final List<({T value, String label})> items;
  final ValueChanged<T?> onChanged;
  final bool enabled;
  final String? errorText;
  final String? helperText;
  final bool helperIsWarning;

  /// Said out loud when someone taps a field that is not open yet.
  ///
  /// A disabled dropdown swallows the tap silently, so the placeholder text is
  /// the only explanation and it is easy to miss - the admin taps again,
  /// nothing happens, and the form looks broken rather than sequenced.
  final String? disabledMessage;

  const _Dropdown({
    required this.label,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
    this.errorText,
    this.helperText,
    this.helperIsWarning = false,
    this.disabledMessage,
  });

  @override
  Widget build(BuildContext context) {
    // A value the list no longer holds - a subject from the previous exam -
    // would throw inside DropdownButton, so it is dropped rather than shown.
    final safe = items.any((i) => i.value == value) ? value : null;

    final field = DropdownButtonFormField<T>(
      initialValue: safe,
      isExpanded: true,
      // White, not the Material 3 elevation tint the menu takes by default.
      dropdownColor: LmsColors.surface,
      borderRadius: BorderRadius.circular(12),
      menuMaxHeight: 340,
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        helperText: helperText,
        helperMaxLines: 2,
        helperStyle: TextStyle(
          fontSize: 10.5,
          color: helperIsWarning ? const Color(0xFFB8860B) : LmsColors.textGrey,
        ),
        filled: true,
        fillColor: enabled ? LmsColors.surface : LmsColors.bg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: LmsColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: LmsColors.border),
        ),
      ),
      hint: Text(hint,
          style: const TextStyle(fontSize: 13, color: LmsColors.textGrey),
          overflow: TextOverflow.ellipsis),
      style: const TextStyle(fontSize: 13, color: LmsColors.textDark),
      items: [
        // Clearing is a first-class choice: every level below the course is
        // optional, so "any" has to stay reachable once something is picked.
        DropdownMenuItem<T>(
          value: null,
          child: Text(hint,
              style: const TextStyle(fontSize: 13, color: LmsColors.textGrey)),
        ),
        for (final item in items)
          DropdownMenuItem<T>(
            value: item.value,
            child: Text(item.label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13)),
          ),
      ],
      onChanged: enabled ? onChanged : null,
    );

    if (enabled || disabledMessage == null) return field;

    // Behind an AbsorbPointer, so the tap reaches this handler rather than a
    // dropdown that would open with nothing in it.
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(disabledMessage!),
            duration: const Duration(seconds: 2),
          ));
      },
      child: AbsorbPointer(child: field),
    );
  }
}
