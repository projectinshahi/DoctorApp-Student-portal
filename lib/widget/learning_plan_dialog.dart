// lib/widget/learning_plan_dialog.dart
//
// "Your Learning Plan Is Not Active" — shown over home when a student has no
// plan for the premium course they picked.
//
// Read from what the app already holds: the profile's subscription block, or
// the course tree's own paid flag. Both come back with the first two calls
// home makes, so this needs no request of its own.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:provider/provider.dart';

import '../View_model/profile_model.dart';
import '../repository/plan_access_provider.dart';
import '../repository/profile_provider.dart';
import '../repository/refresh_api_provider.dart';
import '../repository/selection_content_provider.dart';
import '../core/theam /app_color.dart';
import '../models/selection_content_model.dart';
import '../core/utils/website.dart';

/// True when the student's course needs a plan and they do not have one.
///
/// False while either answer is still missing: telling a paying student their
/// plan is inactive is worse than saying nothing for a moment. False for a
/// free course too — there is nothing to buy.
bool learningPlanInactive({
  ProfileModel? profile,
  SelectionContentModel? content,
}) {
  final subscription = profile?.subscriptionInfo;
  final access = profile?.selectedCourse?.accessType ?? content?.course?.accessType;

  // Nothing loaded yet.
  if (subscription == null && content == null) return false;

  final premium = subscription?.isPremiumCourse ??
      (access != null && access.toLowerCase() != 'free');
  final paid = subscription?.hasPaid ?? content?.hasPaid ?? false;

  return premium && !paid;
}

/// The gate shown over home when the plan is not active.
///
/// Not a dialog and not dismissible: no close button, the screen behind it
/// takes no taps, and it is rebuilt from the providers — so it closes only
/// when the plan is active, and comes back on the next app open if it is not.
class LearningPlanGate extends StatelessWidget {
  const LearningPlanGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      // Material, because this sits beside the Scaffold rather than inside
      // it: without one, every Text here falls back to Flutter's unstyled
      // debug rendering — monospace with yellow underlines.
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Swallows every tap meant for home — the nav bar included.
            const ModalBarrier(dismissible: false, color: Color(0xB3000000)),
            Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 26.w, vertical: 32.h),
                child: const LearningPlanCard(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Your plan ends in 3 days" — the prompt an expiry reminder opens.
///
/// Dismissible, and it opens nothing: the plan is still working, and renewing
/// happens on the website like every other purchase. Walking the student into
/// a screen whose only button is that same link would be a step for nothing.
///
/// [daysLeft] null when it cannot be known — a reminder tapped before the
/// plan has loaded.
Future<void> showRenewPlanDialog(BuildContext context, {int? daysLeft}) async {
  final renew = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: const Color(0xFFEDF6D8),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22.r)),
      icon: Icon(Icons.schedule_rounded,
          size: 30.sp, color: const Color(0xFF8A5B18)),
      title: Text(
        daysLeft == null ? 'Your plan is ending soon' : planEndsLabel(daysLeft),
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: 17.sp,
            fontWeight: FontWeight.w800,
            color: Colors.black87),
      ),
      content: Text(
        'Renew on our website to keep your lessons, tests and rapid recall '
        'without a break.',
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: 13.sp,
            height: 1.5,
            color: Colors.black.withValues(alpha: 0.72)),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text('Not now',
              style: TextStyle(
                  fontSize: 13.sp,
                  color: Colors.black.withValues(alpha: 0.6))),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColor.buttoncolor,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 12.h),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22.r)),
          ),
          child: Text('Explore plans',
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );

  if (renew == true && context.mounted) await openWebsite(context);
}

/// Asks again until the server says the plan is active, or the tries run out.
///
/// The website takes the money and tells the backend over a webhook a moment
/// later, so the first look after a student comes back often still says "not
/// active". Refetching once would slam the lock back on somebody who has just
/// paid; this waits the lag out instead.
@visibleForTesting
Future<bool> pollUntilActive({
  required Future<void> Function() refresh,
  required bool Function() active,
  int attempts = 5,
  Duration gap = const Duration(seconds: 3),
}) async {
  for (var i = 0; i < attempts; i++) {
    if (i > 0) await Future.delayed(gap);
    await refresh();
    if (active()) return true;
  }
  return false;
}

