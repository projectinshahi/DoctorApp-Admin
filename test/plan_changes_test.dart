import 'package:flutter_test/flutter_test.dart';

import 'package:admin_drapp/models/panal_model.dart';
import 'package:admin_drapp/Screen/Dashbord/plan_card_editor.dart';

void main() {
  final base = AdminPlanModel.fromJson({
    'id': 7,
    'courseId': 22,
    'title': 'Plan B',
    'price': 85,
    'durationDays': 45,
    'currency': 'AED',
    'accentColor': '#DDE5F5',
    'features': ['MCQ Bank', 'Mock Test'],
    'entitlements': ['mcq', 'mock'],
    'isActive': true,
  });

  test('opening a plan and saving it untouched sends nothing', () {
    final draft = PlanDraft.from(base);
    expect(planChanges(base, draft.toModel(22)), isEmpty);
    draft.dispose();
  });

  test('an old plan with no currency or colour is not "edited" by opening it',
      () {
    // PlanDraft fills in defaults for the form; those defaults must not come
    // back out as changes the admin never made.
    final legacy = AdminPlanModel.fromJson({
      'id': 3,
      'courseId': 22,
      'title': 'Old plan',
      'price': 50,
      'durationDays': 30,
      'entitlements': ['mock'],
    });
    final draft = PlanDraft.from(legacy);
    expect(planChanges(legacy, draft.toModel(22)), isEmpty);
    draft.dispose();
  });

  test('only the edited field goes on the wire', () {
    final draft = PlanDraft.from(base)..priceController.text = '95';
    expect(planChanges(base, draft.toModel(22)), {'price': 95.0});
    draft.dispose();
  });

  test('ticking the same entitlements in another order is not an edit', () {
    final draft = PlanDraft.from(base);
    draft.entitlements
      ..clear()
      ..addAll([PlanEntitlement.mock, PlanEntitlement.mcq]);
    expect(planChanges(base, draft.toModel(22)), isEmpty);
    draft.dispose();
  });

  test('removing an entitlement sends the whole new list', () {
    final draft = PlanDraft.from(base)..entitlements.remove(PlanEntitlement.mock);
    expect(planChanges(base, draft.toModel(22)), {
      'entitlements': ['mcq'],
    });
    draft.dispose();
  });

  test('clearing the tick list is sent, not silently dropped', () {
    final draft = PlanDraft.from(base)..featuresController.text = '';
    expect(planChanges(base, draft.toModel(22)), {'features': <String>[]});
    draft.dispose();
  });

  test('retiring is a one-field change', () {
    expect(planChanges(base, base.copyWith(isActive: false)),
        {'isActive': false});
  });
}
