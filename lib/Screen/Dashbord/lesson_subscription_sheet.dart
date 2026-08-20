import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theam/theam_dart.dart';
import '../../models/lesson_detail_model.dart';
import '../../models/panal_model.dart';
import '../../provider/lesson_upload_provider.dart';
import '../../services/admin_plan_services.dart';
import '../../services/lesson_services.dart';
import 'add_edit_plan_sheet.dart';
import 'lesson_badges.dart';

/// Multi-select list of the course's subscription plans, with create / edit /
/// delete on each one.
///
/// Shared by the lesson sheet and the standalone subscription sheet so the
/// plan rules only exist in one place: an empty selection means "any active
/// subscription", and a plan attached to the lesson but missing from the
/// course list still shows up so saving can't silently detach it.
class LessonPlanSelector extends StatefulWidget {
  final int courseId;
  final Set<int> selectedPlanIds;
  final ValueChanged<Set<int>> onChanged;

  /// Plans the lesson already carries. Used to keep an attached-but-delisted
  /// plan visible while the course list loads or if it comes back without it.
  final List<LessonPlanSummary> attachedPlans;

  const LessonPlanSelector({
    super.key,
    required this.courseId,
    required this.selectedPlanIds,
    required this.onChanged,
    this.attachedPlans = const [],
  });

  @override
  State<LessonPlanSelector> createState() => _LessonPlanSelectorState();
}

class _LessonPlanSelectorState extends State<LessonPlanSelector> {
  final _service = AdminPlanService();

  List<AdminPlanModel> _plans = [];
  bool _isLoading = false;
  String? _error;
  int? _busyPlanId; // plan currently being deleted

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final plans = await _service.getPlansForCourse(widget.courseId);
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _toggle(int planId) {
    final next = {...widget.selectedPlanIds};
    next.contains(planId) ? next.remove(planId) : next.add(planId);
    widget.onChanged(next);
  }

  Future<void> _createPlan() async {
    final created = await showAddEditPlanSheet(context, courseId: widget.courseId);
    if (created == null || !mounted) return;
    setState(() => _plans = [..._plans, created]);
    // A freshly created plan is almost always the one you meant to attach.
    widget.onChanged({...widget.selectedPlanIds, created.id});
  }

  Future<void> _editPlan(AdminPlanModel plan) async {
    final saved = await showAddEditPlanSheet(context, courseId: widget.courseId, existingPlan: plan);
    if (saved == null || !mounted) return;
    setState(() {
      _plans = [for (final p in _plans) p.id == saved.id ? saved : p];
    });
  }

  Future<void> _deletePlan(AdminPlanModel plan) async {
    final attachedHere = widget.selectedPlanIds.contains(plan.id);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete plan?'),
        content: Text(
          attachedHere
              ? '"${plan.title}" is attached to this lesson and may be attached to others. '
                  'Deleting it removes it from the whole course. This cannot be undone.'
              : 'This permanently deletes "${plan.title}" from the course. This cannot be undone.',
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

    setState(() => _busyPlanId = plan.id);
    try {
      await _service.deletePlan(plan.id);
      if (!mounted) return;
      setState(() {
        _plans = _plans.where((p) => p.id != plan.id).toList();
        _busyPlanId = null;
      });
      widget.onChanged({...widget.selectedPlanIds}..remove(plan.id));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyPlanId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: LmsColors.error,
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  /// Course plans, plus any attached plan the course list didn't return.
  List<AdminPlanModel> get _visiblePlans {
    final rows = [..._plans];
    for (final a in widget.attachedPlans) {
      if (rows.any((p) => p.id == a.id)) continue;
      rows.add(AdminPlanModel(
        id: a.id,
        courseId: widget.courseId,
        title: a.title,
        price: a.price,
        durationDays: a.durationDays,
        isActive: a.isActive,
      ));
    }
    rows.sort((a, b) => a.price.compareTo(b.price));
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _plans.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Row(
          children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 10),
            Text('Loading plans...', style: TextStyle(fontSize: 13, color: LmsColors.textGrey)),
          ],
        ),
      );
    }

