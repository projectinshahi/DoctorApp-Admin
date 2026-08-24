import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theam/theam_dart.dart';
import '../../models/course_get_model.dart';
import '../../provider/admin_student_provider.dart';
import '../../provider/course_get_provider.dart';
import '../../widget/shimmer_loading.dart';
import 'course_details_screen.dart';

/// The dashboard landing view: real counts, then every course as a card.
///
/// Both numbers and cards come from GET /api/courses, which already carries
/// the course types per course. The student total comes from the students
/// endpoint's pagination block - the list itself isn't needed, only its
/// `total`, so it is asked for one row at a time.
class DashboardOverview extends StatefulWidget {
  const DashboardOverview({super.key});

  @override
  State<DashboardOverview> createState() => _DashboardOverviewState();
}

class _DashboardOverviewState extends State<DashboardOverview> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CourseListGetProvider>().fetchCourses(limit: 100);
      // limit 1: only pagination.total is read, so a full page is wasted work.
      context.read<AdminStudentProvider>().loadStudents(page: 1, limit: 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final courseProvider = context.watch<CourseListGetProvider>();
    final studentProvider = context.watch<AdminStudentProvider>();
    final courses = courseProvider.courses;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Hero(
            courseCount: courses.length,
            studentCount: studentProvider.pagination?.total,
          ),
          const SizedBox(height: 22),

          // Only the very first load gets the skeleton. A manual reload keeps
          // the numbers on screen and updates them in place, which is less
          // jarring than the whole row flashing back to grey.
          if (courseProvider.isLoadingCourses && courses.isEmpty)
            LayoutBuilder(
              builder: (context, constraints) => ShimmerStatTiles(
                columns: constraints.maxWidth > 1000
                    ? 4
                    : constraints.maxWidth > 560
                    ? 2
                    : 1,
              ),
            )
          else
            _StatGrid(
              isLoading: courseProvider.isLoadingCourses,
              courses: courses,
              studentTotal: studentProvider.pagination?.total,
              studentError: studentProvider.errorMessage,
              studentLoading: studentProvider.isLoading,
            ),
          const SizedBox(height: 26),

          Row(
            children: [
              const Text(
                'Courses',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 8),
              if (!courseProvider.isLoadingCourses)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: LmsColors.primarySoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${courses.length}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: LmsColors.primary,
                    ),
                  ),
                ),
              const Spacer(),
              IconButton(
                tooltip: 'Reload',
                onPressed: courseProvider.isLoadingCourses
                    ? null
                    : () => courseProvider.fetchCourses(limit: 100),
                icon: const Icon(Icons.refresh_rounded, size: 19),
                color: LmsColors.textGrey,
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (courseProvider.isLoadingCourses && courses.isEmpty)
            const ShimmerCardGrid(count: 4)
          else if (courseProvider.coursesErrorMessage != null)
            _ErrorCard(
              message: courseProvider.coursesErrorMessage!,
              onRetry: () => courseProvider.fetchCourses(limit: 100),
            )
          else if (courses.isEmpty)
            const _EmptyCard(text: 'No courses yet.')
          else
            _CourseGrid(courses: courses),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// The headline numbers, all derived from the loaded courses except the
/// student total.
class _StatGrid extends StatelessWidget {
  final bool isLoading;
  final List<CourseListGetModel> courses;
  final int? studentTotal;
  final String? studentError;
  final bool studentLoading;

  const _StatGrid({
    required this.isLoading,
    required this.courses,
    required this.studentTotal,
    required this.studentError,
    required this.studentLoading,
  });

  @override
  Widget build(BuildContext context) {
    final examTypes = courses.fold<int>(
      0,
      (sum, c) => sum + c.courseTypes.length,
    );
    final lessons = courses.fold<int>(0, (sum, c) => sum + c.lessonCount);
    final published = courses.where((c) => c.status == 'published').length;
    final premium = courses.where((c) => c.accessType == 'premium').length;

    final tiles = <Widget>[
      _StatTile(
        icon: Icons.people_alt_rounded,
        color: const Color(0xFF4C6FFF),
        label: 'Registered students',
        // An unreachable endpoint must not read as "0 students".
        value: studentLoading
            ? '...'
            : studentError != null
            ? '--'
            : '${studentTotal ?? 0}',
        note: studentError != null ? 'Not available' : null,
      ),
      _StatTile(
        icon: Icons.menu_book_rounded,
        color: const Color(0xFF9C5FFF),
        label: 'Courses',
        value: isLoading ? '...' : '${courses.length}',
        note: isLoading ? null : '$published published',
      ),
      _StatTile(
        icon: Icons.category_rounded,
        color: const Color(0xFFFF9F43),
        label: 'Exam types',
        value: isLoading ? '...' : '$examTypes',
      ),
      _StatTile(
        icon: Icons.workspace_premium_rounded,
        color: const Color(0xFF19B37A),
        label: 'Premium courses',
        value: isLoading ? '...' : '$premium',
        note: lessons > 0 ? '$lessons lessons' : null,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Four across on a desk, two on a tablet, one on a phone.
        final columns = constraints.maxWidth > 1000
            ? 4
            : constraints.maxWidth > 560
            ? 2
            : 1;
        const gap = 16.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String? note;

  const _StatTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: LmsColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: LmsColors.border),
        boxShadow: [
          // Barely there on purpose - enough to lift the card off the page
          // without the drop-shadow look that dates an admin panel.
          BoxShadow(
            color: LmsColors.textDark.withValues(alpha: 0.045),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      // The tile sits in a Wrap, so its height is unbounded. A Row using
      // CrossAxisAlignment.stretch asks its children to fill that height and
      // asserts on the infinity - IntrinsicHeight measures the content first
      // and hands the Row a real number, which is what the spine needs to run
      // the full height of the card.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Accent spine, the one place each tile's colour is fully saturated.
            Container(width: 4, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(15, 16, 15, 16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            color.withValues(alpha: 0.18),
                            color.withValues(alpha: 0.06),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(icon, size: 21, color: color),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            value,
                            style: const TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            label,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: LmsColors.textGrey,
                            ),
                          ),
                          if (note != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              note!,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: color,
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
          ],
        ),
      ),
    );
  }
}

/// The welcome band. Gives the page a top edge and somewhere for the two
/// numbers that matter most to live before the detail starts.
class _Hero extends StatelessWidget {
  final int courseCount;
  final int? studentCount;

  const _Hero({required this.courseCount, required this.studentCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(26, 26, 26, 26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1F2544), Color(0xFF3B3F73), Color(0xFF5A4B8C)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'ADMIN',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "dr.skm's academy",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            studentCount == null
                ? '$courseCount course${courseCount == 1 ? '' : 's'} published to your catalogue.'
                : '$courseCount course${courseCount == 1 ? '' : 's'} · '
                      '$studentCount registered student${studentCount == 1 ? '' : 's'}.',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseGrid extends StatelessWidget {
  final List<CourseListGetModel> courses;

  const _CourseGrid({required this.courses});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 16.0;
        const minCardWidth = 280.0;
        final columns = (constraints.maxWidth / (minCardWidth + gap))
            .floor()
            .clamp(1, 4);
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final course in courses)
              SizedBox(
                width: width,
                child: _CourseCard(course: course),
              ),
          ],
        );
      },
    );
  }
}

