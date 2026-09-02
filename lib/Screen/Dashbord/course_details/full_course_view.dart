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
    final Color badgeColor = isPremium
        ? LmsColors.primary
        : const Color(0xFF4C6FFF);
    final IconData badgeIcon = isPremium
        ? Icons.workspace_premium_rounded
        : Icons.lock_open_rounded;
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
              colors: [
                Color(0xFF1B1D22),
                LmsColors.textDark,
                Color(0xFF0D0E11),
              ],
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
                        Icon(
                          badgeIcon,
                          color: badgeColor.withOpacity(0.9),
                          size: 18,
                        ),
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
          label:
              '${course.chapterCount} syllabus items · ${course.lessonCount} lessons',
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

  /// Listing and reading only - every add / edit / delete affordance comes out
  /// of the tree rather than being disabled, so there is nothing to click that
  /// then refuses.
  final bool readOnly;

  /// Reloads the course after a reorder, so the chapter counts and the
  /// student outline agree with what was just saved.
  final VoidCallback? onRefresh;

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
    this.readOnly = false,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final lessonCount = courseType.chapters.fold<int>(
      0,
      (sum, ch) => sum + ch.lessons.length,
    );
    final isPremium = courseType.accessType.toLowerCase() == 'premium';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: LmsColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: LmsColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
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
                  decoration: BoxDecoration(
                    color: LmsColors.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.assignment_outlined,
                    color: LmsColors.primary,
                    size: 20,
                  ),
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15.5,
                                color: LmsColors.textDark,
                              ),
                            ),
                          ),
                          if (isPremium) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.workspace_premium_rounded,
                              size: 14,
                              color: LmsColors.primary,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${courseType.chapters.length} chapters · $lessonCount lessons',
                        style: const TextStyle(
                          fontSize: 12,
                          color: LmsColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                PillChip(
                  icon: Icons.circle,
                  iconSize: 8,
                  label: courseType.status,
                  color: statusColor,
                ),
                if (!readOnly)
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: LmsColors.textGrey,
                      size: 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (ctx) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit subject')),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete subject'),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          if (courseType.description != null &&
              courseType.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                courseType.description!,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: LmsColors.textGrey,
                  height: 1.4,
                ),
              ),
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
                onEdit: readOnly ? null : () => onEditChapter(chapter),
                onDelete: readOnly ? null : () => onDeleteChapter(chapter),
                onAddLesson: readOnly ? null : () => onAddLesson(chapter),
                onEditLesson: readOnly
                    ? null
                    : (lesson) => onEditLesson(chapter, lesson),
                onDeleteLesson: readOnly
                    ? null
                    : (lesson) => onDeleteLesson(chapter, lesson),
                onEditLessonSubscription:
                    readOnly || onEditLessonSubscription == null
                    ? null
                    : (lesson) => onEditLessonSubscription!(chapter, lesson),
                // Refreshes the course so the chapter counts and the student
                // outline agree with what was just saved.
                onReordered: readOnly ? null : onRefresh,
              );
            }),

          if (!readOnly)
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text(
                    'Add Syllabus',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
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

class ChapterTile extends StatefulWidget {
  final Chapter chapter;
  final int chapterNumber;
  final Map<int, String> planTitles;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onAddLesson;
  final void Function(Lesson lesson)? onEditLesson;
  final void Function(Lesson lesson)? onDeleteLesson;
  final void Function(Lesson lesson)? onEditLessonSubscription;

  /// Called after a successful reorder so the parent can refresh.
  ///
  /// Null also means "not reorderable" - the read-only dashboard view passes
  /// nothing, and the drag handles disappear with it rather than offering a
  /// gesture that would be refused.
  final VoidCallback? onReordered;

  const ChapterTile({
    super.key,
    required this.chapter,
    required this.chapterNumber,
    this.planTitles = const {},
    this.onEdit,
    this.onDelete,
    this.onAddLesson,
    this.onEditLesson,
    this.onDeleteLesson,
    this.onEditLessonSubscription,
    this.onReordered,
  });

  @override
  State<ChapterTile> createState() => _ChapterTileState();
}

class _ChapterTileState extends State<ChapterTile> {
  final _lessonService = LessonService();

  /// The order being shown. Seeded from the chapter and updated on a drop, so
  /// the row lands where it was dropped rather than after the round trip.
  List<Lesson>? _order;
  bool _isSaving = false;

  Chapter get chapter => widget.chapter;
  List<Lesson> get _lessons => _order ?? chapter.lessons;

  @override
  void didUpdateWidget(ChapterTile old) {
    super.didUpdateWidget(old);

    // Chapter has no value equality, so `old.chapter != widget.chapter` is an
    // identity check that fires on any parent rebuild - including ones that
    // pass the same stale data. Dropping the local order there would snap the
    // list back to what the server said before the reorder. Only a genuinely
    // different set of lessons is a reload worth deferring to.
    final oldIds = old.chapter.lessons.map((l) => l.id).toList();
    final newIds = widget.chapter.lessons.map((l) => l.id).toList();
    if (!_sameIds(oldIds, newIds)) _order = null;
  }

  static bool _sameIds(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Sends the whole chapter in its new order.
  ///
  /// The endpoint assigns positions from the array index and rejects any id
  /// that is not in this chapter, so the list posted is exactly the list
  /// shown - no target-position arithmetic here.
  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (_isSaving) return;

    final moved = [..._lessons];
    // ReorderableListView reports the target as if the dragged row were still
    // in place, so an index below it is one too high.
    if (newIndex > oldIndex) newIndex -= 1;
    moved.insert(newIndex, moved.removeAt(oldIndex));

    final previous = _order;
    setState(() {
      _order = moved;
      _isSaving = true;
    });

    final result = await _lessonService.reorderLessons(
      chapterId: chapter.id,
      lessonIds: moved.map((l) => l.id).toList(),
    );

    if (!mounted) return;
    setState(() {
      _isSaving = false;
      if (result.isSuccess) {
        // The server returns the chapter in its saved order - trust that over
        // the local guess, but fall back to it if the body was empty.
        final saved = (result.data ?? const <Map<String, dynamic>>[])
            .map(Lesson.fromJson)
            .toList();
        _order = saved.isEmpty ? moved : saved;
      } else {
        // Put it back: a row that stayed where it was dropped after a failed
        // save is a lie about what students will see.
        _order = previous;
      }
    });

    if (result.isSuccess) {
      widget.onReordered?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Could not save the new order'),
          backgroundColor: LmsColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool showChapterActions =
        widget.onEdit != null || widget.onDelete != null;
    final lessons = _lessons;
    // One lesson cannot be reordered, so it gets no handle either.
    final bool canReorder = widget.onReordered != null && lessons.length > 1;

    // The card this sits in paints its own background, which would cover the
    // header tile's ink splashes - so it gets its own transparent Material to
    // splash onto. Without it Flutter asserts on every frame.
    return Material(
      color: Colors.transparent,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          // A folder with its number on it. The bare digit in a grey square
          // read as a list marker; the icon says "this opens" before the
          // chevron does, and the number keeps the reading order visible.
          leading: SizedBox(
            width: 34,
            height: 34,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: LmsColors.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.folder_copy_rounded,
                    size: 17,
                    color: LmsColors.primary,
                  ),
                ),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    width: 17,
                    height: 17,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: LmsColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.6),
                    ),
                    child: Text(
                      '${widget.chapterNumber}',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          title: Text(
            chapter.title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Text(
            '${chapter.lessons.length} lessons',
            style: const TextStyle(fontSize: 12, color: LmsColors.textGrey),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Moved up here from the foot of the list: adding a lesson is a
              // chapter-level action, and at the bottom it drifted further down
              // the page with every lesson added.
              if (widget.onAddLesson != null)
                TextButton(
                  onPressed: widget.onAddLesson,
                  style: TextButton.styleFrom(
                    foregroundColor: LmsColors.primary,
                    // The header row is tight, so the button carries no padding
                    // it doesn't need and no tap box beyond its own text.
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 34),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Add Lesson',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              showChapterActions
                  ? PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        size: 18,
                        color: LmsColors.textGrey,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onSelected: (value) {
                        if (value == 'edit') widget.onEdit?.call();
                        if (value == 'delete') widget.onDelete?.call();
                      },
                      itemBuilder: (ctx) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: Text('Rename syllabus'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete syllabus'),
                        ),
                      ],
                    )
                  : const Icon(
                      Icons.expand_more_rounded,
                      color: LmsColors.textGrey,
                    ),
            ],
          ),
          children: [
            if (lessons.isEmpty)
              const EmptyRow(text: 'No lessons added yet.')
            else
              // Drag to reorder. The list carries every lesson in the chapter,
              // not just the videos - the endpoint renumbers from the array,
              // so posting a filtered subset would renumber everything else
              // around it.
              ReorderableListView.builder(
                shrinkWrap: true,
                buildDefaultDragHandles: false,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: lessons.length,
                onReorder: canReorder ? _reorder : (_, __) {},
                itemBuilder: (context, index) {
                  final lesson = lessons[index];
                  return ReorderableDragStartListener(
                    key: ValueKey(lesson.id),
                    index: index,
                    child: _LessonTimelineRow(
                      lesson: lesson,
                      index: index,
                      isFirst: index == 0,
                      isLast: index == lessons.length - 1,
                      planTitles: widget.planTitles,
                      draggable: canReorder,
                      onEdit: widget.onEditLesson == null
                          ? null
                          : () => widget.onEditLesson!(lesson),
                      onDelete: widget.onDeleteLesson == null
                          ? null
                          : () => widget.onDeleteLesson!(lesson),
                      onEditSubscription:
                          widget.onEditLessonSubscription == null
                              ? null
                              : () => widget.onEditLessonSubscription!(lesson),
                    ),
                  );
                },
              ),
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 9),
                    Text('Saving the new order…',
                        style: TextStyle(
                            fontSize: 11.5, color: LmsColors.textGrey)),
                  ],
                ),
              ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