    if (_error != null && _plans.isEmpty) {
      return Row(
        children: [
          Expanded(child: Text(_error!, style: const TextStyle(color: LmsColors.error, fontSize: 12.5))),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ],
      );
    }

    final plans = _visiblePlans;
    final anySubscription = widget.selectedPlanIds.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AnySubscriptionTile(
          selected: anySubscription,
          onTap: () => widget.onChanged(const {}),
        ),
        const SizedBox(height: 8),
        if (plans.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: LmsColors.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: LmsColors.border),
            ),
            child: const Text(
              'This course has no plans yet. Create one so students can buy access.',
              style: TextStyle(fontSize: 12.5, color: LmsColors.textGrey, height: 1.4),
            ),
          )
        else
          ...plans.map(
            (p) => _PlanCheckTile(
              plan: p,
              selected: widget.selectedPlanIds.contains(p.id),
              dimmed: anySubscription,
              isDeleting: _busyPlanId == p.id,
              onTap: () => _toggle(p.id),
              onEdit: () => _editPlan(p),
              onDelete: () => _deletePlan(p),
            ),
          ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _createPlan,
            icon: const Icon(Icons.add_circle_outline_rounded, size: 17),
            label: const Text('Create plan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            style: TextButton.styleFrom(foregroundColor: LmsColors.primary),
          ),
        ),
      ],
    );
  }
}

class _AnySubscriptionTile extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const _AnySubscriptionTile({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? LmsColors.primarySoft : LmsColors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? LmsColors.primary : LmsColors.border),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
              size: 19,
              color: selected ? LmsColors.primary : LmsColors.textGrey,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Any active subscription',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: LmsColors.textDark),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Any plan the student holds for this course unlocks it.',
                    style: TextStyle(fontSize: 11.5, color: LmsColors.textGrey),
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

class _PlanCheckTile extends StatelessWidget {
  final AdminPlanModel plan;
  final bool selected;
  final bool dimmed;
  final bool isDeleting;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PlanCheckTile({
    required this.plan,
    required this.selected,
    required this.dimmed,
    required this.isDeleting,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFFFFBF2) : LmsColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? kPremiumColor.withOpacity(0.45) : LmsColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDeleting ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                  size: 20,
                  color: selected
                      ? kPremiumColor
                      : (dimmed ? LmsColors.border : LmsColors.textGrey),
                ),
                const SizedBox(width: 10),
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
                                fontWeight: FontWeight.w700,
                                color: LmsColors.textDark,
                              ),
                            ),
                          ),
                          if (!plan.isActive) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: LmsColors.error.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'INACTIVE',
                                style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: LmsColors.error),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'AED ${plan.price.toStringAsFixed(0)}  ·  ${plan.durationDays} days',
                        style: const TextStyle(fontSize: 11.5, color: LmsColors.textGrey, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                if (isDeleting)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2, color: LmsColors.error),
                    ),
                  )
                else
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, size: 17, color: LmsColors.textGrey),
                    tooltip: 'Plan actions',
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [
                          Icon(Icons.edit_outlined, size: 16, color: LmsColors.textDark),
                          SizedBox(width: 8),
                          Text('Edit plan'),
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete_outline_rounded, size: 16, color: LmsColors.error),
                          SizedBox(width: 8),
                          Text('Delete plan', style: TextStyle(color: LmsColors.error)),
                        ]),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Edit only a lesson's subscription: free vs premium, the free-preview flag,
/// and which plans unlock it. Opened from the lesson detail screen and from
/// each row of the chapter lesson list, so access can be changed without
/// walking through the full lesson form.
///
/// Returns true when the lesson was saved.
Future<bool?> showLessonSubscriptionSheet(
  BuildContext context, {
  required int courseId,
  required int chapterId,
  required int lessonId,
  required String lessonTitle,
  required LessonAccessType accessType,
  required Set<int> planIds,
  required bool isFreePreview,
  List<LessonPlanSummary> attachedPlans = const [],
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChangeNotifierProvider(
      create: (_) => LessonUpdateProvider(),
      child: _LessonSubscriptionSheet(
        courseId: courseId,
        chapterId: chapterId,
        lessonId: lessonId,
        lessonTitle: lessonTitle,
        accessType: accessType,
        planIds: planIds,
        isFreePreview: isFreePreview,
        attachedPlans: attachedPlans,
      ),
    ),
  );
}

