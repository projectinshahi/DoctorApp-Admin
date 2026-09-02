import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theam/theam_dart.dart';
import '../../models/chapter_summary_model.dart';
import '../../models/course_get_model.dart';
import '../../models/course_types_model.dart';
import '../../models/quiz_model.dart';
import '../../provider/course_get_provider.dart';
import '../../services/chapter_services.dart';
import '../../services/course_details_service.dart';
import '../../services/quiz_service.dart';
import '../../widget/shimmer_loading.dart';
import 'quiz_questions_screen.dart';

/// Quizzes belonging to one course and one exam type.
///
/// The quiz API filters by subject and topic, not by course - a quiz reaches
/// its course through the lesson it is attached to. So the course type's
/// chapters are read (they arrive with their lessons nested) and the quiz list
/// is matched against those lesson ids. Nothing here walks the tree a second
/// time.
class CourseQuizScreen extends StatefulWidget {
  const CourseQuizScreen({super.key});

  @override
  State<CourseQuizScreen> createState() => _CourseQuizScreenState();
}

class _CourseQuizScreenState extends State<CourseQuizScreen> {
  final _courseDetails = CourseDetailsService();
  final _chapterService = ChapterService();
  final _quizService = QuizService();

  int? _courseId;
  int? _courseTypeId;

  List<CourseTypeSummary> _types = const [];
  bool _isLoadingTypes = false;
  String? _typeError;

  List<ChapterSummary> _chapters = const [];
  List<Quiz> _quizzes = const [];
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
        await _selectCourse(provider.courses.first.id);
      }
    });
  }

  Future<void> _selectCourse(int courseId) async {
    setState(() {
      _courseId = courseId;
      _courseTypeId = null;
      _types = const [];
      _chapters = const [];
      _quizzes = const [];
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
      if (_types.isNotEmpty) await _selectType(_types.first.id);
    } catch (e) {
      if (!mounted || _courseId != courseId) return;
      setState(() {
        _isLoadingTypes = false;
        _typeError = '$e'.replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _selectType(int courseTypeId) async {
    setState(() {
      _courseTypeId = courseTypeId;
      _isLoading = true;
      _error = null;
    });

    // Chapters and quizzes are independent reads, so they go together.
    final results = await Future.wait([
      _chapterService.getChapters(courseTypeId: courseTypeId),
      // status: null asks for every quiz, active or not - an inactive quiz on
      // this course type is exactly the thing an admin is looking for here.
      _quizService.list(status: null),
    ]);

    if (!mounted || _courseTypeId != courseTypeId) return;

    final chapterResult = results[0] as ChapterListResult;
    final quizResult = results[1] as QuizListResult;

    setState(() {
      _isLoading = false;
      _chapters = chapterResult.chapters ?? const [];
      _quizzes = quizResult.quizzes ?? const [];
      _error = chapterResult.isSuccess
          ? (quizResult.isSuccess ? null : quizResult.errorMessage)
          : chapterResult.errorMessage;
    });
  }

  /// Lesson id -> lesson title, for every lesson under the selected type.
  Map<int, String> get _lessons => {
        for (final chapter in _chapters)
          for (final lesson in chapter.lessons) lesson.id: lesson.title,
      };

  /// Quizzes attached to a lesson in this course type.
  ///
  /// A quiz with no linked lesson belongs to no course, so it is left out
  /// rather than shown under whichever type happens to be open.
  List<Quiz> get _scoped {
    final ids = _lessons.keys.toSet();
    return _quizzes
        .where((q) => q.linkedLessonId != null && ids.contains(q.linkedLessonId))
        .toList();
  }

  /// The scoped quizzes, grouped under the chapter their lesson sits in.
  List<({ChapterSummary chapter, List<Quiz> quizzes})> get _byChapter {
    final scoped = _scoped;
    final groups = <({ChapterSummary chapter, List<Quiz> quizzes})>[];

    for (final chapter in _chapters) {
      final ids = chapter.lessons.map((l) => l.id).toSet();
      final quizzes =
          scoped.where((q) => ids.contains(q.linkedLessonId)).toList();
      if (quizzes.isNotEmpty) groups.add((chapter: chapter, quizzes: quizzes));
    }

    return groups;
  }

  String get _typeTitle {
    for (final t in _types) {
      if (t.id == _courseTypeId) return t.title;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final courseProvider = context.watch<CourseListGetProvider>();
    final scoped = _scoped;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Question Bank',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            _courseTypeId == null
                ? 'Quizzes on a course, by exam type.'
                : '${scoped.length} quiz${scoped.length == 1 ? '' : 'zes'} '
                    'on $_typeTitle.',
            style: const TextStyle(fontSize: 12.5, color: LmsColors.textGrey),
          ),
          const SizedBox(height: 18),

          _coursePicker(courseProvider),
          if (_courseId != null) ...[
            const SizedBox(height: 14),
            _typePicker(),
          ],
          const SizedBox(height: 22),

          if (_courseTypeId == null)
            const SizedBox.shrink()
          else if (_isLoading)
            const ShimmerListSkeleton(rowCount: 4, padding: EdgeInsets.zero)
          else if (_error != null)
            _Notice(
              icon: Icons.error_outline_rounded,
              color: LmsColors.error,
              text: _error!,
              action: TextButton(
                  onPressed: () => _selectType(_courseTypeId!),
                  child: const Text('Retry')),
            )
          else if (_byChapter.isEmpty)
            _Notice(
              icon: Icons.quiz_outlined,
              text: _lessons.isEmpty
                  ? 'This exam type has no lessons yet, so no quiz can be '
                      'attached to it.'
                  : 'No quiz is attached to any lesson on $_typeTitle.',
            )
          else
            for (final group in _byChapter) ...[
              _ChapterHeader(
                title: group.chapter.title,
                quizCount: group.quizzes.length,
              ),
              const SizedBox(height: 10),
              for (final quiz in group.quizzes)
                _QuizRow(
                  quiz: quiz,
                  lessonTitle: _lessons[quiz.linkedLessonId],
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuizQuestionsScreen(quiz: quiz),
                    ),
                  ),
                ),
              const SizedBox(height: 18),
            ],

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
        text: 'No courses yet.',
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

  /// Only published exam types come back from /courses/:id/course-types, so a
  /// draft type is absent here - that is the endpoint, not an empty course.
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
            child: const Text('Retry')),
      );
    }

    if (_types.isEmpty) {
      return const _Notice(
        icon: Icons.category_outlined,
        text: 'This course has no published exam type.',
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
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

class _ChapterHeader extends StatelessWidget {
  final String title;
  final int quizCount;

  const _ChapterHeader({required this.title, required this.quizCount});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Icon(Icons.folder_outlined, size: 15, color: LmsColors.textGrey),
          const SizedBox(width: 8),
          Text(title.toUpperCase(),
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: LmsColors.textGrey,
              )),
          const SizedBox(width: 8),
          Text('· $quizCount',
              style:
                  const TextStyle(fontSize: 10.5, color: LmsColors.textGrey)),
          const Expanded(child: Divider(indent: 12, color: LmsColors.border)),
        ],
      );
}