/// One lesson on the chapter's timeline.
///
/// Not a card. Cards inside an already-carded chapter stack borders three deep
/// and the eye stops reading it as a sequence. A rail with a node per lesson
/// says "these are in order" without adding another box.
class _LessonTimelineRow extends StatelessWidget {
  final Lesson lesson;
  final int index;
  final bool isFirst;
  final bool isLast;
  final Map<int, String> planTitles;

  /// Shows the grab handle. The row is only draggable where the parent has
  /// wired reordering, so the affordance never promises what it cannot do.
  final bool draggable;

  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onEditSubscription;

  const _LessonTimelineRow({
    required this.lesson,
    required this.index,
    required this.isFirst,
    required this.isLast,
    this.planTitles = const {},
    this.draggable = false,
    this.onEdit,
    this.onDelete,
    this.onEditSubscription,
  });

  /// Where the node sits from the top of the row - lines up with the middle of
  /// the title line, not the middle of the row, which drifts as badges wrap.
  static const double _nodeTop = 15;
  static const double _nodeIcon = 18;
  static const double _railWidth = 34;

  @override
  Widget build(BuildContext context) {
    final ui = LessonTypeUI.of(LessonTypeX.fromApiValue(lesson.type));
    final showActions = onEdit != null || onDelete != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LessonDetailScreen(lessonId: lesson.id),
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The handle replaces the rail's left margin rather than adding
              // width, so a draggable list is not a wider list.
              if (draggable)
                Padding(
                  padding: const EdgeInsets.only(top: 9),
                  child: Tooltip(
                    message: 'Drag to reorder',
                    child: Icon(Icons.drag_indicator_rounded,
                        size: 16, color: LmsColors.border),
                  ),
                ),
              SizedBox(
                width: _railWidth,
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    // The rail, clipped at the ends so it doesn't dangle past
                    // the first and last node.
                    Positioned(
                      top: isFirst ? _nodeTop : 0,
                      bottom: isLast ? null : 0,
                      height: isLast ? _nodeTop : null,
                      child: Container(width: 2, color: LmsColors.border),
                    ),
                    // The node carries the lesson's type, so a reorderable
                    // list still says what each row is - video, note or quiz
                    // all share one order inside a chapter.
                    Positioned(
                      top: _nodeTop - _nodeIcon / 2,
                      child: Container(
                        width: _nodeIcon,
                        height: _nodeIcon,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: ui.color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(ui.icon, size: 10, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 6, top: 6, bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lesson.title,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (onEditSubscription != null)
                            IconButton(
                              icon: Icon(
                                Icons.card_membership_rounded,
                                size: 15,
                                color: lesson.accessType == 'premium'
                                    ? kPremiumColor
                                    : LmsColors.textGrey,
                              ),
                              tooltip: 'Edit subscription',
                              visualDensity: VisualDensity.compact,
                              onPressed: onEditSubscription,
                            ),
                          if (showActions) ...[
                            IconButton(
                              icon: const Icon(
                                Icons.edit_rounded,
                                size: 15,
                                color: LmsColors.textDark,
                              ),
                              tooltip: 'Edit lesson',
                              visualDensity: VisualDensity.compact,
                              onPressed: onEdit,
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 15,
                                color: LmsColors.error,
                              ),
                              tooltip: 'Delete lesson',
                              visualDensity: VisualDensity.compact,
                              onPressed: onDelete,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
