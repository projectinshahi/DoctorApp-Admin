import 'package:flutter/material.dart';

import '../../../core/const/responsive_const.dart';
import '../../../core/theam/theam_dart.dart';
import '../../../models/chapter_summary_model.dart';
import '../../../models/course_types_model.dart';
import '../../../models/lesson_model.dart' as flat;
import '../../../provider/chapter_provider.dart';
import '../../../provider/lesson_upload_provider.dart';
import '../../../widget/breadcrumb_widget.dart';
import '../LessonDetailScreen.dart';
import '../add_edit_chapter_sheet.dart';
import '../add_edit_lesson_sheet.dart';
import 'course_details_widgets.dart';

/// The fallback course details view, used when GET /api/courses/:id fails.
///
/// Rebuilds the tree from two narrower routes:
///   /api/courses/:id/course-types    (public)  -> exam types
///   /api/course-types/:id/chapters   (admin)   -> chapters WITH lessons nested
///
/// The chapters route returns each chapter's lessons already nested and
/// sorted, so one request per exam type loads its entire subtree.

class FallbackCourseView extends StatefulWidget {
  final CourseTypesResponse data;
  final String reason;
  final int courseId;
  final Future<void> Function() onRetry;
  final VoidCallback? onAddExamType;

  const FallbackCourseView({
    required this.data,
    required this.reason,
    required this.courseId,
    required this.onRetry,
    this.onAddExamType,
  });

  @override
  State<FallbackCourseView> createState() => FallbackCourseViewState();
}

class FallbackCourseViewState extends State<FallbackCourseView> {
  final _searchController = TextEditingController();
  String _search = '';
  String? _accessFilter; // null = any

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CourseTypeSummary> get _visibleTypes {
    final query = _search.trim().toLowerCase();
    return widget.data.courseTypes.where((t) {
      final matchesAccess = _accessFilter == null || t.accessType == _accessFilter;
      final matchesQuery = query.isEmpty ||
          t.title.toLowerCase().contains(query) ||
          (t.description ?? '').toLowerCase().contains(query);
      return matchesAccess && matchesQuery;
    }).toList();
  }

  bool get _hasFilters => _search.trim().isNotEmpty || _accessFilter != null;

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _search = '';
      _accessFilter = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleTypes;
    final total = widget.data.courseTypes.length;

    return RefreshIndicator(
      onRefresh: widget.onRetry,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          LmsBreadcrumb(path: ['Courses', widget.data.courseTitle]),
          const SizedBox(height: 12),
          Text(
            widget.data.courseTitle,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: LmsColors.textDark,
            ),
          ),
          const SizedBox(height: 16),
          FallbackBanner(reason: widget.reason, onRetry: widget.onRetry),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: Text(
                  _hasFilters
                      ? 'Exam Types (${visible.length} of $total)'
                      : 'Exam Types ($total)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: LmsColors.textDark,
                  ),
                ),
              ),
              // Absent, not disabled - a read-only view offers nothing to
              // click that would then refuse.
              if (widget.onAddExamType != null)
                TextButton.icon(
                  onPressed: widget.onAddExamType,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Add Exam Type',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Published exam types only — drafts are not returned by this endpoint.',
            style: TextStyle(fontSize: 11.5, color: LmsColors.textGrey),
          ),
          const SizedBox(height: 12),

          ExamTypeFilterBar(
            searchController: _searchController,
            accessFilter: _accessFilter,
            hasFilters: _hasFilters,
            onSearchChanged: (v) => setState(() => _search = v),
            onAccessChanged: (v) => setState(() => _accessFilter = v),
            onClear: _clearFilters,
          ),
          const SizedBox(height: 14),

          if (visible.isEmpty)
            EmptyRow(
              text: _hasFilters
                  ? 'No exam types match these filters.'
                  : 'No published exam types in this course.',
            )
          else
            ...visible.map(
              (examType) => ExamTypeTreeCard(
                key: ValueKey(examType.id),
                examType: examType,
                courseId: widget.courseId,
              ),
            ),
        ],
      ),
    );
  }
}

class ExamTypeFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final String? accessFilter;
  final bool hasFilters;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onAccessChanged;
  final VoidCallback onClear;

  const ExamTypeFilterBar({
    required this.searchController,
    required this.accessFilter,
    required this.hasFilters,
    required this.onSearchChanged,
    required this.onAccessChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: LmsColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LmsColors.border),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: LmsResponsive.isMobile(context) ? double.infinity : 260,
            child: TextField(
              controller: searchController,
              // Filtering is in-memory over an already-loaded list, so it can
              // update per keystroke without costing a request.
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search exam types',
                hintStyle: const TextStyle(fontSize: 13, color: LmsColors.textGrey),
                prefixIcon:
                    const Icon(Icons.search_rounded, size: 18, color: LmsColors.textGrey),
                isDense: true,
                filled: true,
                fillColor: LmsColors.bg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: LmsColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: LmsColors.primary, width: 1.4),
                ),
              ),
            ),
          ),
          for (final option in const [
            (label: 'Any access', value: null),
            (label: 'Free', value: 'free'),
            (label: 'Premium', value: 'premium'),
          ])
            ChoiceChip(
              label: Text(option.label),
              selected: accessFilter == option.value,
              onSelected: (_) => onAccessChanged(option.value),
              selectedColor: LmsColors.primarySoft,
              backgroundColor: LmsColors.bg,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: accessFilter == option.value ? LmsColors.primary : LmsColors.textDark,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: accessFilter == option.value ? LmsColors.primary : LmsColors.border,
                ),
              ),
            ),
          if (hasFilters)
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded, size: 15),
              label: const Text('Clear',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}

/// One exam type, expandable into its syllabus. Chapters are fetched the
/// first time it opens and cached in this widget's state.
class ExamTypeTreeCard extends StatefulWidget {
  final CourseTypeSummary examType;
  final int courseId;

  const ExamTypeTreeCard({super.key, required this.examType, required this.courseId});

  @override
  State<ExamTypeTreeCard> createState() => ExamTypeTreeCardState();
}

class ExamTypeTreeCardState extends State<ExamTypeTreeCard> {
  /// One provider per card - the chapters shown here belong to this exam type
  /// only, and its getChapters call prints the response to the terminal.
  final _chapters = ChapterListProvider();

  bool _expanded = false;

  bool get _isLoading => _chapters.isLoading;
  String? get _errorMessage => _chapters.errorMessage;
  List<ChapterSummary> get _chapterList => _chapters.chapters;

  @override
  void initState() {
    super.initState();
    _chapters.addListener(_onChapters);
  }

