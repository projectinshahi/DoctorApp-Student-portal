import 'package:dr_app/View_model/plan_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('features fall back to description bullets, period reads as month', () {
    final plan = PlanModel.fromJson({
      'id': 1,
      'courseId': 2,
      'title': 'Pro',
      'description': 'All videos\nDownloadable notes; Quiz bank',
      'price': 25,
      'durationDays': 30,
    });

    expect(plan.features, ['All videos', 'Downloadable notes', 'Quiz bank']);
    expect(plan.periodLabel, 'month');
  });

  test('explicit features array wins over description', () {
    final plan = PlanModel.fromJson({
      'id': 1,
      'courseId': 2,
      'title': 'Pro',
      'description': 'ignored',
      'features': ['A', ' B '],
      'price': 199.0,
      'durationDays': 365,
    });

    expect(plan.features, ['A', 'B']);
    expect(plan.periodLabel, 'year');
  });
}
