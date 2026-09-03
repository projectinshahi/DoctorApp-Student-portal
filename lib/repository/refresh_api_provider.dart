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

  /// The server's sentence about a device that was just signed out, held
  /// until a screen has shown it. Null except right after a sign-in that
  /// displaced another device.
  String? _signInNotice;
  bool _hasSelectedExam = false; // NEW

  /// True while the server is being asked whether this account already has a
  /// course. The gate shows the splash meanwhile — without it the selection
  /// screen flashes up for a student who has one.
  bool _resolvingSelection = false;
  final AuthService _authService = AuthService();

  /// True once an authenticated request has succeeded in this run.
  ///
  /// A session that dies *while in use* deserves an interruption — the
  /// student was mid-something and needs to know why it stopped. A session
  /// already dead at launch does not: they have touched nothing, and the
  /// login screen's own banner says it without a modal in the way.
  bool _sessionWasLive = false;

  bool get sessionWasLive => _sessionWasLive;

  AuthProvider() {
    ApiClient.onSessionExpired = _onSessionExpired;
    ApiClient.onAuthenticatedSuccess = () => _sessionWasLive = true;
    _checkInitialAuthState();
  }

  AuthStatus get status => _status;
  String? get sessionMessage => _sessionMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoggingOut => _isLoggingOut;

  String? get signInNotice => _signInNotice;

  void clearSignInNotice() {
    _signInNotice = null;
    notifyListeners();
  }
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

    if (!_resolvingSelection) {
      _resolvingSelection = true;
      notifyListeners();
    }

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

  /// Consumed by the gate after it has shown the interruption, so the next
  /// sign-in starts from a clean slate.
  void markSessionEndShown() => _sessionWasLive = false;

  Future<AuthResultModel> signInWithGoogle() async {
    final result = await _authService.signInWithGoogle();
    await adoptSession(result);
    return result;
  }

  /// Takes a session that another provider obtained.
  ///
  /// The login screens sign in through GoogleSignInIntergration, which stores
  /// the tokens but knows nothing about this provider — so without this call
  /// the status stayed `unauthenticated`, AuthGate went on rendering the
  /// login screen, and the student only reached home on some later unrelated
  /// rebuild. That was the "login, see the login screen, then it refreshes
  /// into home" flicker.
  Future<void> adoptSession(AuthResultModel result) async {
    // Shown verbatim, and only when the server sent one. It is null on a new
    // account and on a same-device re-login — telling a student they were
    // signed out on "another device" when it was this phone is worse than
    // saying nothing.
    _signInNotice = result.notice;

    // A brand new account has no course, so there is nothing to ask the
    // server about. Skipping the round trip sends them straight to the
    // picker instead of through a spinner first.
    _hasSelectedExam =
        result.isNewUser ? false : await LocalStorage.getHasSelectedExam();

    // Signing in on a new phone: the flag is local, the course is not, so
    // the server has to be asked.
    final mustResolve = !result.isNewUser && !_hasSelectedExam;

    // Raised *before* the notify, not inside resolveExamSelection.
    //
    // The status flip rebuilds AuthGate immediately. If this were still
    // false, the gate would render the course picker for the one frame
    // before the request starts — picker, then splash, then home. Setting it
    // first means the student sees a loading screen for the whole wait.
    _resolvingSelection = mustResolve;

    _status = AuthStatus.authenticated;
    _sessionMessage = null;
    notifyListeners();

    if (mustResolve) await resolveExamSelection();
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