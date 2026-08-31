import 'package:flutter/material.dart';

import '../../core/theam/theam_dart.dart';
import '../../models/admin_student_model.dart';
import '../../models/panal_model.dart';
import '../../models/student_progress_model.dart';
import '../../services/admin_plan_services.dart';
import '../../services/admin_student_service.dart';
import '../../widget/shimmer_loading.dart';
import '../../widget/student_progress_widgets.dart';
import 'student_progress_detail_screen.dart';

/// One student, as a summary that drills down.
///
/// Every long list - lessons, quiz attempts, test attempts - lives on its own
/// breakdown screen rather than inline here. Stacked inline they made a page
/// several screens tall where the numbers an admin actually opens this for
/// were buried under history.
///
/// Split deliberately into what the API reports and what it doesn't. There is
/// no subscription endpoint yet, so this screen shows the plans that exist on
/// the student's chosen course and says plainly that whether *this* student
/// holds one is unknown - rather than rendering an empty table that reads as
/// "no subscription".
///
/// Progress comes from GET /admin/students/:id and is rendered exactly as the
/// server reports it. Nothing here recomputes a total from the chapter
/// rollups: drafts are excluded from the API's denominators on purpose, and
/// adding them back would show a student as behind on lessons that were never
/// published to them.
class StudentDetailScreen extends StatefulWidget {
  final AdminStudentModel student;

  const StudentDetailScreen({super.key, required this.student});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  final _planService = AdminPlanService();
  final _studentService = AdminStudentService();

  List<AdminPlanModel>? _plans;
  bool _isLoadingPlans = false;
  String? _planError;

  StudentDetail? _detail;
  bool _isLoadingDetail = false;
  String? _detailError;

  AdminStudentModel get _student => widget.student;

  bool get _isActive => _student.status.toLowerCase() == 'active';

  String get _displayName {
    final name = _student.name?.trim();
    return name != null && name.isNotEmpty ? name : _student.email;
  }

