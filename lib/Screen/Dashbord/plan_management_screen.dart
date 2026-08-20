// lib/view/admin/plans/plan_management_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theam/theam_dart.dart';
import '../../models/panal_model.dart';
import '../../provider/admin_plan_provider.dart';
import 'add_edit_plan_sheet.dart';

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
    final saved = await showAddEditPlanSheet(
      context,
      courseId: widget.courseId,
      existingPlan: existingPlan,
    );

    if (saved != null && mounted) {
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
