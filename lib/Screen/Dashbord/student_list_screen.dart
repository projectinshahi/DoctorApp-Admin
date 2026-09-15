import 'package:flutter/material.dart';

import 'student_detail_screen.dart';
import 'package:provider/provider.dart';

import '../../core/theam/theam_dart.dart';
import '../../models/admin_student_model.dart';
import '../../provider/admin_student_provider.dart';
import '../../widget/shimmer_loading.dart';
import '../../widget/student_actions.dart';

class AdminStudentListScreen extends StatefulWidget {
  const AdminStudentListScreen({super.key});

  @override
  State<AdminStudentListScreen> createState() => _AdminStudentListScreenState();
}

class _AdminStudentListScreenState extends State<AdminStudentListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminStudentProvider>().loadStudents();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminStudentProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.students.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: ShimmerListSkeleton(rowCount: 5),
          );
        }

        if (provider.errorMessage != null && provider.students.isEmpty) {
          return _ErrorState(
            message: provider.errorMessage!,
            onRetry: () => provider.loadStudents(),
          );
        }

        if (provider.students.isEmpty) {
          return const _EmptyState();
        }

        final pagination = provider.pagination;

        return Container(
          decoration: BoxDecoration(
            color: LmsColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: LmsColors.border),
          ),
          child: Column(
            children: [
              // ── Column header row (desktop/tablet only - looks odd
              // squeezed onto a phone width) ──
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 640)
                    return const SizedBox.shrink();
                  return const _ListHeaderRow();
                },
              ),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: provider.students.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: LmsColors.border),
                itemBuilder: (context, index) {
                  return _StudentRow(
                    student: provider.students[index],
                    // Re-reads the row from the server rather than patching it
                    // in place: a block also revokes sessions, and the list
                    // shows more than the one field that was sent.
                    onChanged: provider.refreshStudents,
                  );
                },
              ),
              if (pagination != null && pagination.totalPages > 1)
                _PaginationBar(
                  pagination: pagination,
                  isLoading: provider.isLoading,
                  onPageChange: (newPage) => provider.loadStudents(
                    page: newPage,
                    limit: pagination.limit,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Column header, shown above the list on wider screens ─────────────
class _ListHeaderRow extends StatelessWidget {
  const _ListHeaderRow();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      color: LmsColors.textGrey,
      letterSpacing: 0.3,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: LmsColors.border)),
      ),
      child: const Row(
        children: [
          SizedBox(width: 44), // aligns with avatar column below
          SizedBox(width: 12),
          Expanded(flex: 3, child: Text('STUDENT', style: style)),
          Expanded(flex: 2, child: Text('CONTACT', style: style)),
          Expanded(flex: 2, child: Text('STATUS', style: style)),
          Expanded(flex: 2, child: Text('COURSE', style: style)),
          SizedBox(width: 40),
        ],
      ),
    );
  }
}

// ── Professional student row: photo, name/email stacked, aligned
// columns on wide screens, stacked card layout on narrow screens ──────
class _StudentRow extends StatelessWidget {
  final AdminStudentModel student;
  final Future<void> Function() onChanged;

  const _StudentRow({required this.student, required this.onChanged});

  String get _initial =>
      (student.name?.isNotEmpty == true ? student.name![0] : student.email[0])
          .toUpperCase();

  @override
  Widget build(BuildContext context) {
    final course = student.course ?? student.courseType;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 640;

        final avatar = _StudentAvatar(
          initial: _initial,
          // avatarUrl: student.avatarUrl,  // uncomment once the field exists on the model
        );

        final nameBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              student.name?.isNotEmpty == true ? student.name! : 'No name',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
                color: LmsColors.textDark,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              student.email,
              style: const TextStyle(color: LmsColors.textGrey, fontSize: 12.5),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );

        final phoneBlock = Text(
          (student.phone != null && student.phone!.isNotEmpty)
              ? student.phone!
              : '—',
          style: const TextStyle(color: LmsColors.textDark, fontSize: 13),
          overflow: TextOverflow.ellipsis,
        );

        // Left-aligned inside their columns rather than stretched: a chip that
        // fills its column reads as a button.
        final statusBlock = Align(
          alignment: Alignment.centerLeft,
          child: StudentStatusChip(student: student, dense: true),
        );

        final menu = _StudentRowMenu(student: student, onChanged: onChanged);

