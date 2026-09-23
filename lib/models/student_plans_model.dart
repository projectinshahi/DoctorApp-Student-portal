// lib/models/student_plans_model.dart
//
// GET /api/users/me/plans — the plans for the course this student has
// selected, and the subscription they are on.
import 'package:flutter/foundation.dart';

@immutable
class StudentPlans {
  final bool hasCourseSelected;
  final bool isPremiumCourse;
  final PlanCourse? course;
  final List<PlanCard> plans;

  /// What they are on now. Its plan may not be among [plans] — a plan taken
  /// off sale still has students on it — so the banner reads from here and
  /// never by looking the id up in the cards.
  final CurrentSubscription? currentSubscription;

  const StudentPlans({
    this.hasCourseSelected = false,
    this.isPremiumCourse = false,
    this.course,
    this.plans = const [],
    this.currentSubscription,
  });

  bool get isSubscribed => currentSubscription != null;

  /// The card for the plan they hold, when it is still on sale. Null for a
  /// withdrawn plan — which is why nothing here may assume it exists.
  PlanCard? get currentCard {
    for (final plan in plans) {
      if (plan.isCurrent) return plan;
    }
    return null;
  }

  factory StudentPlans.fromJson(Map<String, dynamic> json) {
    final rawPlans = json['plans'];
    return StudentPlans(
      hasCourseSelected: json['hasCourseSelected'] == true,
      isPremiumCourse: json['isPremiumCourse'] == true,
      course: json['course'] is Map
          ? PlanCourse.fromJson(Map<String, dynamic>.from(json['course']))
          : null,
      plans: rawPlans is List
          ? rawPlans
              .whereType<Map>()
              .map((p) => PlanCard.fromJson(Map<String, dynamic>.from(p)))
              .toList()
          : const [],
      currentSubscription: json['currentSubscription'] is Map
          ? CurrentSubscription.fromJson(
              Map<String, dynamic>.from(json['currentSubscription']))
          : null,
    );
  }
}

@immutable
class PlanCourse {
  final int id;
  final String title;
  final String? accessType;

  const PlanCourse({required this.id, required this.title, this.accessType});

  factory PlanCourse.fromJson(Map<String, dynamic> json) => PlanCourse(
        id: _toInt(json['id']) ?? 0,
        title: (json['title'] ?? '').toString(),
        accessType: json['accessType']?.toString(),
      );
}

@immutable
class PlanCard {
  final int id;
  final String title;
  final String? description;
  final double price;
  final String currency;

  /// Always filled in by the server — "45 days access", "3 months access" —
  /// so the card never has to phrase it from [durationDays].
  final String durationLabel;
  final int durationDays;

  /// The card copy, in the admin's words. Sales text, not access codes: the
  /// server decides what a plan unlocks.
  final List<String> features;

  final String? accentColor;
  final int displayOrder;

  /// The plan they are on: the card says "Your plan" rather than a price.
  final bool isCurrent;

  const PlanCard({
    required this.id,
    required this.title,
    this.description,
    this.price = 0,
    this.currency = 'USD',
    this.durationLabel = '',
    this.durationDays = 0,
    this.features = const [],
    this.accentColor,
    this.displayOrder = 0,
    this.isCurrent = false,
  });

  factory PlanCard.fromJson(Map<String, dynamic> json) {
    final rawFeatures = json['features'];
    return PlanCard(
      id: _toInt(json['id']) ?? 0,
      title: (json['title'] ?? '').toString(),
      description: json['description']?.toString(),
      price: _toDouble(json['price']),
      currency: (json['currency'] ?? 'USD').toString(),
      durationLabel: (json['durationLabel'] ?? '').toString(),
      durationDays: _toInt(json['durationDays']) ?? 0,
      features: rawFeatures is List
          ? rawFeatures.map((f) => '$f').where((f) => f.isNotEmpty).toList()
          : const [],
      accentColor: json['accentColor']?.toString(),
      displayOrder: _toInt(json['displayOrder']) ?? 0,
      isCurrent: json['isCurrent'] == true,
    );
  }
}

@immutable
class CurrentSubscription {
  final int id;
  final int planId;
  final String planTitle;
  final DateTime? endDate;
  final int daysLeft;

  const CurrentSubscription({
    required this.id,
    required this.planId,
    this.planTitle = '',
    this.endDate,
    this.daysLeft = 0,
  });

  factory CurrentSubscription.fromJson(Map<String, dynamic> json) {
    final plan = json['plan'];
    return CurrentSubscription(
      id: _toInt(json['id']) ?? 0,
      planId: _toInt(json['planId']) ?? 0,
      planTitle: plan is Map ? '${plan['title'] ?? ''}' : '',
      endDate: DateTime.tryParse('${json['endDate'] ?? ''}')?.toLocal(),
      daysLeft: _toInt(json['daysLeft']) ?? 0,
    );
  }
}

int? _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}');
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}') ?? 0;
}
