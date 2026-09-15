import 'package:flutter/material.dart';

import '../../core/theam/theam_dart.dart';
import '../../models/panal_model.dart';

/// One plan being written, as controllers.
///
/// Kept separate from [AdminPlanModel] because a half-typed price is a string,
/// not a double - parsing on every keystroke would fight the admin mid-number.
class PlanDraft {
  final titleController = TextEditingController();
  final priceController = TextEditingController();
  final durationController = TextEditingController();
  final currencyController = TextEditingController(text: 'AED');

  /// Sales copy: free text, one line per tick. Never derived from
  /// [entitlements] - see PlanEntitlement.
  final featuresController = TextEditingController();

  String accentColor = '#EFEFEF';
  final Set<PlanEntitlement> entitlements = {};
  bool isActive = true;

  /// Set when the draft came from an existing plan, so saving edits it rather
  /// than creating a second one.
  int? id;

  PlanDraft();

  factory PlanDraft.from(AdminPlanModel plan) {
    final draft = PlanDraft()
      ..id = plan.id
      ..accentColor = plan.accentColor ?? '#EFEFEF'
      ..isActive = plan.isActive;
    draft.titleController.text = plan.title;
    draft.priceController.text =
        plan.price == plan.price.roundToDouble() ? '${plan.price.round()}' : '${plan.price}';
    draft.durationController.text = '${plan.durationDays}';
    // Empty rather than 'AED' for a plan stored without one: filling in a
    // default here would make merely opening an old plan count as an edit.
    draft.currencyController.text = plan.currency ?? '';
    draft.featuresController.text = plan.features.join('\n');
    draft.entitlements.addAll(plan.entitlements);
    return draft;
  }

  bool get isBlank =>
      titleController.text.trim().isEmpty &&
      priceController.text.trim().isEmpty &&
      durationController.text.trim().isEmpty;

  double? get price => double.tryParse(priceController.text.trim());
  int? get durationDays => int.tryParse(durationController.text.trim());

  /// The first thing wrong with this plan, or null. Mirrors what the server
  /// refuses, so a plan is not sent only to come back as
  /// `plans[2]: price must be a positive number`.
  String? get problem {
    if (titleController.text.trim().isEmpty) return 'needs a title';
    final p = price;
    if (p == null || p <= 0) return 'needs a price above zero';
    final d = durationDays;
    if (d == null || d <= 0) return 'needs a duration in days';
    if (entitlements.isEmpty) return 'needs at least one entitlement';
    return null;
  }

  AdminPlanModel toModel(int courseId) => AdminPlanModel(
        id: id ?? 0,
        courseId: courseId,
        title: titleController.text.trim(),
        price: price ?? 0,
        durationDays: durationDays ?? 0,
        isActive: isActive,
        currency: currencyController.text.trim(),
        accentColor: accentColor,
        features: [
          for (final line in featuresController.text.split('\n'))
            if (line.trim().isNotEmpty) line.trim(),
        ],
        entitlements: entitlements.toList(),
      );

  void dispose() {
    titleController.dispose();
    priceController.dispose();
    durationController.dispose();
    currencyController.dispose();
    featuresController.dispose();
  }
}

/// The swatches offered for a plan card's background.
const planAccentSwatches = <String>[
  '#EFEFEF',
  '#DDE5F5',
  '#F5DDDD',
  '#DDF5E4',
  '#F5EEDD',
  '#EADDF5',
];

Color parseAccent(String hex) {
  final cleaned = hex.replaceAll('#', '').trim();
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return const Color(0xFFEFEFEF);
  return Color(cleaned.length <= 6 ? 0xFF000000 | value : value);
}

/// The repeatable plan editor used by the course wizard and the course's own
/// access section.
class PlanCardEditor extends StatefulWidget {
  final List<PlanDraft> plans;
  final ValueChanged<List<PlanDraft>> onChanged;
  final bool enabled;

