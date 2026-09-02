import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theam/theam_dart.dart';
import '../../models/course_details_model.dart';
import '../../models/lesson_detail_model.dart';
import '../../models/panal_model.dart';
import '../../provider/course_details_provider.dart';
import '../../provider/course_type_provider.dart';
import '../../provider/chapter_provider.dart';
import '../../provider/lesson_upload_provider.dart';
import '../../services/admin_plan_services.dart';
import '../../services/lesson_detail_service.dart' as detail;
import '../../services/lesson_services.dart';
import '../../widget/breadcrumb_widget.dart';
import 'edit_course_type_sheet.dart';
import 'add_edit_chapter_sheet.dart';
import 'add_edit_lesson_sheet.dart';
import 'lesson_subscription_sheet.dart';
import 'course_details/course_details_widgets.dart';
import 'course_details/fallback_course_view.dart';
import 'course_details/full_course_view.dart';
import '../../widget/shimmer_loading.dart';

class CourseDetailsScreen extends StatefulWidget {
  final int courseId;

  /// Opened from the dashboard listing, where the course is there to be read,
  /// not managed. Every add / edit / delete affordance leaves the tree.
  final bool readOnly;

  const CourseDetailsScreen({
    Key? key,
    required this.courseId,
    this.readOnly = false,
  }) : super(key: key);

  @override
  State<CourseDetailsScreen> createState() => _CourseDetailsScreenState();
}