class _LessonSubscriptionSheet extends StatefulWidget {
  final int courseId;
  final int chapterId;
  final int lessonId;
  final String lessonTitle;
  final LessonAccessType accessType;
  final Set<int> planIds;
  final bool isFreePreview;
  final List<LessonPlanSummary> attachedPlans;

  const _LessonSubscriptionSheet({
    required this.courseId,
    required this.chapterId,
    required this.lessonId,
    required this.lessonTitle,
    required this.accessType,
    required this.planIds,
    required this.isFreePreview,
    required this.attachedPlans,
  });

  @override
  State<_LessonSubscriptionSheet> createState() => _LessonSubscriptionSheetState();
}

class _LessonSubscriptionSheetState extends State<_LessonSubscriptionSheet> {
  late LessonAccessType _accessType;
  late Set<int> _planIds;
  late bool _isFreePreview;

  @override
  void initState() {
    super.initState();
    _accessType = widget.accessType;
    _planIds = {...widget.planIds};
    _isFreePreview = widget.isFreePreview;
  }

  Future<void> _save() async {
    final provider = context.read<LessonUpdateProvider>();
    final isPremium = _accessType == LessonAccessType.premium;

    final ok = await provider.updateLesson(
      chapterId: widget.chapterId,
      lessonId: widget.lessonId,
      accessType: _accessType,
      isFreePreview: _isFreePreview,
      // The service only writes plans when the lesson is premium; a lesson
      // demoted to free is cleared server-side.
      planIds: isPremium ? _planIds.toList() : const [],
    );

    if (!mounted) return;
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LessonUpdateProvider>();
    final isPremium = _accessType == LessonAccessType.premium;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        decoration: const BoxDecoration(
          color: LmsColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: LmsColors.border, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Subscription',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: LmsColors.textDark),
              ),
              const SizedBox(height: 3),
              Text(
                widget.lessonTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, color: LmsColors.textGrey),
              ),
              const SizedBox(height: 18),

              _AccessToggle(
                value: _accessType,
                onChanged: (v) => setState(() => _accessType = v),
              ),

              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                decoration: BoxDecoration(
                  color: LmsColors.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: LmsColors.border),
                ),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isFreePreview,
                  onChanged: (v) => setState(() => _isFreePreview = v),
                  activeColor: LmsColors.primary,
                  title: const Text('Free preview', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  subtitle: const Text(
                    'Open to everyone even when the lesson is premium.',
                    style: TextStyle(fontSize: 11.5, color: LmsColors.textGrey),
                  ),
                ),
              ),

              if (isPremium) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Text(
                      'PLANS THAT UNLOCK THIS LESSON',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                        color: LmsColors.textGrey,
                      ),
                    ),
                    const Spacer(),
                    if (_planIds.isNotEmpty)
                      Text(
                        '${_planIds.length} selected',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kPremiumColor),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                LessonPlanSelector(
                  courseId: widget.courseId,
                  selectedPlanIds: _planIds,
                  attachedPlans: widget.attachedPlans,
                  onChanged: (ids) => setState(() => _planIds = ids),
                ),
              ],

              if (provider.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(provider.errorMessage!, style: const TextStyle(color: LmsColors.error, fontSize: 13)),
              ],

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: provider.isUpdating ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LmsColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: provider.isUpdating
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : const Text('Save', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccessToggle extends StatelessWidget {
  final LessonAccessType value;
  final ValueChanged<LessonAccessType> onChanged;

  const _AccessToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget segment(String label, IconData icon, LessonAccessType mode, Color color) {
      final selected = value == mode;
      return Expanded(
        child: InkWell(
          onTap: () => onChanged(mode),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? color : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15, color: selected ? Colors.white : LmsColors.textGrey),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : LmsColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: LmsColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LmsColors.border),
      ),
      child: Row(
        children: [
          segment('Free', Icons.lock_open_rounded, LessonAccessType.free, LmsColors.success),
          segment('Premium', Icons.workspace_premium_rounded, LessonAccessType.premium, kPremiumColor),
        ],
      ),
    );
  }
}
