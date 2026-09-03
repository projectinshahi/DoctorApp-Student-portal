import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../../../../core/constant/api_constant.dart';
import '../../../../core/utils/device_id_helper.dart';
import '../View_model/auth_result_model.dart';
import '../core/constant/local_storage.dart';

class AuthService {
  AuthService();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
      'openid',
    ],
    serverClientId:
    '125167391971-djufjjsm3gp8vms4id65rdb3bg72hciv.apps.googleusercontent.com',
  );

  Future<AuthResultModel> signInWithGoogle() async {
    try {
      print("========== GOOGLE SIGN IN ==========");

      // Optional: clear previous Google session
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleUser =
      await _googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception("User cancelled Google Sign-In");
      }

      print("User Email : ${googleUser.email}");

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      final String? idToken = googleAuth.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw Exception("Google ID Token is null");
      }

      final String deviceId = await DeviceIdHelper.getDeviceId();

      final response = await http.post(
        Uri.parse(ApiConstant.googleSignIn),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "idToken": idToken,
          "deviceId": deviceId,
        }),
      );

      print("Status Code : ${response.statusCode}");
      print("Response : ${response.body}");

      if (response.statusCode == 200) {
        final AuthResultModel authResult =
        AuthResultModel.fromJson(jsonDecode(response.body));

        // Save Tokens
        await LocalStorage.saveAccessToken(authResult.accessToken);
        await LocalStorage.saveRefreshToken(authResult.refreshToken);

        print("Access Token Saved");
        print("Refresh Token Saved");

        return authResult;
      }

      // The server refuses a login for reasons the student can act on, and
      // each needs its own words. A raw Exception here surfaced as
      // "Exception: ..." on the login screen.
      Map<String, dynamic> error = const {};
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded["error"] is Map) {
          error = Map<String, dynamic>.from(decoded["error"] as Map);
        }
      } catch (_) {
        // A gateway page is not JSON. The generic message below covers it.
      }

      // retryAfterMinutes sits beside `error`, not inside it.
      Map<String, dynamic> body = const {};
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) body = Map<String, dynamic>.from(decoded);
      } catch (_) {}

      final retry = body["retryAfterMinutes"];

      throw LoginRefusedException(
        code: error["code"]?.toString(),
        message: error["message"]?.toString() ??
            "Could not sign in. Please try again.",
        retryAfterMinutes: retry is int
            ? retry
            : int.tryParse('${retry ?? ''}'),
      );
    } catch (e, stackTrace) {
      print("Google Sign-In Error : $e");
      print(stackTrace);
      rethrow;
    }
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

  bool get isAccountBlocked => code == 'ACCOUNT_BLOCKED';

  @override
  String toString() => message;
}