class _CourseDetailsScreenState extends State<CourseDetailsScreen> {
  /// planId -> plan, so lesson badges can name every plan that unlocks a
  /// lesson and the subscription sheet can show delisted ones.
  Map<int, AdminPlanModel> _plansById = {};
  Map<int, String> get _planTitles => {for (final e in _plansById.entries) e.key: e.value.title};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CourseDetailsProvider>().loadCourseDetails(widget.courseId);
    });
    _loadPlanTitles();
  }

  Future<void> _loadPlanTitles() async {
    try {
      final plans = await AdminPlanService().getPlansForCourse(widget.courseId);
      if (!mounted) return;
      setState(() => _plansById = {for (final p in plans) p.id: p});
    } catch (_) {
      // Badges fall back to "Plan #id" - not worth blocking the screen for.
    }
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

  Future<void> _refresh() {
    return context.read<CourseDetailsProvider>().loadCourseDetails(widget.courseId);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: LmsColors.textDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(message),
      ),
    );
  }

  // ── Exam type (CourseType) handlers ──────────────────────────────────

  Future<void> _openEditSheet(CourseType courseType) async {
    final updated = await showEditCourseTypeSheet(
      context,
      courseId: widget.courseId,
      courseTypeId: courseType.id,
      initialTitle: courseType.title,
      initialDescription: courseType.description,
      initialStatus: courseType.status,
      initialAccessType: courseType.accessType.isNotEmpty ? courseType.accessType : 'free',
    );

    if (updated == true) {
      _showSnack('Exam type updated');
      await _refresh();
    }
  }

  Future<void> _openAddSheet() async {
    final created = await showEditCourseTypeSheet(
      context,
      courseId: widget.courseId,
    );

    if (created == true) {
      _showSnack('Exam type added');
      await _refresh();
    }
  }

  Future<void> _confirmDelete(CourseType courseType) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete exam type?'),
        content: Text(
          'This will permanently delete "${courseType.title}" along with its '
              'chapters and lessons. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: LmsColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final deleteProvider = CourseTypeUpdateProvider();
    final success = await deleteProvider.deleteCourseType(
      courseId: widget.courseId,
      courseTypeId: courseType.id,
    );

    if (!mounted) return;
    if (success) {
      _showSnack('Exam type deleted');
      await _refresh();
    } else {
      _showSnack(deleteProvider.errorMessage ?? 'Failed to delete exam type');
    }
  }

  // ── Chapter ("syllabus") handlers ────────────────────────────────────

  Future<void> _openAddChapterSheet(CourseType courseType) async {
    final created = await showAddEditChapterSheet(
      context,
      courseTypeId: courseType.id,
      initialDisplayOrder: courseType.chapters.length,
    );

    if (created == true) {
      _showSnack('Syllabus added');
      await _refresh();
    }
  }

  Future<void> _openEditChapterSheet(CourseType courseType, Chapter chapter) async {
    final updated = await showAddEditChapterSheet(
      context,
      courseTypeId: courseType.id,
      chapterId: chapter.id,
      initialTitle: chapter.title,
    );

    if (updated == true) {
      _showSnack('Syllabus updated');
      await _refresh();
    }
  }

  Future<void> _confirmDeleteChapter(CourseType courseType, Chapter chapter) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete syllabus?'),
        content: Text(
          'This will permanently delete "${chapter.title}" and all its lessons. '
              'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: LmsColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final deleteProvider = ChapterUpdateProvider();
    final success = await deleteProvider.deleteChapter(
      courseTypeId: courseType.id,
      chapterId: chapter.id,
    );

    if (!mounted) return;
    if (success) {
      _showSnack('Syllabus deleted');
      await _refresh();
    } else {
      _showSnack(deleteProvider.errorMessage ?? 'Failed to delete syllabus');
    }
  }

  // ── Lesson handlers ──────────────────────────────────────────────────

  Future<void> _openAddLessonSheet(Chapter chapter) async {
    final created = await showAddEditLessonSheet(
      context,
      chapterId: chapter.id,
      courseId: widget.courseId, // NEW
      initialDisplayOrder: chapter.lessons.length,
    );
    if (created == true) {
      _showSnack('Lesson added');
      await _refresh();
    }
  }

  /// The course payload only carries a lesson's summary fields - no
  /// description, thumbnail or note - so editing from this list fetches the
  /// full lesson first. That's the same source LessonDetailScreen edits
  /// from, which is what keeps both entry points prefilling identically.
  Future<void> _openEditLessonSheet(Chapter chapter, Lesson lesson) async {
    final full = await _fetchFullLesson(lesson.id);
    if (full == null || !mounted) return;

    final updated = await showAddEditLessonSheet(
      context,
      chapterId: chapter.id,
      courseId: widget.courseId,
      lessonId: full.id,
      initialTitle: full.title,
      initialDescription: full.description,
      initialType: full.typeEnum,
      initialVideoUrl: full.videoUrl,
      initialVideoPublicId: full.videoPublicId,
      initialThumbnailUrl: full.thumbnailUrl,
      initialThumbnailPublicId: full.thumbnailPublicId,
      initialNoteUrl: full.noteUrl,
      initialNotePublicId: full.notePublicId,
      initialNoteFileType: full.noteFileType,
      initialQuizId: full.quizId,
      initialQuizTitle: full.quiz?.title,
      initialIsFreePreview: full.isFreePreview,
      initialAccessType: full.accessTypeEnum,
      initialStatus: full.statusEnum,
      initialPlanIds: full.planIds,
      initialPlans: full.plans,
      initialDisplayOrder: full.displayOrder,
    );
    if (updated == true) {
      _showSnack('Lesson updated');
      await _refresh();
    }
  }

  /// Blocking fetch with a barrier spinner - the backend cold-starts, and a
  /// sheet that opens several seconds after the tap reads as a dead button.
  /// Returns null (and snacks) if the fetch fails.
  Future<LessonDetail?> _fetchFullLesson(int lessonId) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: LmsColors.primary),
      ),
    );

    final result = await detail.LessonDetailsService().getLesson(lessonId: lessonId);

    if (!mounted) return null;
    Navigator.pop(context); // dismiss the barrier

    if (result.isSuccess && result.lesson != null) return result.lesson;
    _showSnack(result.errorMessage ?? 'Failed to load lesson');
    return null;
  }

  /// Access + plans straight from the list row - the same sheet the lesson
  /// detail screen opens, so there's one place these rules live.
  Future<void> _openLessonSubscriptionSheet(Chapter chapter, Lesson lesson) async {
    final saved = await showLessonSubscriptionSheet(
      context,
      courseId: widget.courseId,
      chapterId: chapter.id,
      lessonId: lesson.id,
      lessonTitle: lesson.title,
      accessType: LessonAccessTypeX.fromApiValue(lesson.accessType),
      planIds: lesson.planIds,
      isFreePreview: lesson.isFreePreview,
      attachedPlans: lesson.plans,
    );
    if (saved != true || !mounted) return;
    _showSnack('Subscription updated');
    await _loadPlanTitles();
    await _refresh();
  }

  Future<void> _confirmDeleteLesson(Chapter chapter, Lesson lesson) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete lesson?'),
        content: Text('This will permanently delete "${lesson.title}". This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: LmsColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final deleteProvider = LessonUpdateProvider();
    final success = await deleteProvider.deleteLesson(chapterId: chapter.id, lessonId: lesson.id);

    if (!mounted) return;
    if (success) {
      _showSnack('Lesson deleted');
      await _refresh();
    } else {
      _showSnack(deleteProvider.errorMessage ?? 'Failed to delete lesson');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LmsColors.bg,
      body: Consumer<CourseDetailsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: ShimmerListSkeleton(rowCount: 4),
            );
          }

          if (provider.errorMessage != null) {
            return ErrorState(message: provider.errorMessage!);
          }

          // Full tree unavailable: render what the course-types endpoint can
          // give us rather than an error page.
          if (provider.isDegraded) {
            return FallbackCourseView(
              data: provider.courseTypesOnly!,
              reason: provider.degradedReason!,
              courseId: widget.courseId,
              onRetry: _refresh,
              onAddExamType: widget.readOnly ? null : _openAddSheet,
            );
          }

          final course = provider.courseDetails;
          if (course == null) {
            return const ErrorState(message: 'No course found.');
          }

          return CustomScrollView(
            slivers: [
              PremiumHeader(course: course),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LmsBreadcrumb(path: ['Courses', course.title]),
                      const SizedBox(height: 12),
                      StatChipsRow(course: course, statusColor: _statusColor),
                      const SizedBox(height: 28),

                      SectionTitle(
                        'Exam Types',
                        count: course.courseTypes.length,
                        onAdd: widget.readOnly ? null : _openAddSheet,
                      ),
                      const SizedBox(height: 12),

                      if (course.courseTypes.isEmpty)
                        const EmptyRow(text: 'No exam types added yet.')
                      else
                        ...course.courseTypes.map(
                              (courseType) => CourseTypeCard(
                                onRefresh: _refresh,
                            courseType: courseType,
                            courseTitle: course.title,
                            readOnly: widget.readOnly,
                            planTitles: _planTitles,
                            statusColor: _statusColor(courseType.status),
                            onEdit: () => _openEditSheet(courseType),
                            onDelete: () => _confirmDelete(courseType),
                            onAddChapter: () => _openAddChapterSheet(courseType),
                            onEditChapter: (chapter) => _openEditChapterSheet(courseType, chapter),
                            onDeleteChapter: (chapter) => _confirmDeleteChapter(courseType, chapter),
                            onAddLesson: (chapter) => _openAddLessonSheet(chapter),
                            onEditLesson: (chapter, lesson) => _openEditLessonSheet(chapter, lesson),
                            onDeleteLesson: (chapter, lesson) => _confirmDeleteLesson(chapter, lesson),
                            onEditLessonSubscription: (chapter, lesson) =>
                                _openLessonSubscriptionSheet(chapter, lesson),
                          ),
                        ),

                      if (!course.hasCourseTypes) ...[
                        const SizedBox(height: 20),
                        SectionTitle('Syllabus', count: course.chapters.length),
                        const SizedBox(height: 6),
                        LmsBreadcrumb(path: ['Courses', course.title, 'Syllabus']),
                        const SizedBox(height: 12),
                        if (course.chapters.isEmpty)
                          const EmptyRow(text: 'No syllabus added yet.')
                        else
                          ...List.generate(course.chapters.length, (index) {
                            final c = course.chapters[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: LmsColors.surface,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: LmsColors.border),
                              ),
                              child: ChapterTile(
                                chapter: c,
                                chapterNumber: index + 1,
                                planTitles: _planTitles,
                                onAddLesson: widget.readOnly
                                    ? null
                                    : () => _openAddLessonSheet(c),
                                onEditLesson: widget.readOnly
                                    ? null
                                    : (lesson) => _openEditLessonSheet(c, lesson),
                                onDeleteLesson: widget.readOnly
                                    ? null
                                    : (lesson) => _confirmDeleteLesson(c, lesson),
                                onEditLessonSubscription: widget.readOnly
                                    ? null
                                    : (lesson) =>
                                        _openLessonSubscriptionSheet(c, lesson),
                              ),
                            );
                          }),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

