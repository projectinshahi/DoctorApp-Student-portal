import 'package:dr_app/models/student_plans_model.dart';
import 'package:dr_app/repository/plan_access_provider.dart';
import 'package:dr_app/services/student_plans_service.dart';
import 'package:dr_app/widget/app_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _plan(
  int id,
  String title, {
  List<String> features = const ['Mock Test', 'Rapid Recalls'],
  bool isCurrent = false,
}) =>
    {
      'id': id,
      'title': title,
      'description': 'x',
      'price': 85,
      'currency': 'USD',
      'durationDays': 45,
      'durationLabel': '45 days access',
      'features': features,
      'accentColor': '#0EA5E9',
      'displayOrder': 1,
      'isCurrent': isCurrent,
    };

class _FakePlansService extends StudentPlansService {
  final Map<String, dynamic> body;
  int calls = 0;

  _FakePlansService(this.body);

  @override
  Future<StudentPlans> fetch() async {
    calls++;
    return StudentPlans.fromJson(body);
  }
}

void main() {
  group('reading the plan', () {
    test('a card keeps the wording the server sent', () {
      final plans = StudentPlans.fromJson({
        'hasCourseSelected': true,
        'isPremiumCourse': true,
        'course': {'id': 22, 'title': 'GP GULF', 'accessType': 'premium'},
        'plans': [_plan(15, 'Plan B', isCurrent: true)],
        'currentSubscription': {
          'id': 5,
          'planId': 15,
          'plan': {'id': 15, 'title': 'Plan B'},
          'endDate': '2026-10-07T00:00:00.000Z',
          'daysLeft': 14,
        },
      });

      expect(plans.isSubscribed, isTrue);
      // Always filled in by the server, so no card has to phrase it.
      expect(plans.plans.single.durationLabel, '45 days access');
      expect(plans.currentCard?.title, 'Plan B');
      expect(plans.currentSubscription?.planTitle, 'Plan B');
      expect(plans.currentSubscription?.daysLeft, 14);
    });

    test('the banner reads a plan that is no longer on sale', () {
      // Student 42's case: they hold a plan that was withdrawn, so it is not
      // among the cards. Looking the id up there would find nothing.
      final plans = StudentPlans.fromJson({
        'plans': [_plan(15, 'Plan B')],
        'currentSubscription': {
          'id': 5,
          'planId': 7,
          'plan': {'id': 7, 'title': 'Onam offere price'},
          'daysLeft': 14,
        },
      });

      expect(plans.currentSubscription?.planTitle, 'Onam offere price');
      expect(plans.currentCard, isNull);
    });
  });

  group('the provider', () {
    test('reads the plan the student is on', () async {
      final access = PlanAccessProvider(
        service: _FakePlansService({
          'plans': [_plan(15, 'Plan B', isCurrent: true)],
          'currentSubscription': {
            'id': 5,
            'planId': 15,
            'plan': {'id': 15, 'title': 'Plan B'},
            'daysLeft': 14,
          },
        }),
      );
      await access.load();

      expect(access.subscription?.planTitle, 'Plan B');
      expect(access.plans?.isSubscribed, isTrue);
    });
  });

  group('what the student sees', () {
    testWidgets('every tab is open — access is decided inside them',
        (tester) async {
      // Locking a tab also shuts out the free lessons behind it, which is
      // the part an unsubscribed student came for.
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final tapped = <int>[];
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(440, 956),
          minTextAdapt: true,
          builder: (context, _) => MaterialApp(
            home: Scaffold(
              body: AppBottomNav(currentIndex: 0, onTap: tapped.add),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.lock_rounded), findsNothing);

      await tester.tap(find.text('QBank'));
      expect(tapped, [1]);
    });
  });

  group('the countdown on a plan running out', () {
    final now = DateTime(2026, 9, 23, 22, 30);

    CurrentSubscription sub({DateTime? endDate, int daysLeft = 0}) =>
        CurrentSubscription(
            id: 7, planId: 3, endDate: endDate, daysLeft: daysLeft);

    test('counts whole days from the end date', () {
      expect(
        daysUntilExpiry(sub(endDate: DateTime(2026, 9, 29, 3)), now: now),
        6,
        reason: 'an early-morning expiry is still six days away, not five',
      );
    });

    test("today's date beats a daysLeft worked out days ago", () {
      // The number the server sent when the app was last opened.
      expect(
        daysUntilExpiry(sub(endDate: DateTime(2026, 9, 24), daysLeft: 9),
            now: now),
        1,
      );
    });

    test('falls back to daysLeft when no date came back', () {
      expect(daysUntilExpiry(sub(daysLeft: 4), now: now), 4);
    });

    test('no subscription, nothing to count', () {
      expect(daysUntilExpiry(null, now: now), isNull);
    });

    test('phrased the way a student would say it', () {
      expect(planEndsLabel(6), 'Your plan ends in 6 days');
      expect(planEndsLabel(1), 'Your plan ends tomorrow');
      expect(planEndsLabel(0), 'Your plan ends today');
    });

    test('shown inside the window and not before it', () {
      PlanAccessProvider withDays(int days) => PlanAccessProvider()
        ..plans = StudentPlans(
            currentSubscription: sub(
                endDate: DateTime.now().add(Duration(days: days, hours: 2))));

      expect(withDays(10).expiringInDays, 10);
      expect(withDays(1).expiringInDays, 1);
      expect(withDays(11).expiringInDays, isNull, reason: 'too far off yet');
      expect(withDays(-1).expiringInDays, isNull,
          reason: 'already lapsed — that is the gate, not a countdown');
    });
  });
}