  @override
  void initState() {
    super.initState();
    _loadDetail();
    if (_student.course != null) _loadPlans(_student.course!.id);
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoadingDetail = true;
      _detailError = null;
    });
    try {
      final detail = await _studentService.getStudentDetail(_student.id);
      if (!mounted) return;
      setState(() {
        _isLoadingDetail = false;
        _detail = detail;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingDetail = false;
        _detailError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadPlans(int courseId) async {
    setState(() {
      _isLoadingPlans = true;
      _planError = null;
    });
    try {
      final plans = await _planService.getPlansForCourse(courseId);
      if (!mounted) return;
      setState(() {
        _isLoadingPlans = false;
        _plans = plans;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingPlans = false;
        _planError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String _joined() {
    final d = _student.createdAt;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  /// Opens the breakdown behind one metric.
  ///
  /// [noItemsNote] is required for the metrics the API only counts, so a
  /// videos or question-bank tap explains the absence instead of opening an
  /// empty list that reads as "the student did nothing".
  void _openBreakdown({
    required String title,
    required ProgressBlock block,
    List<ChapterProgress> chapters = const [],
    List<AttemptSummary> attempts = const [],
    String? noItemsNote,
    bool historyIsCapped = false,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentProgressDetailScreen(
          title: title,
          studentName: _displayName,
          block: block,
          chapters: chapters,
          attempts: attempts,
          noItemsNote: noItemsNote,
          historyIsCapped: historyIsCapped,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LmsColors.bg,
      // No title: the hero below already names the student, and repeating it
      // in the bar wasted the only row that is always on screen.
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        systemOverlayStyle: null,
      ),
      extendBodyBehindAppBar: true,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _hero(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _progressSection(),
                const SizedBox(height: 24),

                const _SectionLabel('Account'),
                const SizedBox(height: 10),
                _InfoCard(
                  rows: [
                    _InfoRow('Email', _student.email,
                        icon: Icons.mail_outline_rounded),
                    _InfoRow(
                      'Phone',
                      _student.phone?.trim().isNotEmpty == true
                          ? _student.phone!
                          : 'Not provided',
                      icon: Icons.phone_outlined,
                      muted: _student.phone?.trim().isNotEmpty != true,
                    ),
                    _InfoRow('Registered', _joined(),
                        icon: Icons.event_outlined),
                    _InfoRow(
                      'Account status',
                      _isActive ? 'Active' : _student.status,
                      icon: Icons.verified_user_outlined,
                      valueColor:
                          _isActive ? LmsColors.success : LmsColors.error,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                const _SectionLabel('Selected course'),
                const SizedBox(height: 10),
                _courseCard(),
                const SizedBox(height: 24),

                const _SectionLabel('Subscription'),
                const SizedBox(height: 10),
                _subscriptionSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero ─────────────────────────────────────────────────────────

  Widget _hero() {
    final initial =
        _displayName.trim().isEmpty ? '?' : _displayName.trim()[0].toUpperCase();
    final lastActive = _detail?.progress.lastActivityAt;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 96, 20, 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B6FE0), Color(0xFF2C4FA8)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(26),
          bottomRight: Radius.circular(26),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 62,
                height: 62,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35), width: 1.5),
                ),
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayName,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _student.email,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroChip(
                icon: _isActive
                    ? Icons.check_circle_rounded
                    : Icons.pause_circle_rounded,
                label: _student.status.toUpperCase(),
              ),
              _HeroChip(icon: Icons.badge_outlined, label: 'ID #${_student.id}'),
              if (lastActive != null)
                _HeroChip(
                  icon: Icons.schedule_rounded,
                  label: 'Active ${formatStamp(lastActive)}',
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Progress ─────────────────────────────────────────────────────

  Widget _progressSection() {
    if (_isLoadingDetail) {
      return const ShimmerListSkeleton(rowCount: 4, padding: EdgeInsets.zero);
    }

    if (_detailError != null) {
      return _NoticeCard(
        icon: Icons.error_outline_rounded,
        color: LmsColors.error,
        text: _detailError!,
        action: TextButton(onPressed: _loadDetail, child: const Text('Retry')),
      );
    }

    final detail = _detail;
    if (detail == null) return const SizedBox.shrink();
    final p = detail.progress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Progress'),
        const SizedBox(height: 4),
        const Text(
          'Tap any card for the full breakdown.',
          style: TextStyle(fontSize: 12, color: LmsColors.textGrey),
        ),
        const SizedBox(height: 12),

        if (!p.hasAnyActivity) ...[
          const _NoticeCard(
            icon: Icons.hourglass_empty_rounded,
            color: LmsColors.textGrey,
            text: 'This student has not opened anything yet.',
          ),
          const SizedBox(height: 12),
        ],

        // Four rings rather than four bars: each metric reads at a glance,
        // and the tile carries its own "in progress" count where the API
        // reports one.
        LayoutBuilder(
          builder: (context, constraints) {
            // Two per row on a phone, four across on a wide admin window.
            const spacing = 10.0;
            final columns = constraints.maxWidth >= 620 ? 4 : 2;
            final width =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                ProgressRingTile(
                  label: 'Lessons',
                  block: p.lessons,
                  color: LmsColors.primary,
                  width: width,
                  onTap: () => _openBreakdown(
                    title: 'Lessons',
                    block: p.lessons,
                    chapters: detail.chapters,
                    noItemsNote: 'The API did not return any chapters for this '
                        'student, so there is no per-lesson breakdown.',
                  ),
                ),
                ProgressRingTile(
                  label: 'Videos',
                  block: p.videos,
                  color: const Color(0xFF7C3AED),
                  width: width,
                  onTap: () => _openBreakdown(
                    title: 'Videos',
                    block: p.videos,
                    noItemsNote: 'This endpoint reports video progress as '
                        'totals only - there is no per-video list to show.',
                  ),
                ),
                ProgressRingTile(
                  label: 'Notes',
                  block: p.notes,
                  color: const Color(0xFFB8860B),
                  width: width,
                  onTap: () => _openBreakdown(
                    title: 'Notes',
                    block: p.notes,
                    noItemsNote: 'This endpoint reports note progress as '
                        'totals only - there is no per-note list to show.',
                  ),
                ),
                ProgressRingTile(
                  label: 'Quizzes',
                  block: p.quizzes,
                  color: LmsColors.success,
                  width: width,
                  onTap: () => _openBreakdown(
                    title: 'Quizzes',
                    block: p.quizzes,
                    attempts: detail.recentQuizAttempts,
                    historyIsCapped: detail.historyIsCapped,
                    noItemsNote:
                        'No quiz attempts were returned for this student.',
                  ),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 18),
        const _SectionLabel('Performance'),
        const SizedBox(height: 10),

        // Every value in these three rows sits in the same right column as
        // the account and course rows below, so the whole page reads as one
        // aligned list rather than four competing layouts.
        if (!p.qbank.isEmpty) ...[
          _InfoCard(
            onTap: () => _openBreakdown(
              title: 'Question bank',
              block: p.qbank,
              noItemsNote: 'Question bank activity is reported as totals only '
                  '- the individual questions this student answered are not '
                  'returned by this endpoint.',
            ),
            rows: [
              // Distinct questions, not answer rows: retakes are unlimited, so
              // counting rows would report a student who retook one quiz five
              // times as having seen five times the bank.
              _InfoRow('Questions attempted',
                  '${p.qbank['attempted'] ?? 0} distinct',
                  icon: Icons.quiz_outlined),
              _InfoRow('Correct', '${p.qbank['correct'] ?? 0}',
                  icon: Icons.check_circle_outline_rounded,
                  valueColor: LmsColors.success),
              _InfoRow('Wrong', '${p.qbank['wrong'] ?? 0}',
                  icon: Icons.cancel_outlined, valueColor: LmsColors.error),
              _InfoRow('Accuracy', '${p.qbank['accuracy'] ?? 0}%',
                  icon: Icons.percent_rounded),
            ],
          ),
          const SizedBox(height: 10),
        ],

        if (!p.tests.isEmpty) ...[
          _InfoCard(
            onTap: () => _openBreakdown(
              title: 'Tests',
              block: p.tests,
              attempts: detail.recentTestAttempts,
              historyIsCapped: detail.historyIsCapped,
              noItemsNote: 'No test attempts were returned for this student.',
            ),
            rows: [
              _InfoRow('Tests attempted', '${p.tests['attempted'] ?? 0}',
                  icon: Icons.fact_check_outlined),
              _InfoRow('Submitted', '${p.tests['submitted'] ?? 0}',
                  icon: Icons.assignment_turned_in_outlined),
              _InfoRow('Best score', '${p.tests['bestScore'] ?? 0}',
                  icon: Icons.emoji_events_outlined),
            ],
          ),
          const SizedBox(height: 10),
        ],

        if (!p.bookmarks.isEmpty)
          _InfoCard(
            rows: [
              _InfoRow(
                  'Bookmarked questions', '${p.bookmarks['questions'] ?? 0}',
                  icon: Icons.bookmark_outline_rounded),
              _InfoRow('Bookmarked lessons', '${p.bookmarks['lessons'] ?? 0}',
                  icon: Icons.bookmarks_outlined),
            ],
          ),
      ],
    );
  }

  // ── Course & subscription ────────────────────────────────────────

  Widget _courseCard() {
    final course = _student.course;
    if (course == null) {
      return const _NoticeCard(
        icon: Icons.school_outlined,
        text: 'This student has not selected a course.',
      );
    }

    final examType = _student.courseType;
    return _InfoCard(
      rows: [
        _InfoRow('Course', course.title, icon: Icons.menu_book_outlined),
        if (examType != null)
          _InfoRow('Exam type', examType.title, icon: Icons.category_outlined),
        _InfoRow(
          'Access',
          course.isPremium ? 'Premium' : 'Free',
          icon: Icons.workspace_premium_outlined,
          valueColor:
              course.isPremium ? const Color(0xFFB8860B) : LmsColors.success,
        ),
        _InfoRow(
          'Course status',
          course.status.isEmpty ? 'Unknown' : course.status,
          icon: Icons.published_with_changes_outlined,
        ),
      ],
    );
  }

  Widget _subscriptionSection() {
    final course = _student.course;

    if (course == null) {
      return const _NoticeCard(
        icon: Icons.credit_card_off_outlined,
        text: 'No course selected, so no plan applies.',
      );
    }

    if (!course.isPremium) {
      return const _NoticeCard(
        icon: Icons.lock_open_rounded,
        color: LmsColors.success,
        text: 'This is a free course - the student needs no subscription to '
            'open its lessons.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Said outright rather than implied by an empty table: the API cannot
        // yet report whether this student paid, or when their access ends.
        const _NoticeCard(
          icon: Icons.info_outline_rounded,
          text: 'Payment state and expiry are not reported by the API yet. '
              'The plans below are what this course offers, not what this '
              'student holds.',
        ),
        const SizedBox(height: 12),
        Text(
          'Plans on "${course.title}"',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: LmsColors.textGrey,
          ),
        ),
        const SizedBox(height: 8),
        if (_isLoadingPlans)
          const ShimmerListSkeleton(rowCount: 2, padding: EdgeInsets.zero)
        else if (_planError != null)
          _NoticeCard(
            icon: Icons.error_outline_rounded,
            color: LmsColors.error,
            text: _planError!,
            action: TextButton(
              onPressed: () => _loadPlans(course.id),
              child: const Text('Retry'),
            ),
          )
        else if ((_plans ?? const []).isEmpty)
          const _NoticeCard(
            icon: Icons.report_problem_outlined,
            color: LmsColors.error,
            text: 'This premium course has no plans, so nobody can subscribe '
                'to it at all.',
          )
        else
          for (final plan in _plans!) _PlanRow(plan: plan),
      ],
    );
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                )),
          ],
        ),
      );
}

class _PlanRow extends StatelessWidget {
  final AdminPlanModel plan;

  const _PlanRow({required this.plan});

  /// durationDays is what the API stores; months read better past a month.
  String get _duration {
    final d = plan.durationDays;
    if (d % 365 == 0 && d >= 365) {
      final years = d ~/ 365;
      return '$years year${years == 1 ? '' : 's'}';
    }
    if (d % 30 == 0 && d >= 30) {
      final months = d ~/ 30;
      return '$months month${months == 1 ? '' : 's'}';
    }
    return '$d day${d == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: lmsCard,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.title,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  'AED ${plan.price.toStringAsFixed(plan.price % 1 == 0 ? 0 : 2)}'
                  ' · $_duration',
                  style: const TextStyle(fontSize: 12, color: LmsColors.textGrey),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (plan.isActive ? LmsColors.success : LmsColors.textGrey)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              plan.isActive ? 'ACTIVE' : 'INACTIVE',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: plan.isActive ? LmsColors.success : LmsColors.textGrey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      );
}

class _InfoRow {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;
  final bool muted;

  const _InfoRow(
    this.label,
    this.value, {
    required this.icon,
    this.valueColor,
    this.muted = false,
  });
}

class _InfoCard extends StatelessWidget {
  final List<_InfoRow> rows;

  /// Optional: makes the whole card open a breakdown, with a chevron to say so.
  final VoidCallback? onTap;

  const _InfoCard({required this.rows, this.onTap});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: lmsCard,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: LmsColors.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  Icon(rows[i].icon, size: 17, color: LmsColors.textGrey),
                  const SizedBox(width: 11),
                  Text(
                    rows[i].label,
                    style: const TextStyle(
                        fontSize: 12.5, color: LmsColors.textGrey),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      rows[i].value,
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            rows[i].muted ? FontWeight.w400 : FontWeight.w700,
                        color: rows[i].muted
                            ? LmsColors.textGrey
                            : rows[i].valueColor ?? LmsColors.textDark,
                      ),
                    ),
                  ),
                  // Only the first row carries the chevron, so a tappable card
                  // says so once instead of on every line.
                  if (onTap != null)
                    SizedBox(
                      width: 20,
                      child: i == 0
                          ? const Icon(Icons.chevron_right_rounded,
                              size: 18, color: LmsColors.textGrey)
                          : null,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: card,
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final Widget? action;

  const _NoticeCard({
    required this.icon,
    required this.text,
    this.color = LmsColors.primary,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12.5, height: 1.35, color: color),
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}
