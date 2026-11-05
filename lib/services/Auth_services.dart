import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../../core/constant/api_constant.dart';
import '../../../../core/utils/device_id_helper.dart';
import '../View_model/auth_result_model.dart';
import '../core/constant/local_storage.dart';

class AuthService {
  AuthService();

  /// The iOS OAuth client, from Google Cloud Console → Credentials, created
  /// against the bundle id `com.keerthana.drApp`.
  ///
  /// iOS needs its own client — Android's does not work, and there is no
  /// GoogleService-Info.plist in this project to read one from. Passing it
  /// here rather than as `GIDClientID` in Info.plist is deliberate: with a
  /// clientId present the plugin builds a real GIDConfiguration and applies
  /// [_serverClientId] with it. Configure through Info.plist alone and the
  /// serverClientId below is silently dropped on iOS.
  ///
  /// Its reverse also has to be registered as a URL scheme in
  /// ios/Runner/Info.plist, or the OAuth redirect cannot get back into the
  /// app.
  static const String _iosClientId =
      '125167391971-fp3tvkdoq4asja9jgs02k9o27dks2jse.apps.googleusercontent.com';

  /// The backend's own client. The id token the app posts to /auth/google
  /// carries this as its audience, which is what the server verifies.
  static const String _serverClientId =
      '125167391971-djufjjsm3gp8vms4id65rdb3bg72hciv.apps.googleusercontent.com';

  static bool get _isIosUnconfigured => Platform.isIOS && _iosClientId.isEmpty;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
      'openid',
    ],
    clientId: Platform.isIOS && _iosClientId.isNotEmpty ? _iosClientId : null,
    serverClientId: _serverClientId,
  );

  Future<AuthResultModel> signInWithGoogle() async {
    // Checked before the call, not caught after it. With no client id
    // GIDSignIn raises an Objective-C exception from signInWithOptions:,
    // which is not a Dart error — it aborts the process, so the app vanishes
    // instead of showing anything. A thrown Exception here is catchable.
    if (_isIosUnconfigured) {
      throw Exception(
        'Google sign-in is not set up for iOS yet. Use email sign-in, or add '
        'the iOS OAuth client id to AuthService._iosClientId.',
      );
    }

    try {


      // Optional: clear previous Google session
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleUser =
      await _googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception("User cancelled Google Sign-In");
      }



      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      final String? idToken = googleAuth.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw Exception("Google ID Token is null");
      }

      return await _signInToBackend(ApiConstant.googleSignIn, {"idToken": idToken});
    } catch (e) {
      if (kDebugMode) debugPrint('Google sign-in failed: $e');
      rethrow;
    }
  }

  /// The Services ID from the Apple portal. Android has no native Apple
  /// sign-in, so it signs in on Apple's web page as this "service", and Apple
  /// posts the result to the backend, which hands it back to the app.
  static const String _appleServiceId = 'com.keerthana.drApp.signin';

  /// Native sheet on iPhone; Apple's web page on Android.
  Future<AuthResultModel> signInWithApple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: Platform.isAndroid
            ? WebAuthenticationOptions(
                clientId: _appleServiceId,
                redirectUri: Uri.parse(ApiConstant.appleCallback),
              )
            : null,
      );

      final idToken = credential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception("Apple ID Token is null");
      }

      // Apple hands over the name on the very first sign-in only, and never
      // puts it in the token, so it travels beside it.
      final name = [credential.givenName, credential.familyName]
          .whereType<String>()
          .join(' ')
          .trim();

      return await _signInToBackend(ApiConstant.appleSignIn, {
        "idToken": idToken,
        if (name.isNotEmpty) "name": name,
      });
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw Exception("User cancelled Apple Sign-In");
      }
      if (kDebugMode) debugPrint('Apple sign-in failed: $e');
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint('Apple sign-in failed: $e');
      rethrow;
    }
  }

  /// Posts a provider's id token to the backend. The reply is the same for
  /// Google and Apple: tokens on 200, a typed refusal otherwise.
  Future<AuthResultModel> _signInToBackend(
    String url,
    Map<String, dynamic> payload,
  ) async {
    final String deviceId = await DeviceIdHelper.getDeviceId();

    final response = await http.post(
      Uri.parse(url),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({...payload, "deviceId": deviceId}),
    );

    // Never the body: it carries the access and refresh tokens, and
    // print() reaches logcat in release builds too, where any app with log
    // access could read them. The status alone is enough to debug with.
    if (kDebugMode) debugPrint('AUTH  POST [${response.statusCode}]  $url');

    if (response.statusCode == 200) {
      final AuthResultModel authResult =
      AuthResultModel.fromJson(jsonDecode(response.body));

      // Save Tokens
      await LocalStorage.saveAccessToken(authResult.accessToken);
      await LocalStorage.saveRefreshToken(authResult.refreshToken);



      return authResult;
    }

    throw _refusalFrom(response, "Could not sign in. Please try again.");
  }

  /// Creates an unverified account. The server emails a 6-digit code, which
  /// [verifyOtp] then exchanges for a session.
  Future<void> registerWithEmail(String email, String password) async {
    final response = await http.post(
      Uri.parse(ApiConstant.register),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );
    if (kDebugMode) debugPrint('AUTH  POST [${response.statusCode}]  register');
    if (response.statusCode != 201) {
      throw _refusalFrom(response, "Could not create the account. Please try again.");
    }
  }

  Future<AuthResultModel> loginWithEmail(String email, String password) =>
      _signInToBackend(ApiConstant.login, {"email": email, "password": password});

  /// The right code verifies the account and signs in, like a login.
  Future<AuthResultModel> verifyOtp(String email, String code) =>
      _signInToBackend(ApiConstant.verifyOtp, {"email": email, "code": code});

  /// Emails a code for [resetPassword]. A Google account has no password,
  /// so this is also how it adds one.
  Future<void> forgotPassword(String email) => _postQuietly(ApiConstant.forgotPassword, email);

  /// The right code sets the new password and signs in, like a login.
  Future<AuthResultModel> resetPassword(String email, String code, String password) =>
      _signInToBackend(ApiConstant.resetPassword,
          {"email": email, "code": code, "password": password});

  /// The server answers the same whether or not it sent one, and ignores a
  /// second request inside a minute, so there is nothing to report back.
  Future<void> resendOtp(String email) => _postQuietly(ApiConstant.resendOtp, email);

  Future<void> _postQuietly(String url, String email) async {
    try {
      await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email}),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('POST $url failed: $e');
    }
  }

  /// The server refuses for reasons the student can act on, and each needs
  /// its own words. A raw Exception here surfaced as "Exception: ..." on the
  /// login screen.
  LoginRefusedException _refusalFrom(http.Response response, String fallback) {
    Map<String, dynamic> body = const {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) body = Map<String, dynamic>.from(decoded);
    } catch (_) {
      // A gateway page is not JSON. The fallback message covers it.
    }
    final error = body["error"] is Map
        ? Map<String, dynamic>.from(body["error"] as Map)
        : const <String, dynamic>{};

    // retryAfterMinutes and attemptsLeft sit beside `error`, not inside it.
    final retry = body["retryAfterMinutes"];
    final attemptsLeft = body["attemptsLeft"];
    var message = error["message"]?.toString() ?? fallback;
    if (attemptsLeft is int) {
      message = '$message $attemptsLeft ${attemptsLeft == 1 ? 'try' : 'tries'} left.';
    }

    return LoginRefusedException(
      code: error["code"]?.toString(),
      message: message,
      retryAfterMinutes: retry is int ? retry : int.tryParse('${retry ?? ''}'),
    );
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await LocalStorage.clearAll();
  }
}