  const PlanCardEditor({
    super.key,
    required this.plans,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<PlanCardEditor> createState() => _PlanCardEditorState();
}

class _PlanCardEditorState extends State<PlanCardEditor> {
  void _add() {
    widget.onChanged([...widget.plans, PlanDraft()]);
  }

  void _remove(int index) {
    final next = [...widget.plans];
    next.removeAt(index).dispose();
    widget.onChanged(next);
  }

  void _reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final next = [...widget.plans];
    next.insert(newIndex, next.removeAt(oldIndex));
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.plans.isEmpty
                    ? 'No plans yet'
                    : '${widget.plans.length} plan'
                        '${widget.plans.length == 1 ? '' : 's'}',
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w800),
              ),
            ),
            TextButton.icon(
              onPressed: widget.enabled ? _add : null,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add plan'),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (widget.plans.isEmpty)
          const SizedBox.shrink()
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            buildDefaultDragHandles: false,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.plans.length,
            onReorder: _reorder,
            itemBuilder: (context, index) {
              final draft = widget.plans[index];
              return Padding(
                key: ValueKey(identityHashCode(draft)),
                padding: const EdgeInsets.only(bottom: 12),
                child: PlanCardForm(
                  index: index,
                  draft: draft,
                  enabled: widget.enabled,
                  draggable: true,
                  onRemove: () => _remove(index),
                  onChanged: () => setState(() {}),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// One plan's form, usable on its own.
///
/// The course wizard shows several inside a reorderable list; the Plans screen
/// shows one inside a dialog. [index], the drag handle and [onRemove] only make
/// sense in the first, so each is optional and simply absent in the second.
class PlanCardForm extends StatelessWidget {
  final int? index;
  final PlanDraft draft;
  final bool enabled;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  /// Only inside a ReorderableListView - a drag handle anywhere else asserts.
  final bool draggable;

  const PlanCardForm({
    super.key,
    required this.draft,
    required this.onChanged,
    this.index,
    this.enabled = true,
    this.onRemove,
    this.draggable = false,
  });

  @override
  Widget build(BuildContext context) {
    final problem = draft.isBlank ? null : draft.problem;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LmsColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: problem != null
              ? const Color(0xFFB8860B).withValues(alpha: 0.5)
              : LmsColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (enabled && draggable && index != null)
                ReorderableDragStartListener(
                  index: index!,
                  child: const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.drag_indicator_rounded,
                        size: 18, color: LmsColors.border),
                  ),
                ),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: parseAccent(draft.accentColor),
                  shape: BoxShape.circle,
                  border: Border.all(color: LmsColors.border),
                ),
              ),
              const SizedBox(width: 9),
              Text(index == null ? 'Plan' : 'Plan ${index! + 1}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: LmsColors.textGrey)),
              const Spacer(),
              if (!draft.isActive)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Text('RETIRED',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: LmsColors.textGrey)),
                ),
              if (onRemove != null)
                IconButton(
                onPressed: enabled ? onRemove : null,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                color: LmsColors.error,
                tooltip: 'Remove plan',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),

          _Field(draft.titleController, 'Plan name', 'Plan A',
              enabled: enabled, onChanged: onChanged),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                flex: 2,
                child: _Field(draft.priceController, 'Price', '55',
                    enabled: enabled,
                    number: true,
                    onChanged: onChanged),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Field(draft.currencyController, 'Currency', 'AED',
                    enabled: enabled, onChanged: onChanged),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _Field(draft.durationController, 'Days', '30',
                    enabled: enabled,
                    number: true,
                    onChanged: onChanged),
              ),
            ],
          ),
          const SizedBox(height: 12),

          const _Label('Card colour'),
          const SizedBox(height: 7),
          Wrap(
            spacing: 8,
            children: [
              for (final hex in planAccentSwatches)
                GestureDetector(
                  onTap: enabled
                      ? () {
                          draft.accentColor = hex;
                          onChanged();
                        }
                      : null,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: parseAccent(hex),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: draft.accentColor == hex
                            ? LmsColors.primary
                            : LmsColors.border,
                        width: draft.accentColor == hex ? 2.5 : 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          const _Label('What it unlocks'),
          const SizedBox(height: 2),
          const Text(
            'The access list the app enforces. Ticking a box here is what '
            'actually opens the content.',
            style: TextStyle(fontSize: 11, color: LmsColors.textGrey),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in PlanEntitlement.values)
                FilterChip(
                  label: Text(e.label, style: const TextStyle(fontSize: 12)),
                  selected: draft.entitlements.contains(e),
                  onSelected: enabled
                      ? (on) {
                          on
                              ? draft.entitlements.add(e)
                              : draft.entitlements.remove(e);
                          onChanged();
                        }
                      : null,
                  selectedColor: LmsColors.primarySoft,
                  checkmarkColor: LmsColors.primary,
                  backgroundColor: LmsColors.bg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: draft.entitlements.contains(e)
                          ? LmsColors.primary
                          : LmsColors.border,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          const _Label('Tick list on the pricing page'),
          const SizedBox(height: 2),
          const Text(
            'Sales copy, one line each. Written by hand — it is never built '
            'from the boxes above, and neither is derived from the other.',
            style: TextStyle(fontSize: 11, color: LmsColors.textGrey),
          ),
          const SizedBox(height: 7),
          _Field(draft.featuresController, '', 'Mock Test\nRapid Recalls',
              enabled: enabled, maxLines: 4, onChanged: onChanged),

          if (problem != null) ...[
            const SizedBox(height: 10),
            Text('This plan $problem.',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB8860B))),
          ],
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.7,
          color: LmsColors.textGrey,
        ),
      );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool enabled;
  final bool number;
  final int maxLines;
  final VoidCallback onChanged;

  const _Field(
    this.controller,
    this.label,
    this.hint, {
    required this.enabled,
    required this.onChanged,
    this.number = false,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        enabled: enabled,
        maxLines: maxLines,
        keyboardType: number ? TextInputType.number : null,
        onChanged: (_) => onChanged(),
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          labelText: label.isEmpty ? null : label,
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 12.5, color: LmsColors.textGrey),
          isDense: true,
          filled: true,
          fillColor: LmsColors.bg,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: LmsColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: LmsColors.border),
          ),
        ),
      );
}

