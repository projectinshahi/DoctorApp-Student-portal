import 'package:dr_app/repository/refresh_api_provider.dart';
import 'package:dr_app/view/refresh_gate/auth_gate.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the gate must do when auth changes.
///
/// Mirrors `_AuthGateState._onAuthChanged`. The rule that was wrong is the
/// one worth pinning: the old gate re-applied the sign-out effects from a
/// post-frame callback in `build`, so any rebuild while signed out reset the
/// navigation stack again.
enum GateEffect {
  none,

  /// Stack reset only. The login screen's banner carries the reason.
  resetStackQuietly,

  /// Stack reset plus a dialog, because the student was mid-something.
  resetStackAndInterrupt,
}

GateEffect onAuthChanged({
  required AuthStatus? previous,
  required AuthStatus next,
  bool sessionWasLive = true,
  String? message,
}) {
  final wasSignedIn = previous == AuthStatus.authenticated;
  if (next != AuthStatus.unauthenticated || !wasSignedIn) {
    return GateEffect.none;
  }
  return (message != null && sessionWasLive)
      ? GateEffect.resetStackAndInterrupt
      : GateEffect.resetStackQuietly;
}

void main() {
  group('arriving', () {
    test('a fresh sign-in gets the welcome animation', () {
      expect(
        isFreshSignIn(AuthStatus.unauthenticated, AuthStatus.authenticated),
        isTrue,
      );
    });

    test('a restored session skips it — the splash has just played', () {
      // Cold start: unknown while the stored token is read, then signed in.
      // A second brand moment there is delay, not welcome.
      expect(isFreshSignIn(AuthStatus.unknown, AuthStatus.authenticated),
          isFalse);
    });

    test('a rebuild while already signed in is not a sign-in', () {
      expect(isFreshSignIn(AuthStatus.authenticated, AuthStatus.authenticated),
          isFalse);
    });

    test('signing out is not a sign-in', () {
      expect(isFreshSignIn(AuthStatus.authenticated, AuthStatus.unauthenticated),
          isFalse);
    });

    test('the welcome is held long enough to be seen', () {
      // The animation itself runs 1400ms; a shorter hold would cut it off.
      expect(AuthGate.welcomeHold.inMilliseconds, greaterThanOrEqualTo(1400));
    });
  });

  group('sign-out is an event, not a state', () {
    test('losing a live session resets the stack', () {
      expect(
        onAuthChanged(
            previous: AuthStatus.authenticated,
            next: AuthStatus.unauthenticated,
            message: 'x'),
        GateEffect.resetStackAndInterrupt,
      );
    });

    test('a session already dead at launch does not interrupt', () {
      // The cold start case: the app opens, the first request 401s, and the
      // student has touched nothing. A modal there is an interruption with
      // nothing to interrupt — the login banner says it instead.
      expect(
        onAuthChanged(
          previous: AuthStatus.authenticated,
          next: AuthStatus.unauthenticated,
          sessionWasLive: false,
          message: 'You were signed out...',
        ),
        GateEffect.resetStackQuietly,
      );
    });

    test('a live session dying does interrupt, before the login screen', () {
      // Mid-quiz, mid-video: the student needs to know why it stopped.
      expect(
        onAuthChanged(
          previous: AuthStatus.authenticated,
          next: AuthStatus.unauthenticated,
          sessionWasLive: true,
          message: 'You were signed out because your account was accessed '
              'on another device.',
        ),
        GateEffect.resetStackAndInterrupt,
      );
    });

    test('a rebuild while already signed out does nothing', () {
      // The bug in the old gate: build scheduled popUntil every time, so an
      // unrelated notifyListeners re-reset the stack under the login screen.
      expect(
        onAuthChanged(
            previous: AuthStatus.unauthenticated,
            next: AuthStatus.unauthenticated),
        GateEffect.none,
      );
    });

    test('a cold start that finds no token is not a sign-out', () {
      // unknown -> unauthenticated is the app deciding nobody is logged in.
      // Treating it as a session loss would pop a stack that does not exist
      // and show "you were signed out" to someone who never was.
      expect(
        onAuthChanged(
            previous: AuthStatus.unknown, next: AuthStatus.unauthenticated),
        GateEffect.none,
      );
    });

    test('signing in triggers nothing', () {
      expect(
        onAuthChanged(
            previous: AuthStatus.unauthenticated,
            next: AuthStatus.authenticated),
        GateEffect.none,
      );
    });

    test('the very first callback, with no previous status, is not a loss',
        () {
      expect(
        onAuthChanged(previous: null, next: AuthStatus.unauthenticated),
        GateEffect.none,
      );
    });
  });
}
