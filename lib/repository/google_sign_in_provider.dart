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

  /// Asks for the emailed login code. Null when it is on its way — or, from
  /// a server without login codes, when it signed straight in, with the
  /// session in [authResult]. Not through [_signIn]: usually nothing is
  /// signed in yet, so no "Signing you in…".
  Future<LoginRefusedException?> loginWithEmail(
      String email, String password) async {
    authResult = null;
    refusal = null;
    try {
      authResult = await _authService.loginWithEmail(email, password);
      return null;
    } on LoginRefusedException catch (e) {
      return e;
    } catch (_) {
      return const LoginRefusedException(
        code: null,
        message: 'Could not reach the server. Check your connection and try again.',
      );
    }
  }

  Future<bool> verifyLoginOtp(String email, String code) =>
      _signIn(() => _authService.verifyLoginOtp(email, code));

  Future<bool> verifyOtp(String email, String code) =>
      _signIn(() => _authService.verifyOtp(email, code));

  Future<void> resendOtp(String email) => _authService.resendOtp(email);

  Future<String?> forgotPassword(String email) => _authService.forgotPassword(email);

  Future<bool> resetPassword(String email, String code, String password) =>
      _signIn(() => _authService.resetPassword(email, code, password));

  /// Registration signs no one in, so all it reports is why it was refused,
  /// or null when the code is on its way.
  Future<LoginRefusedException?> registerWithEmail(
      String email, String password) async {
    try {
      await _authService.registerWithEmail(email, password);
      return null;
    } on LoginRefusedException catch (e) {
      return e;
    } catch (_) {
      return const LoginRefusedException(
        code: null,
        message: 'Could not reach the server. Check your connection and try again.',
      );
    }
  }

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