        final courseBlock = course != null
            ? Align(
                alignment: Alignment.centerLeft,
                child: _CourseChip(
                  title: course.title,
                  isPremium: course.isPremium,
                ),
              )
            : Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: LmsColors.bg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Not enrolled',
                  style: TextStyle(fontSize: 11.5, color: LmsColors.textGrey),
                ),
              );

        if (isWide) {
          return InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    StudentDetailScreen(student: student, onChanged: onChanged),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  avatar,
                  const SizedBox(width: 12),
                  Expanded(flex: 3, child: nameBlock),
                  Expanded(flex: 2, child: phoneBlock),
                  Expanded(flex: 2, child: statusBlock),
                  Expanded(flex: 2, child: courseBlock),
                  menu,
                ],
              ),
            ),
          );
        }

        // Narrow screens: stacked card layout instead of squeezed columns.
        return InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  StudentDetailScreen(student: student, onChanged: onChanged),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                avatar,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      nameBlock,
                      const SizedBox(height: 6),
                      phoneBlock,
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [statusBlock, courseBlock],
                      ),
                    ],
                  ),
                ),
                menu,
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Avatar: shows the real profile photo when available, falls back
// to a colored initial circle otherwise. ──────────────────────────────
class _StudentAvatar extends StatelessWidget {
  final String initial;
  final String? avatarUrl;

  const _StudentAvatar({required this.initial, this.avatarUrl});

  // Deterministic color per-student so initials aren't all one flat
  // color - based on a simple hash of the initial character.
  Color _colorFor(String letter) {
    const palette = [
      Color(0xFF4C6FFF),
      Color(0xFF9C5FFF),
      Color(0xFFFF9F43),
      Color(0xFF20C997),
      Color(0xFFFF6B6B),
      Color(0xFF20A4F3),
    ];
    final index = letter.codeUnitAt(0) % palette.length;
    return palette[index];
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = avatarUrl != null && avatarUrl!.isNotEmpty;
    final color = _colorFor(initial);

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.12),
        border: Border.all(color: color.withOpacity(0.25)),
        image: hasPhoto
            ? DecorationImage(
                image: NetworkImage(avatarUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: hasPhoto
          ? null
          : Center(
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
    );
  }
}

/// Block / unblock and sign-out, without opening the student.
///
/// An admin dealing with a support ticket is on this screen, not inside one
/// row, and the two actions differ enough that they are named in full rather
/// than reduced to icons.
class _StudentRowMenu extends StatelessWidget {
  final AdminStudentModel student;
  final Future<void> Function() onChanged;

  const _StudentRowMenu({required this.student, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final blocked = student.isBlocked;

    return SizedBox(
      width: 40,
      child: PopupMenuButton<String>(
        tooltip: 'Account actions',
        icon: const Icon(
          Icons.more_horiz_rounded,
          size: 19,
          color: LmsColors.textGrey,
        ),
        onSelected: (value) async {
          switch (value) {
            case 'block':
            case 'unblock':
              final updated = await confirmSetBlocked(
                context,
                student,
                blocked: value == 'block',
              );
              if (updated != null) await onChanged();
            case 'signout':
              await confirmSignOutEverywhere(context, student);
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'signout',
            child: Row(
              children: const [
                Icon(Icons.logout_rounded, size: 17, color: LmsColors.textDark),
                SizedBox(width: 10),
                Text('Sign out all devices'),
              ],
            ),
          ),
          const PopupMenuDivider(),
          // Separated from sign-out by the divider: blocking is a punishment
          // and must not sit flush against the action that only helps.
          PopupMenuItem(
            value: blocked ? 'unblock' : 'block',
            child: Row(
              children: [
                Icon(
                  blocked ? Icons.lock_open_rounded : Icons.block_rounded,
                  size: 17,
                  color: blocked ? LmsColors.success : LmsColors.error,
                ),
                const SizedBox(width: 10),
                Text(
                  blocked ? 'Unblock student' : 'Block student',
                  style: TextStyle(
                    color: blocked ? LmsColors.success : LmsColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseChip extends StatelessWidget {
  final String title;
  final bool isPremium;
  const _CourseChip({required this.title, required this.isPremium});

  @override
  Widget build(BuildContext context) {
    final color = isPremium ? LmsColors.primary : const Color(0xFF4C6FFF);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPremium ? Icons.workspace_premium_rounded : Icons.school_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  final PaginationModel pagination;
  final bool isLoading;
  final ValueChanged<int> onPageChange;

  const _PaginationBar({
    required this.pagination,
    required this.isLoading,
    required this.onPageChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: LmsColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: isLoading || pagination.page <= 1
                ? null
                : () => onPageChange(pagination.page - 1),
          ),
          Text(
            'Page ${pagination.page} of ${pagination.totalPages}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: LmsColors.textDark,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: isLoading || pagination.page >= pagination.totalPages
                ? null
                : () => onPageChange(pagination.page + 1),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: LmsColors.bg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline_rounded,
                size: 32,
                color: LmsColors.textGrey,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No students found',
              style: TextStyle(
                color: LmsColors.textGrey,
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 36,
              color: LmsColors.error,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: LmsColors.textDark),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: LmsColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
