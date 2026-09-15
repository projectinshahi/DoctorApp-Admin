import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theam/theam_dart.dart';
import '../../models/course_get_model.dart';
import '../../models/panal_model.dart';
import '../../provider/course_get_provider.dart';
import '../../services/admin_plan_services.dart';
import '../../widget/shimmer_loading.dart';
import 'plan_card_editor.dart';

/// The plans that sell each course, one course at a time.
///
/// Course first, like Videos and the Question Bank: an admin comes here to
/// change the pricing of one course, not to read every price in the system.
/// It is also one request per course picked - `GET /api/courses/:id/plans` is
/// the only way to read plans, so the old all-courses page fanned out over
/// every course the moment it opened.
///
/// Plans are retired with `isActive: false`, not deleted. A deleted plan
/// orphans every subscription that referenced it, so Delete sits behind a
/// confirmation that leads with retiring instead.
class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  final _service = AdminPlanService();

  int? _courseId;
  List<AdminPlanModel> _plans = const [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<CourseListGetProvider>();
      await provider.fetchCourses(limit: 100);
      if (!mounted || _courseId != null || provider.courses.isEmpty) return;
      // Premium courses are the ones with something to sell, so open on one.
      final first = provider.courses.firstWhere(
        (c) => c.accessType == 'premium',
        orElse: () => provider.courses.first,
      );
      _select(first.id);
    });
  }

  Future<void> _select(int courseId) async {
    setState(() {
      _courseId = courseId;
      _plans = const [];
      _error = null;
    });
    await _load();
  }

  Future<void> _load() async {
    final courseId = _courseId;
    if (courseId == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final plans = await _service.getPlansForCourse(courseId);
      // A slow response for a course the admin has already moved off must not
      // overwrite the plans of the course they are now looking at.
      if (!mounted || _courseId != courseId) return;
      setState(() {
        _isLoading = false;
        _plans = plans;
      });
    } catch (e) {
      if (!mounted || _courseId != courseId) return;
      setState(() {
        _isLoading = false;
        _error = '$e'.replaceFirst('Exception: ', '');
      });
    }
  }

  CourseListGetModel? _courseOf(List<CourseListGetModel> courses) {
    for (final course in courses) {
      if (course.id == _courseId) return course;
    }
    return null;
  }

  void _toast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: isError ? LmsColors.error : null,
      ));
  }

  Future<void> _openEditor(
    CourseListGetModel course, {
    AdminPlanModel? existing,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _PlanEditorDialog(
        course: course,
        existing: existing,
        service: _service,
      ),
    );
    if (saved != true) return;
    _toast(existing == null ? 'Plan added.' : 'Plan saved.');
    await _load();
  }

  Future<void> _setActive(AdminPlanModel plan, bool active) async {
    try {
      await _service.updatePlanBody(plan.id, {'isActive': active});
      _toast(active
          ? '"${plan.title}" is on sale again.'
          : '"${plan.title}" retired — it can no longer be bought.');
      await _load();
    } catch (e) {
      _toast('$e'.replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _confirmDelete(AdminPlanModel plan) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete "${plan.title}"?'),
        content: const Text(
          'Deleting a plan orphans every subscription that was bought with it. '
          'Retiring it stops new sales and keeps those records intact.\n\n'
          'Only delete a plan nobody has ever bought.',
          style: TextStyle(fontSize: 13.5, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'delete'),
            style: TextButton.styleFrom(foregroundColor: LmsColors.error),
            child: const Text('Delete anyway'),
          ),
          // Retire leads: it is the safe answer to almost every "get rid of
          // this price", so it is the filled button and Delete is the quiet one.
          if (plan.isActive)
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'retire'),
              style: FilledButton.styleFrom(backgroundColor: LmsColors.primary),
              child: const Text('Retire instead'),
            ),
        ],
      ),
    );
    if (!mounted || choice == null) return;

    if (choice == 'retire') {
      await _setActive(plan, false);
      return;
    }
    try {
      await _service.deletePlan(plan.id);
      _toast('"${plan.title}" deleted.');
      await _load();
    } catch (e) {
      _toast('$e'.replaceFirst('Exception: ', ''), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CourseListGetProvider>();
    final course = _courseOf(provider.courses);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Plans',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    SizedBox(height: 4),
                    Text(
                      'Pick a course to see and manage the plans that sell it.',
                      style:
                          TextStyle(fontSize: 12.5, color: LmsColors.textGrey),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Reload',
                onPressed: _isLoading || course == null ? null : _load,
                icon: const Icon(Icons.refresh_rounded, size: 19),
                color: LmsColors.textGrey,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _coursePicker(provider),
          const SizedBox(height: 18),
          if (course != null) _coursePanel(course),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _coursePicker(CourseListGetProvider provider) {
    if (provider.isLoadingCourses && provider.courses.isEmpty) {
      return const LmsShimmer(
        child: Row(
          children: [
            ShimmerBox(width: 140, height: 36, radius: 18),
            SizedBox(width: 8),
            ShimmerBox(width: 110, height: 36, radius: 18),
          ],
        ),
      );
    }

    if (provider.courses.isEmpty) {
      return const _Notice(
        icon: Icons.menu_book_outlined,
        text: 'No courses yet. Plans belong to a course, so create one first.',
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in provider.courses)
          _CourseChip(
            title: c.title,
            isPremium: c.accessType == 'premium',
            selected: c.id == _courseId,
            onTap: () => _select(c.id),
          ),
      ],
    );
  }

  Widget _coursePanel(CourseListGetModel course) {
    final isPremium = course.accessType == 'premium';
    final onSale = _plans.where((p) => p.isActive).length;
    final retired = _plans.length - onSale;

    return Container(
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
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _isLoading
                            ? 'Loading plans…'
                            : !isPremium
                                ? 'Free course'
                                : '$onSale on sale'
                                    '${retired == 0 ? '' : ' · $retired retired'}',
                        style: const TextStyle(
                            fontSize: 12, color: LmsColors.textGrey),
                      ),
                    ],
                  ),
                ),
                // A free course has nothing to sell, so there is nowhere to
                // put a plan - the same rule the course wizard follows.
                if (isPremium)
                  FilledButton.icon(
                    onPressed: _isLoading ? null : () => _openEditor(course),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add plan'),
                    style: FilledButton.styleFrom(
                        backgroundColor: LmsColors.primary),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: LmsColors.border),
          if (_isLoading && _plans.isEmpty)
            const Padding(
              padding: EdgeInsets.all(14),
              child: ShimmerListSkeleton(rowCount: 3, padding: EdgeInsets.zero),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(14),
              child: _Notice(
                icon: Icons.error_outline_rounded,
                color: LmsColors.error,
                text: _error!,
                action:
                    TextButton(onPressed: _load, child: const Text('Retry')),
              ),
            )
          else if (_plans.isEmpty)
            Padding(
              padding: const EdgeInsets.all(14),
              child: isPremium
                  ? const _Notice(
                      icon: Icons.lock_outline_rounded,
                      color: Color(0xFFB8860B),
                      text: 'No plans yet. Every lesson in this course is '
                          'locked, and nobody can subscribe until one is added.',
                    )
                  : const _Notice(
                      icon: Icons.lock_open_rounded,
                      color: LmsColors.textGrey,
                      text: 'This course is free, so there is nothing to sell. '
                          'Switch it to premium to add plans.',
                    ),
            )
          else
            for (var i = 0; i < _plans.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: LmsColors.border),
              _PlanTile(
                plan: _plans[i],
                onEdit: () => _openEditor(course, existing: _plans[i]),
                onToggleActive: () =>
                    _setActive(_plans[i], !_plans[i].isActive),
                onDelete: () => _confirmDelete(_plans[i]),
              ),
            ],
        ],
      ),
    );
  }
}

