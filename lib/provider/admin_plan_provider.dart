// lib/provider/admin_plan_provider.dart
import 'package:flutter/material.dart';

import '../models/panal_model.dart';
import '../services/admin_plan_services.dart';

class AdminPlanProvider extends ChangeNotifier {
  final AdminPlanService _service = AdminPlanService();

  bool isLoading = false;
  String? errorMessage;
  List<AdminPlanModel> plans = [];

  bool isSaving = false;
  String? saveErrorMessage;

  /// The plan returned by the last successful create/update — lets a caller
  /// (e.g. the lesson sheet) select the plan it just created.
  AdminPlanModel? lastSavedPlan;

  bool isDeleting = false;
  String? deleteErrorMessage;

  Future<void> loadPlans(int courseId) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      plans = await _service.getPlansForCourse(courseId);
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createPlan({
    required int courseId,
    required String title,
    String? description,
    required double price,
    required int durationDays,
  }) async {
    isSaving = true;
    saveErrorMessage = null;
    notifyListeners();

    try {
      lastSavedPlan = await _service.createPlan(
        courseId: courseId,
        plan: AdminPlanModel(
          id: 0,
          courseId: courseId,
          title: title,
          description: description,
          price: price,
          durationDays: durationDays,
          isActive: true,
        ),
      );
      isSaving = false;
      notifyListeners();
      await loadPlans(courseId);
      return true;
    } catch (e) {
      saveErrorMessage = e.toString().replaceFirst('Exception: ', '');
      isSaving = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updatePlan({
    required int courseId,
    required int planId,
    String? title,
    String? description,
    double? price,
    int? durationDays,
    bool? isActive,
  }) async {
    isSaving = true;
    saveErrorMessage = null;
    notifyListeners();

    try {
      lastSavedPlan = await _service.updatePlan(
        planId: planId,
        title: title,
        description: description,
        price: price,
        durationDays: durationDays,
        isActive: isActive,
      );
      isSaving = false;
      notifyListeners();
      await loadPlans(courseId);
      return true;
    } catch (e) {
      saveErrorMessage = e.toString().replaceFirst('Exception: ', '');
      isSaving = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deletePlan({required int courseId, required int planId}) async {
    isDeleting = true;
    deleteErrorMessage = null;
    notifyListeners();

    try {
      await _service.deletePlan(planId);
      isDeleting = false;
      notifyListeners();
      await loadPlans(courseId);
      return true;
    } catch (e) {
      deleteErrorMessage = e.toString().replaceFirst('Exception: ', '');
      isDeleting = false;
      notifyListeners();
      return false;
    }
  }
}