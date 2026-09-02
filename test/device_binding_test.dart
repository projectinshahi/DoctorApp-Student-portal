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
}
