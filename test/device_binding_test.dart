import 'package:dr_app/services/Auth_services.dart' show LoginRefusedException;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('a refused login keeps its reason', () {
    test('DEVICE_BOUND is the subscription-sharing case', () {
      const refused = LoginRefusedException(
        code: 'DEVICE_BOUND',
        message: 'This device is registered to another account.',
      );

      // Nothing to retry: the student needs support, not a second tap. If
      // this ever reads as a generic failure they will sit there tapping.
      expect(refused.isDeviceBound, isTrue);
      expect(refused.isAccountBlocked, isFalse);
      expect(refused.message, contains('another account'));
    });

    test('ACCOUNT_BLOCKED is a different conversation', () {
      const refused = LoginRefusedException(
        code: 'ACCOUNT_BLOCKED',
        message: 'This account has been disabled.',
      );

      expect(refused.isAccountBlocked, isTrue);
      expect(refused.isDeviceBound, isFalse);
    });

    test('an unknown or missing code still carries a message', () {
      // A gateway page or a code the app has never seen must not crash the
      // login screen — it falls back to the generic dialog.
      const refused = LoginRefusedException(
        code: null,
        message: 'Could not sign in. Please try again.',
      );

      expect(refused.isDeviceBound, isFalse);
      expect(refused.isAccountBlocked, isFalse);
      expect(refused.message, isNotEmpty);
    });

    test('the code is what decides, not the wording', () {
      // Matching on message text would break the moment the server rephrases
      // it, or ships another language.
      const reworded = LoginRefusedException(
        code: 'DEVICE_BOUND',
        message: 'Hierdie toestel is aan \'n ander rekening gekoppel.',
      );
      expect(reworded.isDeviceBound, isTrue);
    });
  });

  group('SESSION_ACTIVE_ELSEWHERE — the new policy', () {
    test('the second device is refused, and told how long', () {
      const refused = LoginRefusedException(
        code: 'SESSION_ACTIVE_ELSEWHERE',
        message: 'This account is signed in on another device. Sign out there '
            'first, or try again in a few minutes.',
        retryAfterMinutes: 30,
      );

      // The policy flipped: the account holder keeps their session and the
      // newcomer waits, instead of the first device being kicked off.
      expect(refused.isSessionActiveElsewhere, isTrue);
      expect(refused.retryAfterMinutes, 30);

      // Not one of the others — each needs different words.
      expect(refused.isAccountBlocked, isFalse);
      expect(refused.isDeviceBound, isFalse);
    });

    test('a refusal without a window still explains itself', () {
      // retryAfterMinutes is optional; the dialog falls back to "sign out on
      // your other device" rather than printing "null minutes".
      const refused = LoginRefusedException(
        code: 'SESSION_ACTIVE_ELSEWHERE',
        message: 'This account is signed in on another device.',
      );

      expect(refused.isSessionActiveElsewhere, isTrue);
      expect(refused.retryAfterMinutes, isNull);
    });

    test('the code decides, not the wording', () {
      // The server may rephrase or translate the sentence at any time.
      const reworded = LoginRefusedException(
        code: 'SESSION_ACTIVE_ELSEWHERE',
        message: 'Hierdie rekening is op \'n ander toestel aangeteken.',
        retryAfterMinutes: 15,
      );
      expect(reworded.isSessionActiveElsewhere, isTrue);
      expect(reworded.retryAfterMinutes, 15);
    });
  });
}
