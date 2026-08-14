// lib/view/admin/plans/plan_management_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theam/theam_dart.dart';
import '../../../provider/admin_plan_provider.dart';
import '../../models/panal_model.dart';

class PlanManagementScreen extends StatefulWidget {
  final int courseId;
  final String courseTitle;

  const PlanManagementScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  State<PlanManagementScreen> createState() => _PlanManagementScreenState();
}

class _PlanManagementScreenState extends State<PlanManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminPlanProvider>().loadPlans(widget.courseId);
    });
  }

  Future<void> _openPlanDialog({AdminPlanModel? existingPlan}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _PlanFormDialog(
        courseId: widget.courseId,
        existingPlan: existingPlan,
      ),
    );

    if (result == true && mounted) {
      context.read<AdminPlanProvider>().loadPlans(widget.courseId);
    }
  }

  Future<void> _confirmDelete(AdminPlanModel plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text("Delete plan?"),
        content: Text('This will permanently delete "${plan.title}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: LmsColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    final provider = context.read<AdminPlanProvider>();
    final success = await provider.deletePlan(courseId: widget.courseId, planId: plan.id);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? '"${plan.title}" deleted' : (provider.deleteErrorMessage ?? 'Failed to delete')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LmsColors.bg,
      appBar: AppBar(
        backgroundColor: LmsColors.surface,
        elevation: 0,
        foregroundColor: LmsColors.textDark,
        title: Text("Plans — ${widget.courseTitle}"),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openPlanDialog(),
        backgroundColor: LmsColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Add Plan", style: TextStyle(color: Colors.white)),
      ),
      body: Consumer<AdminPlanProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null) {
            return Center(child: Text(provider.errorMessage!));
          }

          if (provider.plans.isEmpty) {
            return const Center(child: Text("No plans yet. Tap 'Add Plan' to create one."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: provider.plans.length,
            itemBuilder: (context, index) {
              final plan = provider.plans[index];

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: LmsColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: LmsColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                plan.title,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(width: 8),
                              if (!plan.isActive)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    "Inactive",
                                    style: TextStyle(fontSize: 11, color: LmsColors.textGrey),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "AED ${plan.price.toStringAsFixed(0)} / ${plan.durationDays} days",
                            style: const TextStyle(fontSize: 13, color: LmsColors.textGrey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => _openPlanDialog(existingPlan: plan),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: LmsColors.error),
                      onPressed: () => _confirmDelete(plan),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PlanFormDialog extends StatefulWidget {
  final int courseId;
  final AdminPlanModel? existingPlan;

  const _PlanFormDialog({required this.courseId, this.existingPlan});

  @override
  State<_PlanFormDialog> createState() => _PlanFormDialogState();
}

class _PlanFormDialogState extends State<_PlanFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _durationController;
  late bool _isActive;

  bool get isEditing => widget.existingPlan != null;

  @override
  void initState() {
    super.initState();
    final plan = widget.existingPlan;
    _titleController = TextEditingController(text: plan?.title ?? '');
    _descriptionController = TextEditingController(text: plan?.description ?? '');
    _priceController = TextEditingController(text: plan?.price.toString() ?? '');
    _durationController = TextEditingController(text: plan?.durationDays.toString() ?? '');
    _isActive = plan?.isActive ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _handleSave(AdminPlanProvider provider) async {
    if (!_formKey.currentState!.validate()) return;

    bool success;
    if (isEditing) {
      success = await provider.updatePlan(
        courseId: widget.courseId,
        planId: widget.existingPlan!.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        price: double.tryParse(_priceController.text.trim()),
        durationDays: int.tryParse(_durationController.text.trim()),
        isActive: _isActive,
      );
    } else {
      success = await provider.createPlan(
        courseId: widget.courseId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        price: double.tryParse(_priceController.text.trim()) ?? 0,
        durationDays: int.tryParse(_durationController.text.trim()) ?? 0,
      );
    }

    if (!mounted) return;

    if (success) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.saveErrorMessage ?? 'Failed to save plan')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Consumer<AdminPlanProvider>(
              builder: (context, provider, child) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEditing ? "Edit plan" : "Add plan",
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: "Title", border: OutlineInputBorder()),
                      validator: (v) => (v == null || v.trim().isEmpty) ? "Required" : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(labelText: "Description (optional)", border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _priceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: "Price (AED)", border: OutlineInputBorder()),
                            validator: (v) => (double.tryParse(v?.trim() ?? '') == null) ? "Invalid" : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _durationController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: "Duration (days)", border: OutlineInputBorder()),
                            validator: (v) => (int.tryParse(v?.trim() ?? '') == null) ? "Invalid" : null,
                          ),
                        ),
                      ],
                    ),
                    if (isEditing) ...[
                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text("Active"),
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: provider.isSaving ? null : () => Navigator.pop(context, false),
                            child: const Text("Cancel"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: provider.isSaving ? null : () => _handleSave(provider),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: LmsColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: provider.isSaving
                                ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                                : const Text("Save"),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}