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

      final error = jsonDecode(response.body);

      throw Exception(
        error["error"]?["message"] ?? "Google Sign-In Failed",
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