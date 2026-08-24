import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theam/theam_dart.dart';
import '../../models/panal_model.dart';
import '../../provider/admin_plan_provider.dart';

/// Create or edit a subscription plan.
///
/// Returns the saved plan so the caller can select it straight away, or null
/// when the sheet was dismissed without saving.
Future<AdminPlanModel?> showAddEditPlanSheet(
    BuildContext context, {
      required int courseId,
      AdminPlanModel? existingPlan,
    }) {
  return showModalBottomSheet<AdminPlanModel>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      // Its own provider instance so saving here doesn't disturb whatever
      // list the screen underneath is showing.
      return ChangeNotifierProvider(
        create: (_) => AdminPlanProvider(),
        child: _AddEditPlanSheet(courseId: courseId, existingPlan: existingPlan),
      );
    },
  );
}

class _AddEditPlanSheet extends StatefulWidget {
  final int courseId;
  final AdminPlanModel? existingPlan;

  const _AddEditPlanSheet({required this.courseId, this.existingPlan});

  @override
  State<_AddEditPlanSheet> createState() => _AddEditPlanSheetState();
}

class _AddEditPlanSheetState extends State<_AddEditPlanSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _durationController;
  late bool _isActive;

  bool get _isEditMode => widget.existingPlan != null;

  @override
  void initState() {
    super.initState();
    final plan = widget.existingPlan;
    _titleController = TextEditingController(text: plan?.title ?? '');
    _descriptionController = TextEditingController(text: plan?.description ?? '');
    _priceController = TextEditingController(text: plan?.price.toStringAsFixed(0) ?? '');
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

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<AdminPlanProvider>();
    final description = _descriptionController.text.trim();

    final bool success = _isEditMode
        ? await provider.updatePlan(
      courseId: widget.courseId,
      planId: widget.existingPlan!.id,
      title: _titleController.text.trim(),
      description: description.isEmpty ? null : description,
      price: double.parse(_priceController.text.trim()),
      durationDays: int.parse(_durationController.text.trim()),
      isActive: _isActive,
    )
        : await provider.createPlan(
      courseId: widget.courseId,
      title: _titleController.text.trim(),
      description: description.isEmpty ? null : description,
      price: double.parse(_priceController.text.trim()),
      durationDays: int.parse(_durationController.text.trim()),
    );

    if (!mounted) return;
    if (success) Navigator.pop(context, provider.lastSavedPlan);
  }

  InputDecoration _inputDecoration(String hint, {IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: LmsColors.textGrey, fontSize: 13.5),
      prefixIcon: icon != null ? Icon(icon, size: 18, color: LmsColors.textGrey) : null,
      filled: true,
      fillColor: LmsColors.bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: LmsColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: LmsColors.primary, width: 1.5),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: LmsColors.textGrey),
  );

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminPlanProvider>();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        decoration: const BoxDecoration(
          color: LmsColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
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
                Text(
                  _isEditMode ? 'Edit Plan' : 'Add Plan',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: LmsColors.textDark),
                ),
                const SizedBox(height: 20),

                _label('Plan Title'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _titleController,
                  autofocus: true,
                  decoration: _inputDecoration('e.g. 6 Month Access'),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Title is required' : null,
                ),
                const SizedBox(height: 18),

                _label('Description (optional)'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 2,
                  decoration: _inputDecoration('What this plan includes'),
                ),
                const SizedBox(height: 18),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Price (AED)'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _priceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: _inputDecoration('999'),
                            validator: (value) {
                              final price = double.tryParse(value?.trim() ?? '');
                              if (price == null) return 'Enter a price';
                              if (price < 0) return 'Cannot be negative';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Duration (days)'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _durationController,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration('180'),
                            validator: (value) {
                              final days = int.tryParse(value?.trim() ?? '');
                              if (days == null) return 'Enter days';
                              if (days <= 0) return 'Must be above 0';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (_isEditMode) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: LmsColors.bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: LmsColors.border),
                    ),
                    child: Material(
                  color: Colors.transparent,
                  child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _isActive,
                      onChanged: (value) => setState(() => _isActive = value),
                      activeColor: LmsColors.success,
                      title: const Text('Active', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        _isActive ? 'Students can subscribe to this plan' : 'Hidden from new subscribers',
                        style: const TextStyle(fontSize: 11.5, color: LmsColors.textGrey),
                      ),
                    ),
                  ),
                  ),
                ],

                if (provider.saveErrorMessage != null) ...[
                  const SizedBox(height: 14),
                  Text(provider.saveErrorMessage!, style: const TextStyle(color: LmsColors.error, fontSize: 13)),
                ],

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: provider.isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LmsColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: provider.isSaving
                        ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    )
                        : Text(
                      _isEditMode ? 'Save Changes' : 'Add Plan',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
