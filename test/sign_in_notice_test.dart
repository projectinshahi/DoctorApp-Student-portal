import 'package:dr_app/View_model/auth_result_model.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _response({
  bool isNewUser = false,
  bool signedOutOtherDevice = false,
  String? notice,
  Map<String, dynamic>? previousSession,
}) =>
    {
      'accessToken': 'a',
      'refreshToken': 'r',
      'sessionId': 82,
      'isNewUser': isNewUser,
      'signedOutOtherDevice': signedOutOtherDevice,
      'notice': notice,
      'previousSession': previousSession,
      'user': {
        'id': 35,
        'email': 'x@y.com',
        'name': 'Keerthana',
        'role': 'student',
      },
    };

const _live = "You've been signed out on your other device. Only one device "
    'can be signed in at a time.';

void main() {
  group('the three sign-in cases, as verified live', () {
    test('a brand new account gets no notice', () {
      final result = AuthResultModel.fromJson(_response(isNewUser: true));

      expect(result.isNewUser, isTrue);
      expect(result.notice, isNull);
      // Nothing was displaced, so there is no previous session to report.
      expect(result.previousSession, isNull);
    });

    test('the same device signing in again gets no notice', () {
      final result = AuthResultModel.fromJson(_response(
        signedOutOtherDevice: false,
        notice: null,
        previousSession: {'deviceId': 'PHONE-A', 'sameDevice': true},
      ));

      // The case the flag exists for. Re-signing in on the phone in your
      // hand happens constantly; alerting there would tell a student they
      // were kicked off the device they are holding.
      expect(result.notice, isNull);
      expect(result.previousSession!.sameDevice, isTrue);
      expect(result.signedOutOtherDevice, isFalse);
    });

    test('a different device signing in gets the sentence', () {
      final result = AuthResultModel.fromJson(_response(
        signedOutOtherDevice: true,
        notice: _live,
        previousSession: {'deviceId': 'PHONE-A', 'sameDevice': false},
      ));

      expect(result.signedOutOtherDevice, isTrue);
      expect(result.previousSession!.sameDevice, isFalse);
      // Verbatim. Composing our own from the flag would drift from what the
      // server actually did.
      expect(result.notice, _live);
    });
  });

  group('notice hygiene', () {
    test('an empty string is not a notice', () {
      // Rendering "" would open a dialog with nothing in it.
      expect(AuthResultModel.fromJson(_response(notice: '')).notice, isNull);
    });

    test('a missing field is not a notice', () {
      final json = _response()..remove('notice');
      expect(AuthResultModel.fromJson(json).notice, isNull);
    });

    test('the notice is never derived from signedOutOtherDevice', () {
      // A flag set with no sentence must still show nothing — the server
      // decides the wording, including when there is none.
      final result = AuthResultModel.fromJson(
          _response(signedOutOtherDevice: true, notice: null));

      expect(result.signedOutOtherDevice, isTrue);
      expect(result.notice, isNull);
    });
  });

  test('sign-up and sign-in are the same call, told apart by isNewUser', () {
    // There is no separate registration endpoint. isNewUser is what routes a
    // new account to the course picker, since it has no selectedCourseId and
    // /home would return empty modules.
    expect(AuthResultModel.fromJson(_response(isNewUser: true)).isNewUser,
        isTrue);
    expect(AuthResultModel.fromJson(_response()).isNewUser, isFalse);
  });

  test('the session id survives, for support to match against', () {
    expect(AuthResultModel.fromJson(_response()).sessionId, 82);
  });
}
