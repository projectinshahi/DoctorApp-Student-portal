// lib/repository/plan_access_provider.dart
//
// The plan this student is on: which one, and how long it has left.
//
// It decides nothing. Access is per item and the server decides it — a
// premium lesson comes back locked with its media stripped, a premium
// question is never in the set at all. This once marked whole tabs as locked
// by reading the plan's marketing bullets for words like "Mock Test", which
// shut an unsubscribed student out of the free lessons behind those tabs too.
import 'package:flutter/foundation.dart';

import '../models/quiz_model.dart' show QuizException;
import '../models/student_plans_model.dart';
import '../services/student_plans_service.dart';

class PlanAccessProvider extends ChangeNotifier {
  final StudentPlansService _service;

  PlanAccessProvider({StudentPlansService? service})
      : _service = service ?? StudentPlansService();

  StudentPlans? plans;
  bool isLoading = false;
  String? errorMessage;

  bool _fetched = false;
  Future<void>? _inFlight;

  Future<void> load() =>
      _inFlight ??= _fetch().whenComplete(() => _inFlight = null);

  Future<void> _fetch() async {
    isLoading = !_fetched;
    errorMessage = null;
    notifyListeners();

    try {
      plans = await _service.fetch();
      _fetched = true;
    } on QuizException catch (e) {
      errorMessage = e.message;
    }

    isLoading = false;
    notifyListeners();
  }

  /// The plan they are on, for the banner and the countdown. Straight off
  /// currentSubscription, never looked up among the cards — a plan taken off
  /// sale still has students on it and has no card.
  CurrentSubscription? get subscription => plans?.currentSubscription;

  /// Days left on the plan, whatever that number is. Null with no plan.
  int? get daysLeftOnPlan => daysUntilExpiry(subscription);

  /// Days left on the plan while it is close enough to say so, null the rest
  /// of the time. A countdown running all year is wallpaper; one that appears
  /// in the last days is a reminder.
  int? get expiringInDays {
    final days = daysLeftOnPlan;
    if (days == null || days < 0 || days > renewalWindow) return null;
    return days;
  }

  /// How close to the end the countdown starts.
  static const int renewalWindow = 10;

  void clear() {
    plans = null;
    errorMessage = null;
    isLoading = false;
    _fetched = false;
    notifyListeners();
  }
}

/// How many days [subscription] has left, or null when there is no plan.
///
/// Counted from the end date rather than taken from the server's own
/// daysLeft, which was worked out when the call was made: an app left open
/// overnight would otherwise go on showing yesterday's number. daysLeft is
/// the fallback for a subscription that came back without a date.
@visibleForTesting
int? daysUntilExpiry(CurrentSubscription? subscription, {DateTime? now}) {
  if (subscription == null) return null;

  final end = subscription.endDate;
  if (end == null) return subscription.daysLeft;

  // Whole days, not hours: a plan ending tonight and one ending tomorrow
  // morning are both "ends today" and "ends tomorrow" to a student, whatever
  // the clock says.
  final today = _dayOf(now ?? DateTime.now());
  return _dayOf(end).difference(today).inDays;
}

DateTime _dayOf(DateTime moment) =>
    DateTime(moment.year, moment.month, moment.day);

/// "Your plan ends in 6 days", in the words a student would use.
///
/// One phrasing for the countdown on home and for the renewal prompt a
/// reminder opens, so the two cannot come to disagree about the same day.
String planEndsLabel(int days) => switch (days) {
      <= 0 => 'Your plan ends today',
      1 => 'Your plan ends tomorrow',
      _ => 'Your plan ends in $days days',
    };
