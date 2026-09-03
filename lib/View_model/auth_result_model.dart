class AuthResultModel {
  final String accessToken;
  final String refreshToken;
  final int? sessionId;

  /// True when this call created the account. Sign-up and sign-in are the
  /// same endpoint — there is no separate registration call — so this is the
  /// only thing that tells them apart.
  ///
  /// A new account has no selected course, so it goes to the picker rather
  /// than the home screen, which would otherwise render empty.
  final bool isNewUser;

  /// True when signing in here ended a session on a *different* device.
  ///
  /// Not used to compose a message — see [notice]. It is here because the
  /// same-device case is deliberately excluded: re-signing in on the phone
  /// in your hand happens constantly, and alerting there would tell a
  /// student they were kicked off the device they are holding.
  final bool signedOutOtherDevice;

  /// The server's own sentence, or null when there is nothing to say.
  ///
  /// Shown **verbatim**. Composing our own from [signedOutOtherDevice] would
  /// drift from what the server actually did, and it is null on a brand new
  /// account and on a same-device re-login.
  final String? notice;

  /// The session this sign-in replaced. Null on a new account.
  final PreviousSession? previousSession;

  final UserModel user;

  AuthResultModel({
    required this.accessToken,
    required this.refreshToken,
    this.sessionId,
    required this.isNewUser,
    this.signedOutOtherDevice = false,
    this.notice,
    this.previousSession,
    required this.user,
  });

  factory AuthResultModel.fromJson(Map<String, dynamic> json) {
    final notice = json['notice']?.toString();

    return AuthResultModel(
      accessToken: json['accessToken'],
      refreshToken: json['refreshToken'],
      sessionId: json['sessionId'] is int
          ? json['sessionId'] as int
          : int.tryParse('${json['sessionId'] ?? ''}'),
      isNewUser: json['isNewUser'] ?? false,
      signedOutOtherDevice: json['signedOutOtherDevice'] == true,
      // An empty string is not a notice.
      notice: (notice == null || notice.isEmpty) ? null : notice,
      previousSession: json['previousSession'] is Map
          ? PreviousSession.fromJson(
              Map<String, dynamic>.from(json['previousSession'] as Map))
          : null,
      user: UserModel.fromJson(json['user']),
    );
  }
}

/// What was signed out to make room for this session.
class PreviousSession {
  final String? deviceId;
  final DateTime? signedInAt;

  /// True when the previous session was on this same phone. The server uses
  /// it to decide whether a notice is warranted at all.
  final bool sameDevice;

  PreviousSession({
    this.deviceId,
    this.signedInAt,
    required this.sameDevice,
  });

  factory PreviousSession.fromJson(Map<String, dynamic> json) =>
      PreviousSession(
        deviceId: json['deviceId']?.toString(),
        signedInAt: json['signedInAt'] == null
            ? null
            : DateTime.tryParse(json['signedInAt'].toString()),
        sameDevice: json['sameDevice'] == true,
      );
}

class UserModel {
  final int id;
  final String email;
  final String? name;
  final String role;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      email: json['email'],
      name: json['name'],
      role: json['role'],
    );
  }
}
