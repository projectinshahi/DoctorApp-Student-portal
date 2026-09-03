import 'package:dr_app/repository/refresh_api_provider.dart';
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

  group('the welcome hold', () {
    /// The floor is a minimum, not an addition: whatever the work already
    /// used comes off it.
    Duration remainingHold({
      required Duration workTook,
      Duration floor = const Duration(seconds: 2),
    }) =>
        workTook >= floor ? Duration.zero : floor - workTook;

    test('a fast sign-in is padded to the full two seconds', () {
      // Without this, three screens flash past in under 200ms and it reads
      // as a glitch rather than as speed.
      expect(
        remainingHold(workTook: const Duration(milliseconds: 150)),
        const Duration(milliseconds: 1850),
      );
    });

    test('a slow sign-in is never made slower', () {
      // A cold backend can take five seconds on its own. Adding two more on
      // top would punish exactly the students already waiting longest.
      expect(
        remainingHold(workTook: const Duration(seconds: 5)),
        Duration.zero,
      );
    });

    test('work that lands exactly on the floor waits no longer', () {
      expect(
        remainingHold(workTook: const Duration(seconds: 2)),
        Duration.zero,
      );
    });
  });
}
