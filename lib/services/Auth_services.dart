import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/constant/api_constant.dart';
import '../View_model/auth_result_model.dart';

class AuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _isInitialized = false;

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await _googleSignIn.initialize(
        serverClientId: '236824315945-s15s7dnqlr4d0emu5tcj7g5h9ci858tv.apps.googleusercontent.com',
      );
      _isInitialized = true;
    }
  }

  Future<AuthResultModel> signInWithGoogle() async {
    await _ensureInitialized();

    final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

    final GoogleSignInAuthentication googleAuth = googleUser.authentication;
    final String? idToken = googleAuth.idToken;

    if (idToken == null) {
      throw Exception('Failed to get Google ID token');
    }

    final response = await http.post(
      Uri.parse(ApiConstant.googleSignIn),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'idToken': idToken}),
    );

    // 👇 print status code and raw response body
    print('Status code: ${response.statusCode}');
    print('Response body: ${response.body}');

    if (response.statusCode == 200) {
      return AuthResultModel.fromJson(jsonDecode(response.body));

    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error']?['message'] ?? 'Google sign-in failed');
    }
  }
}