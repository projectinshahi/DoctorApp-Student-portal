// lib/repository/plan_access_provider.dart
//
// Which tabs this student's plan covers.
//
// A hint, not the authority. The server decides access — it checks the plan's
// entitlement codes, which it deliberately does not send to the phone — and
// all this does is mark a tab the plan's own card copy does not mention, so a
// student is not sent into a section that will refuse them.
//
// It fails open on purpose. Copy is written by hand and gets reworded, so an
// unrecognised bullet leaves the tab open and the server turns the student
// away if it really is not theirs. The opposite mistake — locking a tab
// somebody paid for because a bullet was renamed — is the one that costs.
import 'package:flutter/foundation.dart';

import '../models/quiz_model.dart' show QuizException;
import '../models/student_plans_model.dart';
import '../services/student_plans_service.dart';

/// The tabs a plan can cover.
enum PlanFeature { qbank, tests, aiVideos, recall }

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

  /// The card copy of the plan they hold, or null when it cannot be known —
  /// no subscription yet, or a plan that has since been taken off sale and so
  /// has no card. Null means "do not lock anything".
  List<String>? get currentFeatures {
    final data = plans;
    if (data == null || !data.isSubscribed) return null;
    return data.currentCard?.features;
  }

  /// The plan they are on, for the banner. Straight off currentSubscription,
  /// never looked up among the cards — a withdrawn plan is not there.
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

  bool allows(PlanFeature feature) => planAllows(currentFeatures, feature);

  /// The tabs to mark locked, by their index in the bottom bar.
  Set<int> get lockedTabs => {
        if (!allows(PlanFeature.qbank)) 1,
        if (!allows(PlanFeature.tests)) 2,
        if (!allows(PlanFeature.aiVideos)) 3,
        if (!allows(PlanFeature.recall)) 4,
      };

  void clear() {
    plans = null;
    errorMessage = null;
    isLoading = false;
    _fetched = false;
    notifyListeners();
  }
}

/// Whether [features] — a plan's card copy — mentions [feature].
///
/// Matched loosely, and open when nothing is known: see the note at the top
/// of this file. "Mock Test" covers the tests tab; "Rapid Recalls" covers
/// recall; neither mentions videos, so that one is marked.
@visibleForTesting
bool planAllows(List<String>? features, PlanFeature feature) {
  if (features == null || features.isEmpty) return true;

  final copy = features.map((line) => line.toLowerCase()).join(' | ');

  // Copy this rule cannot read at all — "Everything in Plan C" — is not a
  // plan without features, it is a plan whose wording says nothing about
  // them. Locking every tab on that basis is exactly the mistake worth
  // avoiding, so an unreadable card locks nothing.
  if (!PlanFeature.values.any((known) => _mentions(known, copy))) return true;

  return _mentions(feature, copy);
}

bool _mentions(PlanFeature feature, String copy) {
  final words = switch (feature) {
    PlanFeature.qbank => ['mcq', 'question', 'qbank', 'q bank', 'quiz', 'practice'],
    PlanFeature.tests => ['mock', 'test', 'grand', 'exam'],
    PlanFeature.recall => ['recall', 'revision', 'flash', 'card'],
    PlanFeature.aiVideos => ['video', 'lecture', 'class', 'ai ', 'patient'],
  };
  return words.any(copy.contains);
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
