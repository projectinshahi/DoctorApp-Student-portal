import 'package:dr_app/view/Authendication/login/sign-up_screen.dart';
import 'package:flutter_test/flutter_test.dart';

/// Where a refused sign-up goes.
///
/// The two endings are very different — a code to type, or a password to
/// remember — so the verdict is read from what the server said, never
/// guessed. Both are matched on the code where one is sent, and on the words
/// otherwise.
void main() {
  group('an account that exists but was never verified', () {
    for (final refusal in [
      ('EMAIL_PENDING_VERIFICATION', 'Account exists.'),
      ('OTP_REQUIRED', 'Check your email.'),
      (null, 'This account is not verified yet.'),
      (null, 'Please verify your email to continue.'),
    ]) {
      test('${refusal.$1 ?? refusal.$2} goes to the code screen', () {
        expect(needsVerification(refusal.$1, refusal.$2), isTrue);
        expect(alreadyRegistered(refusal.$1, refusal.$2), isFalse,
            reason: 'it must not be sent to the password form');
      });
    }
  });

  group('an account that exists and is ready', () {
    for (final refusal in [
      ('EMAIL_EXISTS', 'Email taken.'),
      ('DUPLICATE_EMAIL', 'Taken.'),
      (null, 'An account with this email already exists.'),
    ]) {
      test('${refusal.$1 ?? refusal.$2} goes to the login form', () {
        expect(alreadyRegistered(refusal.$1, refusal.$2), isTrue);
        expect(needsVerification(refusal.$1, refusal.$2), isFalse);
      });
    }
  });

  test('anything else stays on the sign-up screen with its message', () {
    // A password rule, a rate limit, a server fault: the student is already
    // where they need to be, and moving them would lose what they typed.
    expect(alreadyRegistered(null, 'Password is too weak.'), isFalse);
    expect(needsVerification(null, 'Password is too weak.'), isFalse);
    expect(alreadyRegistered('RATE_LIMITED', 'Try again in 5 minutes.'),
        isFalse);
  });
}
