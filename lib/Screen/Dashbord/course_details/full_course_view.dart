import 'package:flutter/material.dart';

import '../../../core/theam/theam_dart.dart';
import '../../../models/course_details_model.dart';
import '../../../widget/breadcrumb_widget.dart';
import '../../../services/lesson_services.dart';
import '../LessonDetailScreen.dart';
import '../lesson_badges.dart';
import '../lesson_type_ui.dart';
import 'course_details_widgets.dart';

/// The normal course details view, rendered from GET /api/courses/:id.
///
/// This is the only view that has the whole tree in one payload, so it is
/// also the only one that can show course-level chapters and per-lesson plan
/// badges without extra requests.

class PremiumHeader extends StatelessWidget {
  final CourseDetails course;
  const PremiumHeader({required this.course});

  @override
  Widget build(BuildContext context) {
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

class StatChipsRow extends StatelessWidget {
  final CourseDetails course;
  final Color Function(String) statusColor;

  const StatChipsRow({required this.course, required this.statusColor});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        PillChip(
          icon: course.accessType.toLowerCase() == 'premium'
              ? Icons.workspace_premium_rounded
              : Icons.lock_open_rounded,
          label: course.accessType.toUpperCase(),
          color: course.accessType.toLowerCase() == 'premium'
              ? LmsColors.primary
              : const Color(0xFF4C6FFF),
        ),
        PillChip(
          icon: Icons.circle,
          iconSize: 9,
          label: course.status.toUpperCase(),
          color: statusColor(course.status),
        ),
        PillChip(
          icon: Icons.menu_book_rounded,
          label: '${course.chapterCount} syllabus items · ${course.lessonCount} lessons',
          color: LmsColors.textDark,
        ),
      ],
    );
  }
}

class CourseTypeCard extends StatelessWidget {
  final CourseType courseType;
  /// Only used for the breadcrumb - the card itself is about the exam type.
  final String courseTitle;
  final Map<int, String> planTitles;
  final Color statusColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAddChapter;
  final void Function(Chapter chapter) onEditChapter;
  final void Function(Chapter chapter) onDeleteChapter;
  final void Function(Chapter chapter) onAddLesson;
  final void Function(Chapter chapter, Lesson lesson) onEditLesson;
  final void Function(Chapter chapter, Lesson lesson) onDeleteLesson;
  final void Function(Chapter chapter, Lesson lesson)? onEditLessonSubscription;

  const CourseTypeCard({
    required this.courseType,
    required this.courseTitle,
    this.planTitles = const {},
    required this.statusColor,
    required this.onEdit,
    required this.onDelete,
    required this.onAddChapter,
    required this.onEditChapter,
    required this.onDeleteChapter,
    required this.onAddLesson,
    required this.onEditLesson,
    required this.onDeleteLesson,
    this.onEditLessonSubscription,
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
                PillChip(icon: Icons.circle, iconSize: 8, label: courseType.status, color: statusColor),
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

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: LmsBreadcrumb(
              path: [courseTitle, courseType.title, 'Syllabus'],
            ),
          ),

          if (courseType.chapters.isEmpty)
            const EmptyRow(text: 'No syllabus added yet.')
          else
            ...List.generate(courseType.chapters.length, (index) {
              final chapter = courseType.chapters[index];
              return ChapterTile(
                planTitles: planTitles,
                chapter: chapter,
                chapterNumber: index + 1,
                onEdit: () => onEditChapter(chapter),
                onDelete: () => onDeleteChapter(chapter),
                onAddLesson: () => onAddLesson(chapter),
                onEditLesson: (lesson) => onEditLesson(chapter, lesson),
                onDeleteLesson: (lesson) => onDeleteLesson(chapter, lesson),
                onEditLessonSubscription: onEditLessonSubscription == null
                    ? null
                    : (lesson) => onEditLessonSubscription!(chapter, lesson),
              );
            }),

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
                label: const Text('Add Syllabus', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String letterLabel(int index) {
  String label = '';
  int n = index;
  do {
    label = String.fromCharCode(65 + (n % 26)) + label;
    n = (n ~/ 26) - 1;
  } while (n >= 0);
  return label;
}

class ChapterTile extends StatelessWidget {
  final Chapter chapter;
  final int chapterNumber;
  final Map<int, String> planTitles;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onAddLesson;
  final void Function(Lesson lesson)? onEditLesson;
  final void Function(Lesson lesson)? onDeleteLesson;
  final void Function(Lesson lesson)? onEditLessonSubscription;

  const ChapterTile({
    required this.chapter,
    required this.chapterNumber,
    this.planTitles = const {},
    this.onEdit,
    this.onDelete,
    this.onAddLesson,
    this.onEditLesson,
    this.onDeleteLesson,
    this.onEditLessonSubscription,
  });

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
            PopupMenuItem(value: 'edit', child: Text('Rename syllabus')),
            PopupMenuItem(value: 'delete', child: Text('Delete syllabus')),
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
                      Navigator.push(context, MaterialPageRoute(builder: (context) => LessonDetailScreen(lessonId: lesson.id)));
                    },
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
                              letterLabel(index),
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: ui.color),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(lesson.title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 5),
                                LessonBadgeRow(
                                  type: lesson.type,
                                  status: lesson.status,
                                  accessType: lesson.accessType,
                                  isFreePreview: lesson.isFreePreview,
                                  planLabels: [
                                    for (final id in lesson.planIds)
                                      planTitles[id] ?? 'Plan #$id',
                                  ],
                                  hasVideo: lesson.hasVideo,
                                  compact: true,
                                ),
                              ],
                            ),
                          ),
                          if (onEditLessonSubscription != null)
                            IconButton(
                              icon: Icon(
                                Icons.card_membership_rounded,
                                size: 15,
                                color: lesson.accessType == 'premium' ? kPremiumColor : LmsColors.textGrey,
                              ),
                              tooltip: 'Edit subscription',
                              onPressed: () => onEditLessonSubscription!(lesson),
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
