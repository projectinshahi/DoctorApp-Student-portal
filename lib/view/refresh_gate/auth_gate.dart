import 'dart:async';
// lib/view/refresh_gate/auth_gate.dart
//
// Decides which of the three roots the app shows: splash, login, or home.
//
// Two jobs, deliberately kept apart:
//
//  * **build** renders the root for the current status and does nothing else.
//    It used to schedule a `popUntil` and a dialog from a post-frame callback,
//    so a stack reset ran every time the widget happened to rebuild while
//    signed out.
//
//  * **a listener** reacts to the status *changing*. Signing out is an event,
//    not a state to re-apply every frame — and the screen that has to be
//    removed is usually the one on top, so the reset goes through the app's
//    navigator key rather than this widget's context.
import 'package:dr_app/view/Home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../core/constant/local_storage.dart';
import '../../core/utils/app_navigator.dart';
import '../../widget/app_loading_screen.dart';
import '../splash/animated_splash.dart';
import '../../repository/daily_quiz_provider.dart';
import '../../repository/refresh_api_provider.dart';
import '../../repository/quiz_prefetch.dart';
import '../../repository/rapid_recall_provider.dart';
import '../../repository/notification_feed_provider.dart';
import '../../repository/plan_access_provider.dart';
import '../../repository/saved_provider.dart';
import '../../repository/settings_provider.dart';
import '../../services/notification_service.dart';
import '../../repository/selection_content_provider.dart';
import '../Authendication/login/login_screen.dart';
import '../Home/notifications/notifications_screen.dart';
import '../subjectSelection/select_exam_screen.dart';

