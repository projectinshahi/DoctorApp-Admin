import 'package:flutter/material.dart';

import '../../core/theam/theam_dart.dart';
import '../../models/admin_student_model.dart';
import '../../models/panal_model.dart';
import '../../services/admin_plan_services.dart';
import '../../widget/shimmer_loading.dart';

/// One student, with everything the admin can currently know about them.
///
/// Split deliberately into what the API reports and what it doesn't. There is
/// no subscription endpoint yet, so this screen shows the plans that exist on
/// the student's chosen course and says plainly that whether *this* student
/// holds one is unknown - rather than rendering an empty table that reads as
/// "no subscription".
class StudentDetailScreen extends StatefulWidget {
  final AdminStudentModel student;

  const StudentDetailScreen({super.key, required this.student});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  final _planService = AdminPlanService();

  List<AdminPlanModel>? _plans;
  bool _isLoadingPlans = false;
  String? _planError;

  AdminStudentModel get _student => widget.student;

  @override
  void initState() {
    super.initState();
    if (_student.course != null) _loadPlans(_student.course!.id);
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

  @override
  Widget build(BuildContext context) {
    final isActive = _student.status.toLowerCase() == 'active';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: LmsColors.textDark,
        title: const Text(
          'Student',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _header(isActive),
          const SizedBox(height: 22),

          _SectionLabel('Account'),
          const SizedBox(height: 10),
          _InfoCard(
            rows: [
              _InfoRow('Email', _student.email, icon: Icons.mail_outline_rounded),
              _InfoRow(
                'Phone',
                _student.phone?.trim().isNotEmpty == true ? _student.phone! : 'Not provided',
                icon: Icons.phone_outlined,
                muted: _student.phone?.trim().isNotEmpty != true,
              ),
              _InfoRow('Registered', _joined(), icon: Icons.event_outlined),
              _InfoRow(
                'Account status',
                isActive ? 'Active' : _student.status,
                icon: Icons.verified_user_outlined,
                valueColor: isActive ? LmsColors.success : LmsColors.error,
              ),
            ],
          ),
          const SizedBox(height: 22),

          _SectionLabel('Selected course'),
          const SizedBox(height: 10),
          _courseCard(),
          const SizedBox(height: 22),

          _SectionLabel('Subscription'),
          const SizedBox(height: 10),
          _subscriptionSection(),
        ],
      ),
    );
  }

  Widget _header(bool isActive) {
    final name = _student.name?.trim();
    final display = name != null && name.isNotEmpty ? name : _student.email;
    final initial = display.trim().isEmpty ? '?' : display.trim()[0].toUpperCase();

    return Row(
      children: [
        Container(
          width: 58,
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: LmsColors.primarySoft,
            shape: BoxShape.circle,
          ),
          child: Text(
            initial,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              color: LmsColors.primary,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                display,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (isActive ? LmsColors.success : LmsColors.error)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      _student.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isActive ? LmsColors.success : LmsColors.error,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ID #${_student.id}',
                    style: const TextStyle(fontSize: 11.5, color: LmsColors.textGrey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

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
          valueColor: course.isPremium ? const Color(0xFFB8860B) : LmsColors.success,
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
      decoration: BoxDecoration(
        color: LmsColors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: LmsColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.title,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
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
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
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

  const _InfoCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: LmsColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LmsColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: LmsColors.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(rows[i].icon, size: 17, color: LmsColors.textGrey),
                  const SizedBox(width: 11),
                  Text(
                    rows[i].label,
                    style: const TextStyle(fontSize: 12.5, color: LmsColors.textGrey),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      rows[i].value,
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: rows[i].muted ? FontWeight.w400 : FontWeight.w700,
                        color: rows[i].muted
                            ? LmsColors.textGrey
                            : rows[i].valueColor ?? LmsColors.textDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
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
        borderRadius: BorderRadius.circular(13),
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
