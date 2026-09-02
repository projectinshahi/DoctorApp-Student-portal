import 'package:dr_app/repository/refresh_api_provider.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the gate must do when auth changes.
///
/// Mirrors `_AuthGateState._onAuthChanged`. The rule that was wrong is the
/// one worth pinning: the old gate re-applied the sign-out effects from a
/// post-frame callback in `build`, so any rebuild while signed out reset the
/// navigation stack again.
enum GateEffect { none, resetStackAndWarn }

GateEffect onAuthChanged({
  required AuthStatus? previous,
  required AuthStatus next,
}) {
  final wasSignedIn = previous == AuthStatus.authenticated;
  if (next != AuthStatus.unauthenticated || !wasSignedIn) {
    return GateEffect.none;
  }
  return GateEffect.resetStackAndWarn;
}

void main() {
  group('sign-out is an event, not a state', () {
    test('losing a live session resets the stack', () {
      expect(
        onAuthChanged(
            previous: AuthStatus.authenticated,
            next: AuthStatus.unauthenticated),
        GateEffect.resetStackAndWarn,
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
