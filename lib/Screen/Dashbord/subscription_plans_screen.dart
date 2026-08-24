import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theam/theam_dart.dart';
import '../../models/course_get_model.dart';
import '../../models/panal_model.dart';
import '../../provider/course_get_provider.dart';
import '../../services/admin_plan_services.dart';
import '../../widget/shimmer_loading.dart';

/// Every subscription plan in the system, grouped by the course it unlocks.
///
/// Plans are only addressable per course (GET /api/courses/:id/plans) - there
/// is no endpoint that lists them all - so the courses are loaded first and
/// then fanned out over. Requests run concurrently rather than in sequence;
/// a dozen courses one after another is a visibly slow screen.
class SubscriptionPlansScreen extends StatefulWidget {
  const SubscriptionPlansScreen({super.key});

  @override
  State<SubscriptionPlansScreen> createState() => _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen> {
  final _service = AdminPlanService();

  final Map<int, List<AdminPlanModel>> _plansByCourse = {};
  bool _isLoadingPlans = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final courseProvider = context.read<CourseListGetProvider>();

    setState(() {
      _isLoadingPlans = true;
      _error = null;
    });

    await courseProvider.fetchCourses(limit: 100);
    if (!mounted) return;

    final courses = courseProvider.courses;
    try {
      final results = await Future.wait(
        courses.map((c) => _service.getPlansForCourse(c.id)),
      );
      if (!mounted) return;
      setState(() {
        _isLoadingPlans = false;
        _plansByCourse
          ..clear()
          ..addEntries([
            for (var i = 0; i < courses.length; i++)
              MapEntry(courses[i].id, results[i]),
          ]);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingPlans = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final courseProvider = context.watch<CourseListGetProvider>();
    final courses = courseProvider.courses;
    final busy = courseProvider.isLoadingCourses || _isLoadingPlans;

    final allPlans = _plansByCourse.values.expand((p) => p).toList();
    final activeCount = allPlans.where((p) => p.isActive).length;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Subscriptions',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      busy
                          ? 'Loading plans...'
                          : '${allPlans.length} plan${allPlans.length == 1 ? '' : 's'} '
                              'across ${courses.length} course'
                              '${courses.length == 1 ? '' : 's'} · '
                              '$activeCount active',
                      style: const TextStyle(fontSize: 12.5, color: LmsColors.textGrey),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Reload',
                onPressed: busy ? null : _load,
                icon: const Icon(Icons.refresh_rounded, size: 19),
                color: LmsColors.textGrey,
              ),
            ],
          ),
          const SizedBox(height: 18),

          if (busy && _plansByCourse.isEmpty)
            const ShimmerListSkeleton(rowCount: 3, padding: EdgeInsets.zero)
          else if (_error != null)
            _Notice(
              icon: Icons.error_outline_rounded,
              color: LmsColors.error,
              text: _error!,
              action: TextButton(onPressed: _load, child: const Text('Retry')),
            )
          else if (courses.isEmpty)
            const _Notice(
              icon: Icons.menu_book_outlined,
              text: 'No courses yet, so there are no plans to show.',
            )
          else
            for (final course in courses)
              _CourseSection(
                course: course,
                plans: _plansByCourse[course.id] ?? const [],
              ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _CourseSection extends StatelessWidget {
  final CourseListGetModel course;
  final List<AdminPlanModel> plans;

  const _CourseSection({required this.course, required this.plans});

  @override
  Widget build(BuildContext context) {
    final isPremium = course.accessType == 'premium';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: LmsColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: LmsColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: (isPremium
                            ? const Color(0xFFB8860B)
                            : LmsColors.textGrey)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isPremium
                        ? Icons.workspace_premium_rounded
                        : Icons.lock_open_rounded,
                    size: 18,
                    color: isPremium
                        ? const Color(0xFFB8860B)
                        : LmsColors.textGrey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    course.title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${plans.length} plan${plans.length == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 12, color: LmsColors.textGrey),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: LmsColors.border),

          if (plans.isEmpty)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                // A premium course with no plan is unsellable; a free one with
                // no plan is simply free. Same emptiness, different meaning.
                isPremium
                    ? 'No plans on this premium course - nobody can subscribe to it.'
                    : 'Free course, so no plan is needed.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: isPremium ? LmsColors.error : LmsColors.textGrey,
                ),
              ),
            )
          else
            for (var i = 0; i < plans.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: LmsColors.border),
              _PlanRow(plan: plans[i]),
            ],
        ],
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  final AdminPlanModel plan;

  const _PlanRow({required this.plan});

  /// durationDays is what the API stores; months and years read better.
  String get _duration {
    final d = plan.durationDays;
    if (d >= 365 && d % 365 == 0) {
      final years = d ~/ 365;
      return '$years year${years == 1 ? '' : 's'}';
    }
    if (d >= 30 && d % 30 == 0) {
      final months = d ~/ 30;
      return '$months month${months == 1 ? '' : 's'}';
    }
    return '$d day${d == 1 ? '' : 's'}';
  }

  String get _price =>
      'AED ${plan.price.toStringAsFixed(plan.price % 1 == 0 ? 0 : 2)}';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
                if ((plan.description ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    plan.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.35,
                      color: LmsColors.textGrey,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _price,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                _duration,
                style: const TextStyle(fontSize: 11.5, color: LmsColors.textGrey),
              ),
            ],
          ),
          const SizedBox(width: 12),
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
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(width: 11),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12.5, color: color)),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}