  void _onChapters() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _chapters.removeListener(_onChapters);
    _chapters.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final opening = !_expanded;
    setState(() => _expanded = opening);
    if (opening && !_chapters.loadedOnce) await _loadChapters();
  }

  Future<void> _loadChapters() => _chapters.load(widget.examType.id);

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

  Future<void> _addChapter() async {
    final created = await showAddEditChapterSheet(
      context,
      courseTypeId: widget.examType.id,
      initialDisplayOrder: _chapterList.length,
    );
    if (created == true && mounted) {
      _showSnack('Syllabus added');
      setState(() => _expanded = true);
      await _loadChapters();
    }
  }

  Future<void> _editChapter(ChapterSummary chapter) async {
    final updated = await showAddEditChapterSheet(
      context,
      courseTypeId: widget.examType.id,
      chapterId: chapter.id,
      initialTitle: chapter.title,
    );
    if (updated == true && mounted) {
      _showSnack('Syllabus updated');
      await _loadChapters();
    }
  }

  Future<void> _deleteChapter(ChapterSummary chapter) async {
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

    final provider = ChapterUpdateProvider();
    final success = await provider.deleteChapter(
      courseTypeId: widget.examType.id,
      chapterId: chapter.id,
    );

    if (!mounted) return;
    if (success) {
      _showSnack('Syllabus deleted');
      await _loadChapters();
    } else {
      _showSnack(provider.errorMessage ?? 'Failed to delete syllabus');
    }
  }

  @override
  Widget build(BuildContext context) {
    final examType = widget.examType;
    final isPremium = examType.accessType == 'premium';
    final isMobile = LmsResponsive.isMobile(context);

    // Before the chapters load, the count from the list endpoint is the only
    // number we have; afterwards the loaded list is authoritative.
    final chapterCount =
        _chapters.loadedOnce ? _chapterList.length : examType.chapterCount;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: LmsColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LmsColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _toggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: LmsColors.primarySoft,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(Icons.assignment_outlined,
                          size: 18, color: LmsColors.primary),
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
                                  examType.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: LmsColors.textDark,
                                  ),
                                ),
                              ),
                              if (isPremium) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.workspace_premium_rounded,
                                    size: 14, color: Colors.amber),
                              ],
                            ],
                          ),
                          if (examType.description != null &&
                              examType.description!.trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              examType.description!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12, color: LmsColors.textGrey),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              LmsBadge(
                                text: isPremium ? 'Premium' : 'Free',
                                color: isPremium ? LmsColors.primary : LmsColors.textGrey,
                              ),
                              LmsBadge(
                                text: '$chapterCount syllabus'
                                    '${chapterCount == 1 ? '' : ' items'}',
                                color: LmsColors.textGrey,
                              ),
                              LmsBadge(
                                text: 'Order ${examType.displayOrder}',
                                color: LmsColors.textGrey,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (isMobile)
                      IconButton(
                        onPressed: _addChapter,
                        icon: const Icon(Icons.playlist_add_rounded, size: 20),
                        color: LmsColors.primary,
                        tooltip: 'Add syllabus',
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: _addChapter,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: LmsColors.primary,
                          side: const BorderSide(color: LmsColors.primary),
                          shape:
                              RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Syllabus',
                            style:
                                TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                      ),
                    IconButton(
                      onPressed: _toggle,
                      icon: AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 150),
                        child: const Icon(Icons.expand_more_rounded, size: 22),
                      ),
                      color: LmsColors.textGrey,
                      tooltip: _expanded ? 'Hide syllabus' : 'Show syllabus',
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (_expanded) ...[
            const Divider(height: 1, color: LmsColors.border),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 22),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.2, color: LmsColors.primary),
                  ),
                ),
              )
            else if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 16, color: LmsColors.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_errorMessage!,
                              style: const TextStyle(
                                  fontSize: 12.5, color: LmsColors.error)),
                        ),
                        TextButton(
                          onPressed: _loadChapters,
                          child: const Text('Retry',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 12.5)),
                        ),
                      ],
                    ),
                    // This endpoint nests lessons, so it hits the same broken
                    // column as the full course tree. Saying so stops it
                    // reading as a second, separate fault.
                    const Padding(
                      padding: EdgeInsets.only(left: 24, top: 2),
                      child: Text(
                        'This route also reads lessons, so it fails for the same '
                        'reason as the full course endpoint. It recovers on deploy.',
                        style: TextStyle(
                            fontSize: 11.5, color: LmsColors.textGrey, height: 1.35),
                      ),
                    ),
                  ],
                ),
              )
            else if (_chapterList.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('No syllabus items yet.',
                          style:
                              TextStyle(fontSize: 12.5, color: LmsColors.textGrey)),
                    ),
                    TextButton(
                      onPressed: _addChapter,
                      child: const Text('Add the first one',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              )
            else
              ...List.generate(_chapterList.length, (index) {
                final chapter = _chapterList[index];
                return ChapterTreeTile(
                  key: ValueKey(chapter.id),
                  chapter: chapter,
                  chapterNumber: index + 1,
                  courseId: widget.courseId,
                  onEdit: () => _editChapter(chapter),
                  onDelete: () => _deleteChapter(chapter),
                  onChanged: _loadChapters,
                );
              }),
          ],
        ],
      ),
    );
  }
}

/// One chapter, expandable into its lessons.
///
/// The lessons arrive nested on the chapters response, so expanding costs
/// nothing - there is no per-chapter request. Writes bubble up to the parent,
/// which refetches the whole course type in one call.
class ChapterTreeTile extends StatefulWidget {
  final ChapterSummary chapter;
  final int chapterNumber;
  final int courseId;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Future<void> Function() onChanged;