/// The fields of [after] that differ from [before], as a `PUT /api/plans/:id`
/// body. Empty when nothing changed.
///
/// Built field by field rather than by diffing [AdminPlanModel.toJson], which
/// leaves out empty optionals - a tick list cleared to nothing would look
/// unchanged there and never be sent.
///
/// Entitlements compare as a set: they are an access list, and ticking the same
/// boxes in a different order is not an edit. Features compare in order,
/// because the tick list is read top to bottom.
Map<String, dynamic> planChanges(AdminPlanModel before, AdminPlanModel after) {
  String norm(String? v) => (v ?? '').trim();
  String accent(String? v) =>
      norm(v).isEmpty ? '#EFEFEF' : norm(v).toUpperCase();

  final body = <String, dynamic>{};
  if (after.title.trim() != before.title.trim()) {
    body['title'] = after.title.trim();
  }
  if (after.price != before.price) body['price'] = after.price;
  if (after.durationDays != before.durationDays) {
    body['durationDays'] = after.durationDays;
  }
  if (norm(after.currency) != norm(before.currency)) {
    body['currency'] = norm(after.currency);
  }
  if (accent(after.accentColor) != accent(before.accentColor)) {
    body['accentColor'] = accent(after.accentColor);
  }
  if (after.isActive != before.isActive) body['isActive'] = after.isActive;

  var featuresChanged = after.features.length != before.features.length;
  for (var i = 0; !featuresChanged && i < after.features.length; i++) {
    featuresChanged = after.features[i] != before.features[i];
  }
  if (featuresChanged) body['features'] = after.features;

  final a = {for (final e in after.entitlements) e.code};
  final b = {for (final e in before.entitlements) e.code};
  if (a.length != b.length || !a.containsAll(b)) {
    body['entitlements'] = [
      for (final e in PlanEntitlement.values)
        if (a.contains(e.code)) e.code,
    ];
  }
  return body;
}
