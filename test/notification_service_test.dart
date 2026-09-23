import 'dart:convert';

import 'package:dr_app/repository/refresh_api_provider.dart';
import 'package:dr_app/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// A JWT with [claims] as its payload. Unsigned — the app only reads it.
String _jwt(Map<String, Object?> claims) {
  String part(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part(claims)}.signature';
}

void main() {
  group('the student id comes from the access token', () {
    test('reads the userId claim', () {
      expect(AuthProvider.userIdFromToken(_jwt({'userId': 41, 'sessionId': 9})),
          41);
    });

    test('a string id is read as a number', () {
      expect(AuthProvider.userIdFromToken(_jwt({'userId': '41'})), 41);
    });

    test('no token, a broken token, or no claim: null, never a throw', () {
      expect(AuthProvider.userIdFromToken(null), isNull);
      expect(AuthProvider.userIdFromToken('not-a-jwt'), isNull);
      expect(AuthProvider.userIdFromToken('a.%%%.c'), isNull);
      expect(AuthProvider.userIdFromToken(_jwt({'sessionId': 9})), isNull);
    });
  });

  group('tapped notifications', () {
    test('a course_join carries its course id, sent as a string', () {
      final data = {'type': 'course_join', 'courseId': '22'};
      expect(NotificationService.courseIdFrom(data), 22);
    });

    test('a missing or broken course id is null, not a crash', () {
      expect(NotificationService.courseIdFrom({'type': 'course_join'}), isNull);
      expect(NotificationService.courseIdFrom({'courseId': 'abc'}), isNull);
      expect(NotificationService.courseIdFrom({'courseId': 7}), 7);
    });

    test('a foreground notification keeps its whole data map through a tap',
        () {
      // Shown by hand while the app is open, so the payload has to bring the
      // course id along — a bare type would lose it.
      final payload = jsonEncode({'type': 'course_join', 'courseId': '22'});
      final data = NotificationService.decodePayload(payload)!;
      expect(data['type'], 'course_join');
      expect(NotificationService.courseIdFrom(data), 22);
    });

    test('a plain-string payload from an earlier build still opens', () {
      expect(NotificationService.decodePayload('study_reminder'),
          {'type': 'study_reminder'});
      expect(NotificationService.decodePayload(null), isNull);
      expect(NotificationService.decodePayload(''), isNull);
    });
  });

  test('the token goes to the endpoint the backend exposes', () {
    expect(
      NotificationService.tokenUrl,
      'https://doctorapp-backend-cl2h.onrender.com/api/users/me/fcm-token',
    );
    // No id in the path: the server reads the student from the access token,
    // and an id there would let a phone be registered against another
    // student's account.
    expect(NotificationService.tokenUrl, isNot(contains('students')));
  });
}
