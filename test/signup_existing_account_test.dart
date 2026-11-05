import 'package:dr_app/services/Auth_services.dart';
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
        expect(accountNeedsVerification(refusal.$1, refusal.$2), isTrue);
        expect(accountAlreadyRegistered(refusal.$1, refusal.$2), isFalse,
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
        expect(accountAlreadyRegistered(refusal.$1, refusal.$2), isTrue);
        expect(accountNeedsVerification(refusal.$1, refusal.$2), isFalse);
      });
    }
  });

  test('anything else stays on the sign-up screen with its message', () {
    // A password rule, a rate limit, a server fault: the student is already
    // where they need to be, and moving them would lose what they typed.
    expect(accountAlreadyRegistered(null, 'Password is too weak.'), isFalse);
    expect(accountNeedsVerification(null, 'Password is too weak.'), isFalse);
    expect(accountAlreadyRegistered('RATE_LIMITED', 'Try again in 5 minutes.'),
        isFalse);
  });

  group('the same rule decides both screens', () {
    // Sign-up and sign-in both end at a refusal, and both have to read it
    // the same way — the code screen for an unverified account, the
    // password form for a ready one.
    const refusal = LoginRefusedException(
      code: 'ACCOUNT_PENDING',
      message: 'Please verify your email.',
    );

    test('login sends an unverified account to the code screen', () {
      expect(refusal.needsVerification, isTrue);
      expect(refusal.alreadyRegistered, isFalse);
    });

    test('the exact code still reads as unverified', () {
      const exact = LoginRefusedException(
        code: 'EMAIL_NOT_VERIFIED',
        message: 'Verify first.',
      );

      expect(exact.isEmailNotVerified, isTrue);
      expect(exact.needsVerification, isTrue);
    });

    test('a wording the exact code misses is still caught', () {
      // What used to fall through to a dialog the student could do nothing
      // about.
      const worded = LoginRefusedException(
        code: 'FORBIDDEN',
        message: 'This account is not verified yet.',
      );

      expect(worded.isEmailNotVerified, isFalse);
      expect(worded.needsVerification, isTrue);
    });
  });
}
