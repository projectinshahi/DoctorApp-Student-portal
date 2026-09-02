import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

/// The decision the API client makes on an auth failure.
///
/// Mirrors `ApiClient._sendWithAuth`, which cannot be exercised directly
/// without a live socket. The rule is what matters and it is the rule that
/// breaks silently: refreshing on the wrong code spins forever instead of
/// telling the student anything.
enum AuthAction { pass, refreshAndRetry, endSession }

AuthAction decide(int status, String body) {
  String? code;
  try {
    final json = jsonDecode(body);
    if (json is Map && json['error'] is Map) {
      code = json['error']['code']?.toString();
    }
  } catch (_) {
    // Not JSON — a gateway page. No code, no special handling.
  }

  if (status == 403) {
    return code == 'ACCOUNT_BLOCKED' ? AuthAction.endSession : AuthAction.pass;
  }
  if (status != 401) return AuthAction.pass;

  if (code == 'SESSION_ENDED' ||
      code == 'SESSION_NOT_FOUND' ||
      code == 'REFRESH_TOKEN_REUSED') {
    return AuthAction.endSession;
  }
  return AuthAction.refreshAndRetry;
}

String _err(String code, [String message = 'x']) =>
    jsonEncode({'error': {'code': code, 'message': message}});

void main() {
  group('401 is three different things', () {
    test('an expired access token is refreshed and retried', () {
      expect(decide(401, _err('INVALID_TOKEN')), AuthAction.refreshAndRetry);
    });

    test('another device signing in ends the session, never a refresh', () {
      // /refresh answers 401 too, so refreshing here loops: the app spins and
      // the student never learns why they were signed out. This is the whole
      // reason the backend distinguishes the codes.
      expect(decide(401, _err('SESSION_ENDED')), AuthAction.endSession);
    });

    test('a replayed refresh token ends the session', () {
      expect(decide(401, _err('REFRESH_TOKEN_REUSED')), AuthAction.endSession);
    });

    test('a 401 with no readable code still tries a refresh once', () {
      // An expired token is by far the likeliest cause, and one retry that
      // fails ends the session anyway.
      expect(decide(401, '<html>gateway error</html>'),
          AuthAction.refreshAndRetry);
    });
  });

  group('403', () {
    test('a blocked account is an ending, not a permission answer', () {
      // No amount of refreshing re-enables a disabled account. Before this it
      // fell through as if it were ordinary data.
      expect(decide(403, _err('ACCOUNT_BLOCKED')), AuthAction.endSession);
    });

    test('any other 403 belongs to the caller', () {
      // A locked lesson or someone else's comment — the screen shows a
      // paywall or a message, and the session is untouched.
      expect(decide(403, _err('LESSON_LOCKED')), AuthAction.pass);
    });
  });

  test('a 200 is never an auth decision', () {
    expect(decide(200, '{"ok":true}'), AuthAction.pass);
  });

  test("the server's own message is what the student should see", () {
    const live = 'You were signed out because your account was accessed on '
        'another device.';
    final body = _err('SESSION_ENDED', live);

    // Replacing this with a generic "session expired" throws away the only
    // part that explains what happened.
    final message = jsonDecode(body)['error']['message'];
    expect(message, live);
    expect(decide(401, body), AuthAction.endSession);
  });
}