/// A sign-in that just happened, as opposed to a session restored at launch.
///
/// Only this one gets the welcome animation: a cold start has already shown
/// the splash for two seconds, and a second brand moment there is delay.
@visibleForTesting
bool isFreshSignIn(AuthStatus? previous, AuthStatus next) =>
    next == AuthStatus.authenticated &&
    previous == AuthStatus.unauthenticated;

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  /// How long the logo animation is held after a sign-in.
  ///
  /// A floor, not a wait: the session usually resolves in a few hundred
  /// milliseconds, and without it the animation would be gone before it could
  /// be seen.
  static const Duration welcomeHold = Duration(milliseconds: 1600);

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  AuthProvider? _auth;
  AuthStatus? _lastStatus;

  /// Loaded once. A FutureBuilder given an inline future re-runs it on every
  /// rebuild, which re-read storage on each frame the picker was up.
  Future<Map<String, String?>>? _tokens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // A tapped notification comes here: this is where it is known whether
    // anyone is signed in to open anything for.
    NotificationService.instance.onOpen = _openFromNotification;
    // A push that lands while the app is open: the backend has stored it,
    // so only the badge has to move.
    NotificationService.instance.onReceived = (_) {
      if (mounted) context.read<NotificationFeedProvider>().bumpUnread();
    };

    _splashTimer = Timer(AnimatedSplash.hold, () {
      if (mounted) setState(() => _splashOver = true);
    });
  }

  /// Re-checks the session every time the app comes back to the foreground.
  ///
  /// An admin revoking a session, or blocking a student, only reaches the app
  /// on its next request — so a student sitting on the home screen would stay
  /// there indefinitely. Resuming is the cheapest honest moment to notice:
  /// the call goes through ApiClient, so a 401 or 403 takes the normal path
  /// and signs them out.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_auth?.status != AuthStatus.authenticated) return;
    if (!mounted) return;

    // /users/me/home is small, already cached by the home screen, and starts
    // nothing — unlike the daily-quiz endpoint beside it.
    context.read<HomeSummaryProvider>().load();

    // And the course tree, because it carries whether the plan is still
    // active: a subscription that lapsed while the app was in the background
    // has to close the content on the next look, not on the next sign-in.
    context.read<SelectionContentProvider>().loadContent();

    // And the plan, which carries the days left and which tabs are locked. A
    // renewal bought in the browser lands here on the way back, so the
    // countdown is not still reading "ends tomorrow" the morning after.
    context.read<PlanAccessProvider>().load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final auth = context.read<AuthProvider>();
    if (identical(auth, _auth)) return;

    _auth?.removeListener(_onAuthChanged);
    _auth = auth..addListener(_onAuthChanged);
    _lastStatus = auth.status;
  }

  @override
  void dispose() {
    // Outlives a frame, so it has to go or it fires setState on a gate that
    // is gone.
    _splashTimer?.cancel();
    _welcomeTimer?.cancel();
    NotificationService.instance.onOpen = null;
    NotificationService.instance.onReceived = null;
    WidgetsBinding.instance.removeObserver(this);
    _auth?.removeListener(_onAuthChanged);
    super.dispose();
  }

  /// The splash has had its two seconds.
  ///
  /// A floor on the very first screen, not a wait on anything: the session
  /// and the cached course restore in milliseconds, so without this the
  /// splash was gone before it could be seen.
  bool _splashOver = false;
  Timer? _splashTimer;

  bool _welcoming = false;
  Timer? _welcomeTimer;

  /// The notification permission and the device token, once per session.
  bool _settingsApplied = false;

  bool _warmedUp = false;

  /// Pulls the app's content once, as soon as there is a session.
  ///
  /// Screens restore from disk instantly, so this is about what lands in that
  /// store for next time and about being fresh before the student navigates —
  /// rather than each screen discovering it needs data at the moment it is
  /// opened, which is what put a spinner in front of every tap.
  ///
  /// One at a time. The backend is a single instance and measured 3-5s per
  /// call when cold; firing these together would make the home screen — the
  /// one thing the student is actually looking at — the slowest of the three.
  ///
  /// Deliberately NOT the daily quiz: fetchToday *creates* the attempt, and
  /// preloading it would end the day with an unfinished quiz and a broken
  /// streak for a student who only opened the app.
  void _warmUp() {
    if (_warmedUp) return;
    _warmedUp = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final navigatorContext = navigatorKey.currentContext;
      if (navigatorContext == null || !mounted) return;

      // The notification permission and the study reminder, now that there
      // is a signed-in student to ask on behalf of. Asked at launch, before
      // sign-in, the prompt has no context and gets refused.
      // The notification permission, now that home is on screen.
      _applySettingsForSession();

      // The bell's number, for a student who was sent something while they
      // were away.
      unawaited(navigatorContext.read<NotificationFeedProvider>().load());

      final pending = NotificationService.instance.takePendingOpen();
      if (pending != null) unawaited(_openFromNotification(pending));

      try {
        await navigatorContext.read<SelectionContentProvider>().loadContent();
        if (!mounted) return;
        await navigatorContext.read<HomeSummaryProvider>().load();
        if (!mounted) return;
        await navigatorContext.read<SavedProvider>().ensureLoaded();
      } catch (_) {
        // Warming is an optimisation. Every screen still loads on its own.
      }
    });
  }

  /// Where a tapped notification goes: the Notifications screen, with the
  /// one that was tapped at the top of it.
  ///
  /// The screen is where a student looks for what arrived, and the alert's
  /// own row still opens what it names — home when it is about the course
  /// they already have, the picker when it is about another.
  Future<void> _openFromNotification(Map<String, dynamic> data) async {
    if (_auth?.status != AuthStatus.authenticated) {
      // Tapped before the session was restored. _warmUp picks it up.
      NotificationService.instance.pendingOpen = data;
      return;
    }

    final navigatorContext = navigatorKey.currentContext;
    if (navigatorContext != null) {
      await NotificationsScreen.open(navigatorContext);
    }
  }

  /// Holds the logo animation for [welcomeHold] after a sign-in.
  void _startWelcome() {
    _welcomeTimer?.cancel();
    setState(() => _welcoming = true);
    _welcomeTimer = Timer(AuthGate.welcomeHold, () {
      if (mounted) setState(() => _welcoming = false);
    });
  }

  /// Asks for the notification permission and registers this device.
  ///
  /// From _warmUp, which runs after home's first frame — so the student sees
  /// where they have landed before a system dialog appears over it.
  void _applySettingsForSession() {
    if (_settingsApplied) return;
    _settingsApplied = true;

    final settings = context.read<SettingsProvider>();
    unawaited(AuthProvider.currentStudentId()
        .then((studentId) => settings.applyForSession(studentId: studentId)));
  }

  void _onAuthChanged() {
    final auth = _auth;
    if (auth == null || !mounted) return;

    final status = auth.status;
    final previous = _lastStatus;
    final wasSignedIn = previous == AuthStatus.authenticated;
    _lastStatus = status;

    if (isFreshSignIn(previous, status)) _startWelcome();

    // A sign-in that displaced another device. Shown from here rather than
    // from the login screen, because that screen is being replaced by this
    // very state change — its context dies with it.
    final notice = auth.signInNotice;
    if (notice != null && status == AuthStatus.authenticated) {
      auth.clearSignInNotice();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final navigatorContext = navigatorKey.currentContext;
        if (navigatorContext != null) _showNotice(navigatorContext, notice);
      });
      return;
    }

    // Only the transition out of a signed-in state, and only once.
    if (status != AuthStatus.unauthenticated || !wasSignedIn) return;

    // Every cached list belongs to the account that just left. Now that
    // screens show what they have before refetching, the next account would
    // open on the previous one's bookmarks and course tree until the fetch
    // lands. Done here rather than in the logout button because a session
    // also ends from another device signing in and from an account being
    // blocked — all three arrive as this one transition.
    _warmedUp = false;
    _settingsApplied = false;
    _welcomeTimer?.cancel();
    _welcoming = false;
    context.read<SavedProvider>().clear();
    context.read<SelectionContentProvider>().invalidate();
    // Warmed attempts belong to the account that just left; opening one on
    // the next account would show the wrong student's answers.
    context.read<QuizPrefetch>().clear();
    // Decks and their bookmarks belong to that account's course too.
    context.read<RapidRecallProvider>().clear();
    // Course alerts and the study reminder are for a signed-in student.
    unawaited(context.read<SettingsProvider>().clearForSignOut());
    // The list belongs to the account that just left.
    context.read<NotificationFeedProvider>().clear();
    // The plan belongs to that account too.
    context.read<PlanAccessProvider>().clear();

    // The session can die while a quiz, a test paper or the player is on
    // top. Swapping this root does not remove those, and without the reset
    // the student sits on a dead screen whose back button walks them out of
    // the app.
    navigatorKey.currentState?.popUntil((route) => route.isFirst);

    // The message is deliberately not cleared: the login screen keeps it
    // above the sign-in button either way, so the reason is still there
    // after the dialog is dismissed.
    final message = auth.sessionMessage;

    // Only interrupt when the session was actually in use. A cold start with
    // an already-dead token never completed a request, so the student is
    // taken quietly to the login screen and reads the banner there.
    if (message == null || !auth.sessionWasLive) return;
    auth.markSessionEndShown();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigatorContext = navigatorKey.currentContext;
      if (navigatorContext != null) _showSessionEnded(navigatorContext, message);
    });
  }

  /// Shown before the login screen is reached, so the student learns why they
  /// were interrupted rather than finding themselves back at sign-in with no
  /// explanation.
  void _showSessionEnded(BuildContext context, String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFFEFF4E2),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.devices_other_rounded,
            size: 34, color: Color(0xFF87986B)),
        title: Text('Signed out',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800)),
        // The server's wording, unchanged.
        content: Text(message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5.sp, height: 1.45)),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF87986B),
              foregroundColor: Colors.white,
              elevation: 0,
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
            ),
            child: const Text('Sign in again',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  /// The server's sentence, verbatim. Composing our own from
  /// `signedOutOtherDevice` would drift from what actually happened.
  void _showNotice(BuildContext context, String notice) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFFEFF4E2),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.devices_other_rounded,
            size: 32, color: Color(0xFF87986B)),
        content: Text(notice,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5.sp, height: 1.45)),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF87986B),
              foregroundColor: Colors.white,
              elevation: 0,
              padding:
                  const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
            ),
            child:
                const Text('OK', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Before the switch, so it covers every branch. Signing in and being
    // signed out both resolve fast enough to flash past otherwise.
    if (!_splashOver) return const AnimatedSplash();

    final auth = context.watch<AuthProvider>();

    return switch (auth.status) {
      AuthStatus.unauthenticated => const LoginScreen(),
      // Reading the stored token. Brief, but it is the very first frame and
      // an empty screen there reads as a crash.
      AuthStatus.unknown => const AnimatedSplash(),
      AuthStatus.authenticated => _authenticated(auth),
    };
  }

  Widget _authenticated(AuthProvider auth) {
    // Held for a moment after a sign-in is accepted, so the student sees one
    // steady screen instead of three flashing past. The work happens during
    // it, not after.
    // The logo's animation as a moment after signing in, held long enough to
    // be seen. The notification prompt comes up over it, so home is the first
    // thing the student reaches after both.
    if (_welcoming || auth.isSigningIn) {
      return const AnimatedSplash(message: 'Signing you in…');
    }

    // Still asking the server whether this account has a course. Showing the
    // picker here would flash it at a student who chose months ago.
    //
    // This is the wait right after signing in, and the longest one in the
    // app — a cold Render instance can take several seconds. Naming it beats
    // a bare spinner: the student knows the app is working, not stuck.
    if (auth.isResolvingSelection) {
      return const AppLoadingScreen(message: 'Loading your course…');
    }

    if (auth.hasSelectedExam) {
      _warmUp();
      return const Homescreen();
    }

    _tokens ??= _loadTokensForExamSelection();
    return FutureBuilder<Map<String, String?>>(
      future: _tokens,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const AppLoadingScreen(message: 'Loading your course…');
        }
        final data = snapshot.data!;
        return ExamSelectionScreen(
          accessToken: data['accessToken'] ?? '',
          refreshToken: data['refreshToken'] ?? '',
          deviceId: data['deviceId'] ?? '',
        );
      },
    );
  }

  Future<Map<String, String?>> _loadTokensForExamSelection() async => {
        'accessToken': await LocalStorage.getAccessToken(),
        'refreshToken': await LocalStorage.getRefreshToken(),
        'deviceId': await LocalStorage.getDeviceId(),
      };
}
