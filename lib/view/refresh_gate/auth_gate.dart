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
import 'package:provider/provider.dart';

import '../../core/constant/local_storage.dart';
import '../../core/utils/app_navigator.dart';
import '../../repository/refresh_api_provider.dart';
import '../Authendication/login/login_screen.dart';
import '../splash/splash_screen.dart';
import '../subjectSelection/select_exam_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  AuthProvider? _auth;
  AuthStatus? _lastStatus;

  /// Loaded once. A FutureBuilder given an inline future re-runs it on every
  /// rebuild, which re-read storage on each frame the picker was up.
  Future<Map<String, String?>>? _tokens;

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
    _auth?.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    final auth = _auth;
    if (auth == null || !mounted) return;

    final status = auth.status;
    final wasSignedIn = _lastStatus == AuthStatus.authenticated;
    _lastStatus = status;

    // Only the transition out of a signed-in state, and only once.
    if (status != AuthStatus.unauthenticated || !wasSignedIn) return;

    // The session can die while a quiz, a test paper or the player is on
    // top. Swapping this root does not remove those, and without the reset
    // the student sits on a dead screen whose back button walks them out of
    // the app.
    navigatorKey.currentState?.popUntil((route) => route.isFirst);

    // The message is dropped, not shown.
    //
    // A dialog here fired on every cold start with a dead session — the app
    // opens, the first request 401s, and the student is met by "Signed out"
    // before they have touched anything. Landing on the login screen already
    // says it. Clearing the message stops it queueing up for later.
    auth.clearSessionMessage();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return switch (auth.status) {
      AuthStatus.unauthenticated => const LoginScreen(),
      AuthStatus.unknown => const SplashScreen(),
      AuthStatus.authenticated => _authenticated(auth),
    };
  }

  Widget _authenticated(AuthProvider auth) {
    // Still asking the server whether this account has a course. Showing the
    // picker here would flash it at a student who chose months ago.
    if (auth.isResolvingSelection) return const SplashScreen();

    if (auth.hasSelectedExam) return const Homescreen();

    _tokens ??= _loadTokensForExamSelection();
    return FutureBuilder<Map<String, String?>>(
      future: _tokens,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SplashScreen();
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
