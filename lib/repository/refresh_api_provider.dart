// lib/providers/auth_provider.dart
import 'package:flutter/foundation.dart';

import '../View_model/auth_result_model.dart';
import '../core/constant/local_storage.dart';
import '../services/Auth_services.dart';
import '../services/refresh_api_services.dart';
import '../services/selection_content_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.unknown;
  String? _sessionMessage;
  bool _isLoggingOut = false;
  bool _hasSelectedExam = false; // NEW

  /// True while the server is being asked whether this account already has a
  /// course. The gate shows the splash meanwhile — without it the selection
  /// screen flashes up for a student who has one.
  bool _resolvingSelection = false;
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
  bool get isResolvingSelection => _resolvingSelection;

  /// Whether the account already has a course, asking the server when the
  /// local flag says no.
  ///
  /// `hasSelectedExam` is a local boolean set only by finishing the selection
  /// screen, so it is missing on a reinstall, on a cleared cache and on every
  /// new device — and the app then asked a student who chose their course
  /// months ago to choose it again. The server knows; ask it.
  ///
  /// Returns true when the student can go straight to the home screen.
  Future<bool> resolveExamSelection() async {
    if (_hasSelectedExam) return true;

    _resolvingSelection = true;
    notifyListeners();

    final result = await SelectionContentService().fetchSelectionContent();
    _resolvingSelection = false;

    // Only a definite "yes" is worth writing down. A failed call means we do
    // not know, and sending a returning student to the selection screen
    // because their connection dropped is the same bug again.
    if (result.isSuccess && result.content?.hasSelection == true) {
      await LocalStorage.setHasSelectedExam(true);
      _hasSelectedExam = true;
      notifyListeners();
      return true;
    }

    notifyListeners();
    return false;
  }

  Future<void> _checkInitialAuthState() async {
    final accessToken = await LocalStorage.getAccessToken();

    if (accessToken != null && accessToken.isNotEmpty) {
      _hasSelectedExam = await LocalStorage.getHasSelectedExam(); // NEW
      _status = AuthStatus.authenticated;
      // A returning student on a reinstalled app has a token but no flag.
      if (!_hasSelectedExam) {
        notifyListeners();
        await resolveExamSelection();
      }
    } else {
      _status = AuthStatus.unauthenticated;
    }

    notifyListeners();
  }

  /// The server's own wording, not a generic line.
  ///
  /// "You were signed out because your account was accessed on another
  /// device" is the difference between a student understanding what happened
  /// and one who thinks the app is broken — and it is why the backend
  /// distinguishes SESSION_ENDED from a plain expiry at all.
  void _onSessionExpired(String message) {
    _status = AuthStatus.unauthenticated;
    _sessionMessage = message;
    notifyListeners();
  }

  Future<AuthResultModel> signInWithGoogle() async {
    final result = await _authService.signInWithGoogle();
    _hasSelectedExam = await LocalStorage.getHasSelectedExam(); // NEW — check fresh on every sign-in
    _status = AuthStatus.authenticated;
    _sessionMessage = null;
    notifyListeners();

    // Signing in on a new phone: the flag is local, the course is not.
    if (!_hasSelectedExam) await resolveExamSelection();

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