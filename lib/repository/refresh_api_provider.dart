// lib/providers/auth_provider.dart
import 'package:flutter/foundation.dart';

import '../View_model/auth_result_model.dart';
import '../core/constant/local_storage.dart';
import '../services/Auth_services.dart';
import '../services/refresh_api_services.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.unknown;
  String? _sessionMessage;
  bool _isLoggingOut = false;
  bool _hasSelectedExam = false; // NEW
  final AuthService _authService = AuthService();

  AuthProvider() {
    ApiClient.onSessionExpired = _onSessionExpired;
    _checkInitialAuthState();
  }

  AuthStatus get status => _status;
  String? get sessionMessage => _sessionMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoggingOut => _isLoggingOut;
  bool get hasSelectedExam => _hasSelectedExam; // NEW

  Future<void> _checkInitialAuthState() async {
    final accessToken = await LocalStorage.getAccessToken();

    if (accessToken != null && accessToken.isNotEmpty) {
      _hasSelectedExam = await LocalStorage.getHasSelectedExam(); // NEW
      _status = AuthStatus.authenticated;
    } else {
      _status = AuthStatus.unauthenticated;
    }

    notifyListeners();
  }

  void _onSessionExpired() {
    _status = AuthStatus.unauthenticated;
    _sessionMessage = "Your session has ended. Please log in again.";
    notifyListeners();
  }

  Future<AuthResultModel> signInWithGoogle() async {
    final result = await _authService.signInWithGoogle();
    _hasSelectedExam = await LocalStorage.getHasSelectedExam(); // NEW — check fresh on every sign-in
    _status = AuthStatus.authenticated;
    _sessionMessage = null;
    notifyListeners();
    return result;
  }

  /// Call this from ExamSelectionScreen right after a successful save,
  /// instead of navigating manually — AuthGate will react automatically.
  Future<void> markExamSelected() async {
    await LocalStorage.setHasSelectedExam(true);
    _hasSelectedExam = true;
    notifyListeners();
  }

  Future<void> signOut() async {
    _isLoggingOut = true;
    notifyListeners();

    await _authService.signOut();

    _status = AuthStatus.unauthenticated;
    _sessionMessage = null;
    _hasSelectedExam = false; // NEW — reset so next login re-checks properly
    _isLoggingOut = false;
    notifyListeners();
  }

  void clearSessionMessage() {
    _sessionMessage = null;
    notifyListeners();
  }
}