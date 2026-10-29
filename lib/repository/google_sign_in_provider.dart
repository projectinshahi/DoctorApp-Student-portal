import 'package:flutter/material.dart';

import '../View_model/auth_result_model.dart';
import '../services/Auth_services.dart';

class GoogleSignInIntergration extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool isLoading = false;
  String? errorMessage;
  AuthResultModel? authResult;

  /// The server's typed reason for turning a login away, or null.
  ///
  /// Kept as the exception rather than flattened into [errorMessage]: the
  /// screens need the *code* to know whether to say "wait 30 minutes",
  /// "contact support" or "try again", and a stringified exception reaches
  /// the student as "Exception: ...".
  LoginRefusedException? refusal;

  Future<bool> signInWithGoogle() => _signIn(_authService.signInWithGoogle);

  Future<bool> signInWithApple() => _signIn(_authService.signInWithApple);

  Future<bool> _signIn(Future<AuthResultModel> Function() signIn) async {
    isLoading = true;
    errorMessage = null;
    refusal = null;
    notifyListeners();

    try {
      authResult = await signIn();
      isLoading = false;
      notifyListeners();
      return true;
    } on LoginRefusedException catch (e) {
      refusal = e;
      errorMessage = e.message;
      isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      errorMessage = e.toString();
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void reset() {
    isLoading = false;
    errorMessage = null;
    authResult = null;
    notifyListeners();
  }
}