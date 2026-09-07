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
import '../../repository/daily_quiz_provider.dart';
import '../../repository/refresh_api_provider.dart';
import '../../repository/saved_provider.dart';
import '../../repository/selection_content_provider.dart';
import '../Authendication/login/login_screen.dart';
import '../subjectSelection/select_exam_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

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
    WidgetsBinding.instance.removeObserver(this);
    _auth?.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    final auth = _auth;
    if (auth == null || !mounted) return;

    final status = auth.status;
    final wasSignedIn = _lastStatus == AuthStatus.authenticated;
    _lastStatus = status;

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
    context.read<SavedProvider>().clear();
    context.read<SelectionContentProvider>().invalidate();

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
    final auth = context.watch<AuthProvider>();

    return switch (auth.status) {
      AuthStatus.unauthenticated => const LoginScreen(),
      // Reading the stored token. Brief, but it is the very first frame and
      // an empty screen there reads as a crash.
      AuthStatus.unknown =>
        const AppLoadingScreen(message: 'Starting up…'),
      AuthStatus.authenticated => _authenticated(auth),
    };
  }

  Widget _authenticated(AuthProvider auth) {
    // Held for a moment after a sign-in is accepted, so the student sees one
    // steady screen instead of three flashing past. The work happens during
    // it, not after.
    if (auth.isSigningIn) {
      return const AppLoadingScreen(message: 'Signing you in…');
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

    if (auth.hasSelectedExam) return const Homescreen();

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