class _QuizRow extends StatelessWidget {
  final Quiz quiz;
  final String? lessonTitle;
  final VoidCallback onTap;

  const _QuizRow({
    required this.quiz,
    required this.lessonTitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final inactive = quiz.status.toLowerCase() != 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: LmsColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: quiz.isUnderfilled
              ? const Color(0xFFB8860B).withValues(alpha: 0.4)
              : LmsColors.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(quiz.title,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
              ),
              if (inactive) const _Tag('INACTIVE', LmsColors.textGrey),
              if (quiz.isUnderfilled) ...[
                const SizedBox(width: 6),
                const _Tag('UNDERFILLED', Color(0xFFB8860B)),
              ],
            ],
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 14,
            runSpacing: 5,
            children: [
              if (lessonTitle != null)
                _Meta(Icons.play_circle_outline_rounded, lessonTitle!),
              if (quiz.subjectName != null)
                _Meta(Icons.category_outlined, quiz.subjectName!),
              if (quiz.topicName != null)
                _Meta(Icons.label_outline_rounded, quiz.topicName!),
              // servedQuestions is what a student actually sees; available is
              // what the bank could offer. The gap is the whole point of the
              // underfilled flag.
              _Meta(Icons.help_outline_rounded,
                  '${quiz.servedQuestions} served of ${quiz.availableQuestions}'),
            ],
          ),
        ],
      ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? LmsColors.primary : LmsColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? LmsColors.primary : LmsColors.border),
          ),
          child: Text(title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : LmsColors.textDark,
              )),
        ),
      );
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;

  const _Tag(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w800, color: color)),
      );
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
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(text,
                style:
                    const TextStyle(fontSize: 11, color: LmsColors.textGrey),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      );
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
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style:
                      TextStyle(fontSize: 12.5, height: 1.35, color: color)),
            ),
            if (action != null) action!,
          ],
        ),
      );
}