/// The server words `durationLabel`; it is rendered as sent. The arithmetic
/// fallback only covers plans stored before that field existed.
String _durationOf(AdminPlanModel plan) {
  final label = plan.durationLabel?.trim();
  if (label != null && label.isNotEmpty) return label;

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

/// The plan's own currency - a course priced in USD must not list as AED.
String _priceOf(AdminPlanModel plan) {
  final symbol =
      (plan.currency ?? '').trim().isEmpty ? 'AED' : plan.currency!.trim();
  return '$symbol ${plan.price.toStringAsFixed(plan.price % 1 == 0 ? 0 : 2)}';
}

class _PlanTile extends StatelessWidget {
  final AdminPlanModel plan;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  const _PlanTile({
    required this.plan,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
        child: Row(
          children: [
            Expanded(
              // A retired plan stays listed, dimmed, so it can be put back on
              // sale - it has not gone anywhere, it just cannot be bought.
              child: Opacity(
                opacity: plan.isActive ? 1 : 0.5,
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 38,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: parseAccent(plan.accentColor ?? '#EFEFEF'),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: LmsColors.border),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  plan.title,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                              if (!plan.isActive) ...[
                                const SizedBox(width: 8),
                                const Text('RETIRED',
                                    style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                        color: LmsColors.textGrey)),
                              ],
                            ],
                          ),
                          if (plan.entitlements.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            // The access list, not the sales tick list: this
                            // is what actually opens content.
                            Text(
                              plan.entitlements.map((e) => e.label).join(' · '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: LmsColors.primary),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(_priceOf(plan),
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(_durationOf(plan),
                            style: const TextStyle(
                                fontSize: 11.5, color: LmsColors.textGrey)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Plan actions',
              icon: const Icon(Icons.more_vert_rounded,
                  size: 19, color: LmsColors.textGrey),
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    onEdit();
                  case 'toggle':
                    onToggleActive();
                  case 'delete':
                    onDelete();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit_outlined, size: 17),
                    SizedBox(width: 10),
                    Text('Edit'),
                  ]),
                ),
                PopupMenuItem(
                  value: 'toggle',
                  child: Row(children: [
                    Icon(
                      plan.isActive
                          ? Icons.pause_circle_outline_rounded
                          : Icons.play_circle_outline_rounded,
                      size: 17,
                    ),
                    const SizedBox(width: 10),
                    Text(plan.isActive ? 'Retire' : 'Put back on sale'),
                  ]),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline_rounded,
                        size: 17, color: LmsColors.error),
                    SizedBox(width: 10),
                    Text('Delete', style: TextStyle(color: LmsColors.error)),
                  ]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Add or edit one plan, using the same form the course wizard uses.
///
/// Editing sends only what changed ([planChanges]); saving an untouched plan
/// sends nothing at all.
class _PlanEditorDialog extends StatefulWidget {
  final CourseListGetModel course;
  final AdminPlanModel? existing;
  final AdminPlanService service;

  const _PlanEditorDialog({
    required this.course,
    required this.existing,
    required this.service,
  });

  @override
  State<_PlanEditorDialog> createState() => _PlanEditorDialogState();
}

class _PlanEditorDialogState extends State<_PlanEditorDialog> {
  late final PlanDraft _draft = widget.existing == null
      ? PlanDraft()
      : PlanDraft.from(widget.existing!);

  bool _saving = false;
  String? _error;

  bool get _isNew => widget.existing == null;

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final problem = _draft.problem;
    if (problem != null) {
      setState(() => _error = 'This plan $problem.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final edited = _draft.toModel(widget.course.id);
      final existing = widget.existing;
      if (existing == null) {
        await widget.service
            .createPlan(courseId: widget.course.id, plan: edited);
      } else {
        final body = planChanges(existing, edited);
        if (body.isNotEmpty) {
          await widget.service.updatePlanBody(existing.id, body);
        }
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '$e'.replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 780),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_isNew ? 'Add plan' : 'Edit plan',
                            style: const TextStyle(
                                fontSize: 16.5, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(
                          'For ${widget.course.title}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: LmsColors.textGrey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: LmsColors.border),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PlanCardForm(
                      draft: _draft,
                      enabled: !_saving,
                      onChanged: () => setState(() {}),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.4,
                              color: LmsColors.error)),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: LmsColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                        backgroundColor: LmsColors.primary),
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(_isNew ? 'Add plan' : 'Save'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseChip extends StatelessWidget {
  final String title;
  final bool isPremium;
  final bool selected;
  final VoidCallback onTap;

  const _CourseChip({
    required this.title,
    required this.isPremium,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? LmsColors.primary : LmsColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? LmsColors.primary : LmsColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isPremium) ...[
                Icon(Icons.workspace_premium_rounded,
                    size: 14,
                    color: selected ? Colors.white : const Color(0xFFB8860B)),
                const SizedBox(width: 6),
              ],
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : LmsColors.textDark,
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
            child: Text(text,
                style: TextStyle(fontSize: 12.5, height: 1.4, color: color)),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}