/// The card: what is wrong, and the one way out of it.
class LearningPlanCard extends StatefulWidget {
  const LearningPlanCard({super.key});

  @override
  State<LearningPlanCard> createState() => _LearningPlanCardState();
}

class _LearningPlanCardState extends State<LearningPlanCard>
    with WidgetsBindingObserver {
  bool _checking = false;

  /// A check that finished and found nothing — so the student is told why
  /// they are still looking at this, rather than tapping into silence.
  bool _stillLocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back from the browser, where the payment was made.
  ///
  /// Whether the website sends them back with a `?paid=true` of its own or
  /// they simply switch apps makes no difference here, and deliberately so: a
  /// query parameter is typed by anyone, and the answer is taken from the
  /// server every time. The link is a doorbell, never the proof.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _recheck();
  }

  Future<void> _recheck() async {
    if (_checking || !mounted) return;
    setState(() {
      _checking = true;
      _stillLocked = false;
    });

    final profiles = context.read<ProfileProvider>();
    final contents = context.read<SelectionContentProvider>();

    final active = await pollUntilActive(
      // Both, because either can carry the answer: the profile's
      // subscription block, and the course tree's own paid flag.
      refresh: () async {
        await profiles.loadProfile();
        await contents.loadContent();
      },
      active: () => !learningPlanInactive(
        profile: profiles.profile,
        content: contents.content,
      ),
    );

    if (!mounted) return;
    // Active needs nothing done to it: the providers have notified, home
    // rebuilds, and this gate is no longer among its children.
    setState(() {
      _checking = false;
      _stillLocked = !active;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(26.w, 30.h, 26.w, 22.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 62.w,
            height: 62.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColor.buttoncolor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lock_outline_rounded,
                size: 30.sp, color: AppColor.buttoncolor),
          ),
          SizedBox(height: 18.h),
          Text(
            'Your learning plan is not active',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19.sp,
              height: 1.3,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1F2418),
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            'Courses, tests and revision cards unlock with a plan. Plans are '
            'bought on our website — it opens in your browser, and your '
            'access appears here straight after.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.sp,
              height: 1.6,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 24.h),
          SizedBox(
            width: double.infinity,
            height: 52.h,
            child: ElevatedButton.icon(
              // Bought on the website, never in the app.
              onPressed: _checking ? null : () => openWebsite(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColor.buttoncolor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r)),
              ),
              icon: Icon(Icons.open_in_new_rounded, size: 18.sp),
              label: Text('Explore plans',
                  style: TextStyle(
                      fontSize: 15.sp, fontWeight: FontWeight.w700)),
            ),
          ),
          SizedBox(height: 6.h),
          if (_checking)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 11.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 14.w,
                    height: 14.w,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColor.buttoncolor),
                  ),
                  SizedBox(width: 10.w),
                  Text('Checking your payment…',
                      style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColor.buttoncolor)),
                ],
              ),
            )
          else
            TextButton(
              onPressed: _recheck,
              child: Text(
                "I've already paid — check again",
                style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColor.buttoncolor),
              ),
            ),
          // Said once a check has actually come back empty, so it cannot be
          // read as the app failing to notice a payment it never saw.
          if (_stillLocked)
            Padding(
              padding: EdgeInsets.only(bottom: 4.h),
              child: Text(
                'No plan on this account yet. A payment can take a minute to '
                'come through — or it may have been made with a different '
                'email address.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11.5.sp,
                    height: 1.5,
                    color: Colors.grey.shade600),
              ),
            ),
          // The one way past this that is not buying: signing in as somebody
          // else. Without it, the wrong account is a reinstall.
          TextButton(
            onPressed: () => context.read<AuthProvider>().signOut(),
            child: Text(
              'Sign out',
              style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }
}