class _CourseCard extends StatelessWidget {
  final CourseListGetModel course;

  const _CourseCard({required this.course});

  @override
  Widget build(BuildContext context) {
    final isPremium = course.accessType == 'premium';
    final isPublished = course.status == 'published';

    return Material(
      color: LmsColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                CourseDetailsScreen(courseId: course.id, readOnly: true),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: LmsColors.border),
            boxShadow: [
              BoxShadow(
                color: LmsColors.textDark.withValues(alpha: 0.045),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail, or a tinted band with the course's initial when
              // there isn't one - a grey box would read as a broken image.
              AspectRatio(
                aspectRatio: 16 / 7,
                child: course.thumbnail != null && course.thumbnail!.isNotEmpty
                    ? Image.network(
                        course.thumbnail!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _Placeholder(title: course.title),
                      )
                    : _Placeholder(title: course.title),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _Pill(
                          text: isPublished
                              ? 'PUBLISHED'
                              : course.status.toUpperCase(),
                          color: isPublished
                              ? LmsColors.success
                              : LmsColors.textGrey,
                        ),
                        if (isPremium)
                          const _Pill(
                            text: 'PREMIUM',
                            color: Color(0xFFB8860B),
                          ),
                        _Pill(
                          text:
                              '${course.courseTypes.length} exam type'
                              '${course.courseTypes.length == 1 ? '' : 's'}',
                          color: LmsColors.primary,
                        ),
                      ],
                    ),
                    if (course.courseTypes.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        course.courseTypes.map((t) => t.title).join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: LmsColors.textGrey,
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

class _Placeholder extends StatelessWidget {
  final String title;
  const _Placeholder({required this.title});

  @override
  Widget build(BuildContext context) {
    // Same title always gets the same colour, so cards stay recognisable
    // across reloads instead of reshuffling.
    const palette = [
      Color(0xFF4C6FFF),
      Color(0xFF9C5FFF),
      Color(0xFFFF9F43),
      Color(0xFF19B37A),
      Color(0xFFE0576B),
    ];
    final color = palette[title.hashCode.abs() % palette.length];

    return Container(
      color: color.withValues(alpha: 0.13),
      alignment: Alignment.center,
      child: Text(
        title.trim().isEmpty ? '?' : title.trim()[0].toUpperCase(),
        style: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;

  const _Pill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LmsColors.errorBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LmsColors.errorBorder),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: LmsColors.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12.5, color: LmsColors.error),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String text;
  const _EmptyCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: LmsColors.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LmsColors.border),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, color: LmsColors.textGrey),
      ),
    );
  }
}
