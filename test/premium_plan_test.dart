import 'package:flutter_test/flutter_test.dart';

import 'package:admin_drapp/models/panal_model.dart';
import 'package:admin_drapp/Screen/Dashbord/plan_card_editor.dart';

void main() {
  group('entitlements', () {
    test('there are exactly six codes and they are spelled as the API has them',
        () {
      expect(
        PlanEntitlement.values.map((e) => e.code).toList(),
        ['mcq', 'mock', 'rapid_recall', 'video_lecture', 'live_class',
            'ai_patient'],
      );
    });

    test('an unknown code is dropped, never guessed into another', () {
      final plan = AdminPlanModel.fromJson({
        'id': 1,
        'title': 'Plan A',
        'price': 55,
        'durationDays': 30,
        'entitlements': ['mock', 'not_a_real_code', 'rapid_recall'],
      });
      expect(plan.entitlements,
          [PlanEntitlement.mock, PlanEntitlement.rapidRecall]);
    });

    test('features and entitlements are independent', () {
      // Sales copy saying "Video Lectures" while the access list omits
      // video_lecture sells something the student cannot open. Neither side is
      // derived from the other, so the model must keep them apart.
      final plan = AdminPlanModel.fromJson({
        'id': 1,
        'title': 'Plan B',
        'price': 85,
        'durationDays': 45,
        'features': ['MCQ Bank', 'Mock Test'],
        'entitlements': ['mcq'],
      });
      expect(plan.features.length, 2);
      expect(plan.entitlements.length, 1);
    });
  });

  group('durationLabel', () {
    test('survives a round trip even when it disagrees with durationDays', () {
      // The server words it; 45 days may read as "45 days" or "1.5 months"
      // depending on its own rules, and the panel does not second-guess that.
      final plan = AdminPlanModel.fromJson({
        'id': 1,
        'title': 'Plan B',
        'price': 85,
        'durationDays': 45,
        'durationLabel': '6 weeks',
      });
      expect(plan.durationLabel, '6 weeks');
      expect(plan.durationDays, 45);
    });

    test('is rendered as sent, not recomputed', () {
      final plan = AdminPlanModel.fromJson({
        'id': 1,
        'title': 'Plan A',
        'price': 55,
        'durationDays': 30,
        'durationLabel': '1 month',
      });
      expect(plan.durationLabel, '1 month');
    });
  });

  group('a plan is refused before it is sent', () {
    test('every field the server checks is checked here first', () {
      final draft = PlanDraft();
      expect(draft.problem, 'needs a title');

      draft.titleController.text = 'Plan A';
      expect(draft.problem, 'needs a price above zero');

      draft.priceController.text = '0';
      expect(draft.problem, 'needs a price above zero');

      draft.priceController.text = '55';
      expect(draft.problem, 'needs a duration in days');

      draft.durationController.text = '30';
      expect(draft.problem, 'needs at least one entitlement');

      draft.entitlements.add(PlanEntitlement.mock);
      expect(draft.problem, isNull);
    });

    test('a blank draft is an unused row, not an invalid one', () {
      expect(PlanDraft().isBlank, isTrue);
      final started = PlanDraft()..titleController.text = 'Plan A';
      expect(started.isBlank, isFalse);
    });

    test('the tick list drops blank lines and keeps the rest verbatim', () {
      final draft = PlanDraft()
        ..titleController.text = 'Plan C'
        ..priceController.text = '150'
        ..durationController.text = '45'
        ..featuresController.text = 'MCQ Bank\n\n  Mock Test  \n';
      draft.entitlements.add(PlanEntitlement.mcq);

      expect(draft.toModel(4).features, ['MCQ Bank', 'Mock Test']);
    });
  });

  test('the write body omits ids - the route or the parent supplies them', () {
    final json = AdminPlanModel(
      id: 12,
      courseId: 4,
      title: 'Plan A',
      price: 55,
      durationDays: 30,
      isActive: true,
      entitlements: const [PlanEntitlement.mock],
    ).toJson();

    expect(json.containsKey('id'), isFalse);
    expect(json.containsKey('courseId'), isFalse);
    expect(json['entitlements'], ['mock']);
  });
}