  const ChapterTreeTile({
    super.key,
    required this.chapter,
    required this.chapterNumber,
    required this.courseId,
    required this.onEdit,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  State<ChapterTreeTile> createState() => ChapterTreeTileState();
}

class ChapterTreeTileState extends State<ChapterTreeTile> {
  bool _expanded = false;

  List<flat.Lesson> get _lessons => widget.chapter.lessons;

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

  Future<void> _addLesson() async {
    final created = await showAddEditLessonSheet(
      context,
      chapterId: widget.chapter.id,
      courseId: widget.courseId,
      initialDisplayOrder: _lessons.length,
    );
    if (created == true && mounted) {
      _showSnack('Lesson added');
      setState(() => _expanded = true);
      await widget.onChanged();
    }
  }

  Future<void> _deleteLesson(flat.Lesson lesson) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete lesson?'),
        content: Text('This will permanently delete "${lesson.title}".'),
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

    final provider = LessonUpdateProvider();
    final success = await provider.deleteLesson(
      chapterId: widget.chapter.id,
      lessonId: lesson.id,
    );

    if (!mounted) return;
    if (success) {
      _showSnack('Lesson deleted');
      await widget.onChanged();
    } else {
      _showSnack(provider.errorMessage ?? 'Failed to delete lesson');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lessonCount = _lessons.length;

    return Container(
      decoration: const BoxDecoration(
        color: LmsColors.bg,
        border: Border(top: BorderSide(color: LmsColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 6, 10),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: LmsColors.surface,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: LmsColors.border),
                      ),
                      child: Text(
                        '${widget.chapterNumber}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: LmsColors.textDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.chapter.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: LmsColors.textDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    LmsBadge(
                      text: '$lessonCount lesson${lessonCount == 1 ? '' : 's'}',
                      color: LmsColors.textGrey,
                    ),
                    IconButton(
                      onPressed: _addLesson,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      color: LmsColors.primary,
                      tooltip: 'Add lesson',
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded,
                          size: 17, color: LmsColors.textGrey),
                      onSelected: (value) =>
                          value == 'edit' ? widget.onEdit() : widget.onDelete(),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Rename syllabus')),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete syllabus',
                              style: TextStyle(color: LmsColors.error)),
                        ),
                      ],
                    ),
                    Icon(
                      _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      size: 19,
                      color: LmsColors.textGrey,
                    ),
                    const SizedBox(width: 6),
                  ],
                ),
              ),
            ),
          ),
          if (_expanded) ...[
            if (_lessons.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(52, 4, 14, 12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('No lessons in this syllabus item yet.',
                          style: TextStyle(fontSize: 12, color: LmsColors.textGrey)),
                    ),
                    TextButton(
                      onPressed: _addLesson,
                      child: const Text('Add lesson',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              )
            else
              ..._lessons.map(
                (lesson) => LessonTreeRow(
                  lesson: lesson,
                  onOpen: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => LessonDetailScreen(lessonId: lesson.id)),
                  ),
                  onDelete: () => _deleteLesson(lesson),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class LessonTreeRow extends StatelessWidget {
  final flat.Lesson lesson;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const LessonTreeRow({
    required this.lesson,
    required this.onOpen,
    required this.onDelete,
  });

  IconData get _typeIcon => switch (lesson.type) {
        'video' => Icons.play_circle_outline_rounded,
        'quiz' => Icons.quiz_outlined,
        _ => Icons.article_outlined,
      };

  Color get _statusColor => switch (lesson.status) {
        'published' => LmsColors.success,
        'archived' => LmsColors.textGrey,
        _ => Colors.orange,
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: LmsColors.surface,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(52, 9, 8, 9),
          child: Row(
            children: [
              Icon(_typeIcon, size: 16, color: LmsColors.textGrey),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  lesson.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: LmsColors.textDark,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              LmsBadge(text: lesson.status, color: _statusColor),
              const SizedBox(width: 6),
              LmsBadge(
                text: lesson.accessType == 'premium' ? 'Premium' : 'Free',
                color: lesson.accessType == 'premium'
                    ? LmsColors.primary
                    : LmsColors.textGrey,
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 17),
                color: LmsColors.textGrey,
                tooltip: 'Delete lesson',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FallbackBanner extends StatelessWidget {
  final String reason;
  final Future<void> Function() onRetry;

  const FallbackBanner({required this.reason, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LmsColors.errorBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LmsColors.errorBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 18, color: LmsColors.error),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Running on fallback endpoints',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: LmsColors.error,
                  ),
                ),
              ),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: LmsColors.error,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(52, 30),
                ),
                child: const Text('Retry',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'The full course endpoint failed, so syllabus and lessons load per '
            'section as you expand them. Everything is editable. Draft exam '
            'types are hidden until it recovers.',
            style: TextStyle(fontSize: 12, color: LmsColors.error, height: 1.4),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: LmsColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: LmsColors.errorBorder),
            ),
            child: Text(
              'Server said: $reason',
              style: const TextStyle(
                  fontSize: 11.5, color: LmsColors.textGrey, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