/// A login the server turned away, carrying its reason.
///
/// The code matters more than the status: a device already registered to
/// another account is a different conversation from a blocked account, and
/// both are different from a network failure.
class LoginRefusedException implements Exception {
  /// e.g. `SESSION_ACTIVE_ELSEWHERE`, `ACCOUNT_BLOCKED`. Null when the body
  /// carried none.
  final String? code;
  final String message;

  /// How long until the held session is released on its own. Only sent with
  /// [isSessionActiveElsewhere].
  final int? retryAfterMinutes;

  const LoginRefusedException({
    required this.code,
    required this.message,
    this.retryAfterMinutes,
  });

  /// The account is signed in on another device, and this login was refused
  /// rather than the other device being kicked off.
  ///
  /// **Not an error to retry.** There is no force-sign-in flag in the API, so
  /// there is nothing to offer but the wait — either the student signs out on
  /// the other device, or the session goes idle and is released.
  bool get isSessionActiveElsewhere => code == 'SESSION_ACTIVE_ELSEWHERE';

  /// This phone is already registered to a different account — the
  /// subscription-sharing case. Nothing the student can do in the app; it
  /// needs support to release the device.
  bool get isDeviceBound => code == 'DEVICE_BOUND';

  bool get isAccountBlocked =>
      code == 'ACCOUNT_BLOCKED' || code == 'ACCOUNT_DEACTIVATED';

  /// Email signup not finished: the app should ask for the code.
  bool get isEmailNotVerified => code == 'EMAIL_NOT_VERIFIED';

  @override
  String toString() => message;
}
