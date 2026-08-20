import 'package:flutter_test/flutter_test.dart';
import 'package:admin_drapp/models/lesson_detail_model.dart';

Map<String, dynamic> _base(Map<String, dynamic> extra) => {
      'id': 1,
      'chapterId': 2,
      'title': 'L',
      'type': 'video',
      'displayOrder': 0,
      'isFreePreview': false,
      'accessType': 'premium',
      'status': 'published',
      ...extra,
    };

void main() {
  test('nested plan object becomes a one-item plans list', () {
    final l = LessonDetail.fromJson(_base({
      'planId': 2,
      'plan': {'id': 2, 'title': 'Gold', 'price': 999, 'durationDays': 30, 'isActive': true},
    }));
    expect(l.plans.single.title, 'Gold');
    expect(l.requiredPlanIds, {2});
  });

  test('plans array wins when the backend gains many-to-many', () {
    final l = LessonDetail.fromJson(_base({
      'planId': 2,
      'plans': [
        {'id': 2, 'title': 'Gold', 'price': 999, 'durationDays': 30, 'isActive': true},
        {'id': 3, 'title': 'Platinum', 'price': 1999, 'durationDays': 90, 'isActive': false},
      ],
    }));
    expect(l.plans.map((p) => p.title), ['Gold', 'Platinum']);
    expect(l.requiredPlanIds, {2, 3});
  });

  test('planIds array wins over the nested objects', () {
    final l = LessonDetail.fromJson(_base({
      'planId': 2,
      'planIds': [2, 5],
      'plan': {'id': 2, 'title': 'Gold', 'price': 999, 'durationDays': 30, 'isActive': true},
    }));
    expect(l.planIds, {2, 5});
  });

  test('planId alone still counts as one attached plan', () {
    final l = LessonDetail.fromJson(_base({'planId': 7}));
    expect(l.plans, isEmpty);
    expect(l.planIds, {7});
  });

  test('premium with no plan means any active subscription', () {
    final l = LessonDetail.fromJson(_base({'planId': null, 'plan': null}));
    expect(l.plans, isEmpty);
    expect(l.requiredPlanIds, isEmpty);
  });
}
