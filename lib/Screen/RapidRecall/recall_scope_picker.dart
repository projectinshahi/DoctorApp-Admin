import 'package:flutter/material.dart';

import '../../core/theam/theam_dart.dart';
import '../../models/course_details_model.dart' as details;
import '../../models/course_get_model.dart';
import '../../models/chapter_summary_model.dart';
import '../../services/course_details_service.dart';
import '../../services/courseget_service.dart';
import '../../services/lesson_services.dart';
import '../../services/chapter_services.dart';

/// Where a deck is filed.
///
/// **Course → exam type → subject → lesson**, and a subject here IS a chapter:
/// this course is built as course → exam type → chapter → lesson, and the
/// chapters are named "Internal Medicine", "Obstetrics And Gynecology" and so
/// on. So the Subject dropdown lists the exam type's chapters and the Lesson
/// dropdown lists that chapter's lessons.
///
/// Exam types come from one `GET /courses/:id` - the same full tree the Videos
/// screen walks - because `/courses/:id/course-types` returns PUBLISHED types
/// only, and a draft one could not be picked at all.
///
/// **A funnel, not a path.** Only the course is required. A deck can cover a
/// whole course, a whole exam type, one chapter, or one lesson.
///
/// Children clear when a parent changes, and each list is refetched. Not
/// tidiness: a lesson left from the previous chapter is exactly what the
/// server now rejects - "That lesson belongs to a different chapter".
class RecallScope {
  final int? courseId;
  final int? courseTypeId;

  /// The chapter, which is what this form calls a subject.
  final int? chapterId;

  final int? lessonId;

  const RecallScope({
    this.courseId,
    this.courseTypeId,
    this.chapterId,
    this.lessonId,
  });

  bool get hasCourse => courseId != null;

  RecallScope withCourse(int? id) => RecallScope(courseId: id);

  RecallScope withCourseType(int? id) =>
      RecallScope(courseId: courseId, courseTypeId: id);

  /// Clears the lesson: lessons hang off the chapter, so one from the previous
  /// chapter is refused with "That lesson belongs to a different chapter".
  RecallScope withChapter(int? id) => RecallScope(
        courseId: courseId,
        courseTypeId: courseTypeId,
        chapterId: id,
      );

  RecallScope withLesson(int? id) => RecallScope(
        courseId: courseId,
        courseTypeId: courseTypeId,
        chapterId: chapterId,
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
  final _chapterService = ChapterService();
  final _lessonService = LessonService();

  List<CourseListGetModel> _courses = const [];
  details.CourseDetails? _tree;
  List<ChapterSummary> _chapters = const [];

  bool _loadingTypes = false;
  bool _loadingChapters = false;
  bool _loadingLessons = false;

  /// Straight from `GET /api/lessons?chapterId=`, so the chosen subject is
  /// what narrows it.
  List<LessonOption> _lessonOptions = const [];



  @override
  void initState() {
    super.initState();
    _loadCourses();
    final courseId = widget.value.courseId;
    if (courseId != null) _loadTree(courseId);
    final typeId = widget.value.courseTypeId;
    if (typeId != null) _loadChapters(typeId);
    final chapterId = widget.value.chapterId;
    if (chapterId != null) _loadLessons(chapterId);
  }

  @override
  void didUpdateWidget(RecallScopePicker old) {
    super.didUpdateWidget(old);

    final courseId = widget.value.courseId;
    final typeId = widget.value.courseTypeId;

    if (courseId != old.value.courseId) {
      if (courseId == null) {
        setState(() => _tree = null);
      } else {
        _loadTree(courseId);
      }
    }

    // Chapters are the subjects, and they hang off the exam type.
    if (typeId != old.value.courseTypeId) {
      if (typeId == null) {
        setState(() => _chapters = const []);
      } else {
        _loadChapters(typeId);
      }
    }

    final chapterId = widget.value.chapterId;
    if (chapterId != old.value.chapterId) {
      if (chapterId == null) {
        setState(() => _lessonOptions = const []);
      } else {
        _loadLessons(chapterId);
      }
    }
  }

  /// GET /api/course-types/:id/chapters - the subjects of this exam type.
  Future<void> _loadChapters(int courseTypeId) async {
    setState(() => _loadingChapters = true);
    final result =
        await _chapterService.getChapters(courseTypeId: courseTypeId);
    // A slow answer for an exam the admin has already moved off must not
    // overwrite the list for the one they are on now.
    if (!mounted || widget.value.courseTypeId != courseTypeId) return;
    setState(() {
      _loadingChapters = false;
      _chapters = result.isSuccess ? (result.chapters ?? const []) : const [];
    });
  }

  /// GET /api/lessons?chapterId= - the lessons of the chosen subject.
  Future<void> _loadLessons(int chapterId) async {
    setState(() => _loadingLessons = true);
    final result = await _lessonService.searchLessons(chapterId: chapterId);

    // A slow answer for a chapter the admin has already moved off must not
    // overwrite the list for the one they are on now.
    if (!mounted || widget.value.chapterId != chapterId) return;

    setState(() {
      _loadingLessons = false;
      _lessonOptions = result.isSuccess ? result.lessons : const [];
    });

    // A lesson the new list no longer holds would still be sent on save and
    // refused, so it is cleared rather than left selected but invisible.
    final chosen = widget.value.lessonId;
    if (chosen != null && !_lessonOptions.any((l) => l.id == chosen)) {
      widget.onChanged(widget.value.withLesson(null));
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
              // The chapters of this exam type: they are the subjects.
              label: 'Subject',
              hint: _loadingChapters
                  ? 'Loading…'
                  : scope.courseTypeId == null
                      ? 'Pick an exam type first'
                      : _chapters.isEmpty
                          ? 'No subjects in this exam type'
                          : 'No subject',
              value: scope.chapterId,
              enabled: widget.enabled &&
                  scope.courseTypeId != null &&
                  !_loadingChapters &&
                  _chapters.isNotEmpty,
              disabledMessage: scope.courseTypeId == null
                  ? 'Choose an exam type first — subjects are its chapters.'
                  : _loadingChapters
                      ? 'Still loading this exam type\'s subjects…'
                      : 'This exam type has no subjects yet.',
              items: [
                for (final c in _chapters) (value: c.id, label: c.title),
              ],
              onChanged: (id) => widget.onChanged(scope.withChapter(id)),
            )),
            cell(_Dropdown<int>(
              label: 'Lesson',
              // Lessons hang off the chapter, so the subject is a gate in
              // front of this one rather than only a filter.
              hint: _loadingLessons
                  ? 'Loading…'
                  : scope.chapterId == null
                      ? 'Pick a subject first'
                      : _lessonOptions.isEmpty
                          // Valid, and not a blocker: the deck simply stays at
                          // chapter level.
                          ? 'No lesson in this subject'
                          : 'No lesson',
              value: scope.lessonId,
              enabled: widget.enabled &&
                  scope.chapterId != null &&
                  !_loadingLessons &&
                  _lessonOptions.isNotEmpty,
              disabledMessage: scope.chapterId == null
                  ? 'Choose a subject first — lessons are listed per subject.'
                  : _loadingLessons
                      ? 'Still loading this subject\'s lessons…'
                      : 'This subject has no lessons. The deck can stay at '
                          'subject level.',
              items: [
                for (final l in lessonDropdownItems(_lessonOptions))
                  (value: l.id, label: l.label),
              ],
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
