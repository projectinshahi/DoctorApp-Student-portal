import 'package:dr_app/services/refresh_api_services.dart';
import 'package:flutter_test/flutter_test.dart';

/// What a student reads when the app signs them out.
///
/// The server sends one sentence for five different causes and it names
/// another device, so a student who logged out themselves was told something
/// untrue. These assert the app no longer repeats that guess.
void main() {
  test('a session that ran out says so, and blames nobody', () {
    expect(ApiClient.timedOutMessage, contains('timed out'));
    expect(ApiClient.timedOutMessage, isNot(contains('another device')));
  });

  test('an ended session says only what is certain', () {
    final message = ApiClient.signedOutMessage('SESSION_ENDED');

    expect(message, 'You have been signed out. Please sign in again.');
    expect(message, isNot(contains('another device')));
  });

  test('a deleted account is named for what it is', () {
    expect(ApiClient.signedOutMessage('USER_NOT_FOUND'),
        'This account is no longer available.');
  });
}
