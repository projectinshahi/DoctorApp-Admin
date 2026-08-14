import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theam/theam_dart.dart';
import '../../models/course_details_model.dart';
import '../../provider/course_details_provider.dart';
import '../../provider/course_type_provider.dart';
import '../../provider/chapter_provider.dart';
import '../../provider/lesson_upload_provider.dart';
import '../../services/lesson_services.dart';
import '../../widget/chapter_card_widget.dart';
import 'LessonDetailScreen.dart';
import 'edit_course_type_sheet.dart';
import 'add_edit_chapter_sheet.dart';
import 'add_edit_lesson_sheet.dart';
import 'lesson_type_ui.dart';

class CourseDetailsScreen extends StatefulWidget {
  final int courseId;

  const CourseDetailsScreen({Key? key, required this.courseId}) : super(key: key);

  @override
  State<CourseDetailsScreen> createState() => _CourseDetailsScreenState();
}

class _CourseDetailsScreenState extends State<CourseDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CourseDetailsProvider>().loadCourseDetails(widget.courseId);
    });
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
      _showSnack('Chapter updated');
      await _refresh();
    }
  }

  Future<void> _confirmDeleteChapter(CourseType courseType, Chapter chapter) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete chapter?'),
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
      _showSnack('Chapter deleted');
      await _refresh();
    } else {
      _showSnack(deleteProvider.errorMessage ?? 'Failed to delete chapter');
    }
  }

  // ── Lesson handlers ──────────────────────────────────────────────────

  Future<void> _openAddLessonSheet(Chapter chapter) async {
    final created = await showAddEditLessonSheet(
      context,
      chapterId: chapter.id,
      initialDisplayOrder: chapter.lessons.length,
    );
    if (created == true) {
      _showSnack('Lesson added');
      await _refresh();
    }
  }

  Future<void> _openEditLessonSheet(Chapter chapter, Lesson lesson) async {
    final updated = await showAddEditLessonSheet(
      context,
      chapterId: chapter.id,
      lessonId: lesson.id,
      initialTitle: lesson.title,
      initialType: LessonTypeX.fromApiValue(lesson.type),
      initialContent: lesson.content,
      initialIsFreePreview: lesson.isFreePreview,
    );
    if (updated == true) {
      _showSnack('Lesson updated');
      await _refresh();
    }
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
            return const Center(
              child: CircularProgressIndicator(color: LmsColors.primary),
            );
          }

          if (provider.errorMessage != null) {
            return _ErrorState(message: provider.errorMessage!);
          }

          final course = provider.courseDetails;
          if (course == null) {
            return const _ErrorState(message: 'No course found.');
          }

          return CustomScrollView(
            slivers: [
              _PremiumHeader(course: course),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StatChipsRow(course: course, statusColor: _statusColor),
                      const SizedBox(height: 28),

                      // ─────────────────────────────────────────────
                      // Exam Types — ALWAYS shown, including the "Add
                      // Exam Type" button, even when the course has
                      // zero exam types yet (e.g. right after creation).
                      // Previously this whole block, button included,
                      // was hidden inside `if (course.hasCourseTypes)`,
                      // so a brand-new course never showed the button.
                      // ─────────────────────────────────────────────
                      _SectionTitle(
                        'Exam Types',
                        count: course.courseTypes.length,
                        onAdd: _openAddSheet,
                      ),
                      const SizedBox(height: 12),

                      if (course.courseTypes.isEmpty)
                        const EmptyRow(text: 'No exam types added yet.')
                      else
                        ...course.courseTypes.map(
                              (courseType) => _CourseTypeCard(
                            courseType: courseType,
                            statusColor: _statusColor(courseType.status),
                            onEdit: () => _openEditSheet(courseType),
                            onDelete: () => _confirmDelete(courseType),
                            onAddChapter: () => _openAddChapterSheet(courseType),
                            onEditChapter: (chapter) => _openEditChapterSheet(courseType, chapter),
                            onDeleteChapter: (chapter) => _confirmDeleteChapter(courseType, chapter),
                            onAddLesson: (chapter) => _openAddLessonSheet(chapter),
                            onEditLesson: (chapter, lesson) => _openEditLessonSheet(chapter, lesson),
                            onDeleteLesson: (chapter, lesson) => _confirmDeleteLesson(chapter, lesson),
                          ),
                        ),

                      // ─────────────────────────────────────────────
                      // Course-level Chapters — only relevant for
                      // courses that don't use exam types at all.
                      // ─────────────────────────────────────────────
                      if (!course.hasCourseTypes) ...[
                        const SizedBox(height: 20),
                        _SectionTitle('Chapters', count: course.chapters.length),
                        const SizedBox(height: 12),
                        if (course.chapters.isEmpty)
                          const EmptyRow(text: 'No chapters added yet.')
                        else
                          ...List.generate(course.chapters.length, (index) {
                            final c = course.chapters[index];
                            return ChapterCard(
                              chapter: c,
                              chapterNumber: index + 1,
                              onAddLesson: () => _openAddLessonSheet(c),
                              onEditLesson: (lesson) => _openEditLessonSheet(c, lesson),
                              onDeleteLesson: (lesson) => _confirmDeleteLesson(c, lesson),
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

// ── Header: gradient hero with title, description, back button ─────────
class _PremiumHeader extends StatelessWidget {
  final CourseDetails course;
  const _PremiumHeader({required this.course});

  @override
  Widget build(BuildContext context) {
    // Badge reflects the actual access type instead of always saying "PREMIUM COURSE".
    final bool isPremium = course.accessType.toLowerCase() == 'premium';
    final Color badgeColor = isPremium ? LmsColors.primary : const Color(0xFF4C6FFF);
    final IconData badgeIcon = isPremium ? Icons.workspace_premium_rounded : Icons.lock_open_rounded;
    final String badgeLabel = isPremium ? 'PREMIUM COURSE' : 'FREE COURSE';

    return SliverAppBar(
      pinned: true,
      expandedHeight: 210,
      backgroundColor: LmsColors.textDark,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1B1D22), LmsColors.textDark, Color(0xFF0D0E11)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -30,
                top: -30,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: badgeColor.withOpacity(0.10),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 70, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Icon(badgeIcon, color: badgeColor.withOpacity(0.9), size: 18),
                        const SizedBox(width: 6),
                        Text(
                          badgeLabel,
                          style: TextStyle(
                            color: badgeColor.withOpacity(0.9),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      course.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        height: 1.15,
                      ),
                    ),
                    if (course.description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        course.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.68),
                          fontSize: 13.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Chip row: access / status / chapter+lesson counts ───────────────────
class _StatChipsRow extends StatelessWidget {
  final CourseDetails course;
  final Color Function(String) statusColor;

  const _StatChipsRow({required this.course, required this.statusColor});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _PillChip(
          icon: course.accessType.toLowerCase() == 'premium'
              ? Icons.workspace_premium_rounded
              : Icons.lock_open_rounded,
          label: course.accessType.toUpperCase(),
          color: course.accessType.toLowerCase() == 'premium'
              ? LmsColors.primary
              : const Color(0xFF4C6FFF),
        ),
        _PillChip(
          icon: Icons.circle,
          iconSize: 9,
          label: course.status.toUpperCase(),
          color: statusColor(course.status),
        ),
        _PillChip(
          icon: Icons.menu_book_rounded,
          label: '${course.chapterCount} chapters · ${course.lessonCount} lessons',
          color: LmsColors.textDark,
        ),
      ],
    );
  }
}

class _PillChip extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final String label;
  final Color color;

  const _PillChip({
    required this.icon,
    required this.label,
    required this.color,
    this.iconSize = 15,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final int count;
  final VoidCallback? onAdd;
  const _SectionTitle(this.title, {required this.count, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: LmsColors.textDark,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: LmsColors.textDark.withOpacity(0.06),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: LmsColors.textDark,
            ),
          ),
        ),
        const Spacer(),
        if (onAdd != null)
          TextButton.icon(
            onPressed: onAdd,
            style: TextButton.styleFrom(
              foregroundColor: LmsColors.primary,
              backgroundColor: LmsColors.primarySoft,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text(
              'Add Exam Type',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
            ),
          ),
      ],
    );
  }
}

// ── Subject card - cleaner header, numbered chapter list ──
class _CourseTypeCard extends StatelessWidget {
  final CourseType courseType;
  final Color statusColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAddChapter;
  final void Function(Chapter chapter) onEditChapter;
  final void Function(Chapter chapter) onDeleteChapter;
  final void Function(Chapter chapter) onAddLesson;
  final void Function(Chapter chapter, Lesson lesson) onEditLesson;
  final void Function(Chapter chapter, Lesson lesson) onDeleteLesson;

  const _CourseTypeCard({
    required this.courseType,
    required this.statusColor,
    required this.onEdit,
    required this.onDelete,
    required this.onAddChapter,
    required this.onEditChapter,
    required this.onDeleteChapter,
    required this.onAddLesson,
    required this.onEditLesson,
    required this.onDeleteLesson,
  });

  @override
  Widget build(BuildContext context) {
    final lessonCount = courseType.chapters.fold<int>(0, (sum, ch) => sum + ch.lessons.length);
    final isPremium = courseType.accessType.toLowerCase() == 'premium';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: LmsColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: LmsColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row: subject name + status + overflow menu ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: LmsColors.primarySoft, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.assignment_outlined, color: LmsColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              courseType.title,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: LmsColors.textDark),
                            ),
                          ),
                          if (isPremium) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.workspace_premium_rounded, size: 14, color: LmsColors.primary),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${courseType.chapters.length} chapters · $lessonCount lessons',
                        style: const TextStyle(fontSize: 12, color: LmsColors.textGrey),
                      ),
                    ],
                  ),
                ),
                _PillChip(icon: Icons.circle, iconSize: 8, label: courseType.status, color: statusColor),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: LmsColors.textGrey, size: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit subject')),
                    PopupMenuItem(value: 'delete', child: Text('Delete subject')),
                  ],
                ),
              ],
            ),
          ),

          if (courseType.description != null && courseType.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(courseType.description!, style: const TextStyle(fontSize: 12.5, color: LmsColors.textGrey, height: 1.4)),
            ),

          const Divider(height: 1, color: LmsColors.border),

          // ── Numbered chapter list ──
          if (courseType.chapters.isEmpty)
            const EmptyRow(text: 'No syllabus added yet.')
          else
            ...List.generate(courseType.chapters.length, (index) {
              final chapter = courseType.chapters[index];
              return ChapterTile(
                chapter: chapter,
                chapterNumber: index + 1,
                onEdit: () => onEditChapter(chapter),
                onDelete: () => onDeleteChapter(chapter),
                onAddLesson: () => onAddLesson(chapter),
                onEditLesson: (lesson) => onEditLesson(chapter, lesson),
                onDeleteLesson: (lesson) => onDeleteLesson(chapter, lesson),
              );
            }),

          // ── Full-width "add syllabus" button ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onAddChapter,
                style: OutlinedButton.styleFrom(
                  foregroundColor: LmsColors.primary,
                  side: const BorderSide(color: LmsColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Chapter', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Converts 0,1,2... into A,B,C... (then AA,AB... past 25) ──────────────
String _letterLabel(int index) {
  String label = '';
  int n = index;
  do {
    label = String.fromCharCode(65 + (n % 26)) + label;
    n = (n ~/ 26) - 1;
  } while (n >= 0);
  return label;
}



// Add this import at the top of the file (adjust the path to match
// wherever your LessonDetailScreen file actually lives):
// import 'lesson_detail_screen.dart';

class ChapterTile extends StatelessWidget {
  final Chapter chapter;
  final int chapterNumber;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onAddLesson;
  final void Function(Lesson lesson)? onEditLesson;
  final void Function(Lesson lesson)? onDeleteLesson;

  const ChapterTile({
    required this.chapter,
    required this.chapterNumber,
    this.onEdit,
    this.onDelete,
    this.onAddLesson,
    this.onEditLesson,
    this.onDeleteLesson,
  });

  void _openLessonDetail(BuildContext context, Lesson lesson) {
    // lesson.id is already on the object — no extra lookup needed.
    final int lessonId = lesson.id;

    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => LessonDetailScreen(
    //       lesson: lesson, // full object — id, title, videoUrl, noteUrl, etc.
    //       // lessonId: lessonId, // uncomment if you add this param to LessonDetailScreen
    //     ),
    //   ),
    // );
  }

  @override
  Widget build(BuildContext context) {
    final bool showChapterActions = onEdit != null || onDelete != null;
    final bool showLessonActions = onEditLesson != null || onDeleteLesson != null;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        leading: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: LmsColors.textDark.withOpacity(0.06), borderRadius: BorderRadius.circular(9)),
          child: Text(
            '$chapterNumber',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: LmsColors.textDark),
          ),
        ),
        title: Text(chapter.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text('${chapter.lessons.length} lessons', style: const TextStyle(fontSize: 12, color: LmsColors.textGrey)),
        trailing: showChapterActions
            ? PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, size: 18, color: LmsColors.textGrey),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (value) {
            if (value == 'edit') onEdit?.call();
            if (value == 'delete') onDelete?.call();
          },
          itemBuilder: (ctx) => const [
            PopupMenuItem(value: 'edit', child: Text('Rename chapter')),
            PopupMenuItem(value: 'delete', child: Text('Delete chapter')),
          ],
        )
            : const Icon(Icons.expand_more_rounded, color: LmsColors.textGrey),
        children: [
          if (chapter.lessons.isEmpty)
            const EmptyRow(text: 'No lessons added yet.')
          else
            ...List.generate(chapter.lessons.length, (index) {
              final lesson = chapter.lessons[index];
              final ui = LessonTypeUI.of(LessonTypeX.fromApiValue(lesson.type));

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: LmsColors.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border(left: BorderSide(color: ui.color, width: 3)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      print(lesson.id.toString());
                      // final String LessonsId = lesson.id.toString();
                      // print(Lesson);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => LessonDetailScreen(lessonId: lesson.id)));
                    },
                    //=> _openLessonDetail(context, lesson),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: ui.color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                            child: Text(
                              _letterLabel(index),
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: ui.color),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(lesson.title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                                Text(lesson.id.toString()),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(ui.icon, size: 12, color: ui.color),
                                    const SizedBox(width: 4),
                                    Text(ui.label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: ui.color)),
                                    if (lesson.isFreePreview) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: LmsColors.success.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: const Text(
                                          'Free preview',
                                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: LmsColors.success),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (showLessonActions) ...[
                            IconButton(
                              icon: const Icon(Icons.edit_rounded, size: 15, color: LmsColors.textDark),
                              tooltip: 'Edit lesson',
                              onPressed: onEditLesson != null ? () => onEditLesson!(lesson) : null,
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 15, color: LmsColors.error),
                              tooltip: 'Delete lesson',
                              onPressed: onDeleteLesson != null ? () => onDeleteLesson!(lesson) : null,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          if (onAddLesson != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: onAddLesson,
                  style: TextButton.styleFrom(
                    foregroundColor: LmsColors.primary,
                    backgroundColor: LmsColors.primarySoft,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Add Lesson', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// class ChapterTile extends StatelessWidget {
//   final Chapter chapter;
//   final int chapterNumber;
//   final VoidCallback? onEdit;
//   final VoidCallback? onDelete;
//   final VoidCallback? onAddLesson;
//   final void Function(Lesson lesson)? onEditLesson;
//   final void Function(Lesson lesson)? onDeleteLesson;
//
//   const ChapterTile({
//     required this.chapter,
//     required this.chapterNumber,
//     this.onEdit,
//     this.onDelete,
//     this.onAddLesson,
//     this.onEditLesson,
//     this.onDeleteLesson,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final bool showChapterActions = onEdit != null || onDelete != null;
//     final bool showLessonActions = onEditLesson != null || onDeleteLesson != null;
//
//     return Theme(
//       data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
//       child: ExpansionTile(
//         tilePadding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
//         childrenPadding: const EdgeInsets.only(bottom: 8),
//         leading: Container(
//           width: 30,
//           height: 30,
//           alignment: Alignment.center,
//           decoration: BoxDecoration(color: LmsColors.textDark.withOpacity(0.06), borderRadius: BorderRadius.circular(9)),
//           child: Text(
//             '$chapterNumber',
//             style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: LmsColors.textDark),
//           ),
//         ),
//         title: Text(chapter.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
//         subtitle: Text('${chapter.lessons.length} lessons', style: const TextStyle(fontSize: 12, color: LmsColors.textGrey)),
//         trailing: showChapterActions
//             ? PopupMenuButton<String>(
//           icon: const Icon(Icons.more_vert_rounded, size: 18, color: LmsColors.textGrey),
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//           onSelected: (value) {
//             if (value == 'edit') onEdit?.call();
//             if (value == 'delete') onDelete?.call();
//           },
//           itemBuilder: (ctx) => const [
//             PopupMenuItem(value: 'edit', child: Text('Rename chapter')),
//             PopupMenuItem(value: 'delete', child: Text('Delete chapter')),
//           ],
//         )
//             : const Icon(Icons.expand_more_rounded, color: LmsColors.textGrey),
//         children: [
//           if (chapter.lessons.isEmpty)
//             const EmptyRow(text: 'No lessons added yet.')
//           else
//             ...List.generate(chapter.lessons.length, (index) {
//               final lesson = chapter.lessons[index];
//               final ui = LessonTypeUI.of(LessonTypeX.fromApiValue(lesson.type));
//
//               return Container(
//                 margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
//                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
//                 decoration: BoxDecoration(
//                   color: LmsColors.bg,
//                   borderRadius: BorderRadius.circular(12),
//                   border: Border(left: BorderSide(color: ui.color, width: 3)),
//                 ),
//                 child: Row(
//                   children: [
//                     Container(
//                       width: 26,
//                       height: 26,
//                       alignment: Alignment.center,
//                       decoration: BoxDecoration(color: ui.color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
//                       child: Text(
//                         _letterLabel(index),
//                         style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: ui.color),
//                       ),
//                     ),
//                     const SizedBox(width: 10),
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(lesson.title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
//                           const SizedBox(height: 2),
//                           Row(
//                             children: [
//                               Icon(ui.icon, size: 12, color: ui.color),
//                               const SizedBox(width: 4),
//                               Text(ui.label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: ui.color)),
//                               if (lesson.isFreePreview) ...[
//                                 const SizedBox(width: 8),
//                                 Container(
//                                   padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
//                                   decoration: BoxDecoration(
//                                     color: LmsColors.success.withOpacity(0.12),
//                                     borderRadius: BorderRadius.circular(20),
//                                   ),
//                                   child: const Text(
//                                     'Free preview',
//                                     style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: LmsColors.success),
//                                   ),
//                                 ),
//                               ],
//                             ],
//                           ),
//                         ],
//                       ),
//                     ),
//                     if (showLessonActions) ...[
//                       IconButton(
//                         icon: const Icon(Icons.edit_rounded, size: 15, color: LmsColors.textDark),
//                         tooltip: 'Edit lesson',
//                         onPressed: onEditLesson != null ? () => onEditLesson!(lesson) : null,
//                       ),
//                       IconButton(
//                         icon: const Icon(Icons.delete_outline_rounded, size: 15, color: LmsColors.error),
//                         tooltip: 'Delete lesson',
//                         onPressed: onDeleteLesson != null ? () => onDeleteLesson!(lesson) : null,
//                       ),
//                     ],
//                   ],
//                 ),
//               );
//             }),
//           if (onAddLesson != null)
//             Padding(
//               padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
//               child: SizedBox(
//                 width: double.infinity,
//                 child: TextButton.icon(
//                   onPressed: onAddLesson,
//                   style: TextButton.styleFrom(
//                     foregroundColor: LmsColors.primary,
//                     backgroundColor: LmsColors.primarySoft,
//                     padding: const EdgeInsets.symmetric(vertical: 10),
//                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//                   ),
//                   icon: const Icon(Icons.add_rounded, size: 16),
//                   label: const Text('Add Lesson', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }

class EmptyRow extends StatelessWidget {
  final String text;
  const EmptyRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(text, style: const TextStyle(color: LmsColors.textGrey, fontSize: 13)),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: LmsColors.error, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: LmsColors.error)),
          ],
        ),
      ),
    );
  }
}