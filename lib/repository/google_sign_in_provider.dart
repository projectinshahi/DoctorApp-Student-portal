import 'package:flutter/material.dart';

import '../View_model/auth_result_model.dart';
import '../services/Auth_services.dart';

class GoogleSignInIntergration extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool isLoading = false;
  String? errorMessage;
  AuthResultModel? authResult;

  Future<bool> signInWithGoogle() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      authResult = await _authService.signInWithGoogle();
      isLoading = false;
      notifyListeners();
      return true;
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