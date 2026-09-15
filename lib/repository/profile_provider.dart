import 'dart:convert';
// lib/provider/profile_provider.dart
import '../core/utils/load_timer.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import '../View_model/profile_model.dart';
import '../core/constant/local_storage.dart';
import '../services/profile_service.dart';

class ProfileProvider extends ChangeNotifier {
  final ProfileService _service = ProfileService();

  bool isLoading = false;
  bool isSaving = false;
  bool isUploadingPhoto = false;
  String? errorMessage;
  String? photoUploadError;
  ProfileModel? profile;

  ProfileProvider() {
    _restore();
  }

  /// Paints the last known profile before the network is asked, so the home
  /// screen's greeting and avatar are there on launch rather than a beat
  /// later.
  Future<void> _restore() async {
    if (profile != null) return;
    try {
      final stored = await LocalStorage.getCached(LocalStorage.profileKey);
      if (stored == null || stored.isEmpty || profile != null) return;
      profile = ProfileModel.fromJson(jsonDecode(stored));
      isLoading = false;
      notifyListeners();
    } catch (_) {
      // Written by an older build, or storage unavailable. The fetch under
      // way covers it — restoring must never break the screen.
    }
  }

  /// The request currently in flight, if any.
  Future<void>? _inFlight;

  /// Fetches the profile, sharing one request between callers.
  ///
  /// The home screen and the profile screen both refresh on becoming
  /// visible, and moving between them lands both within a second. The last
  /// of the app's loaders without this guard.
  Future<void> loadProfile() =>
      _inFlight ??= _fetchProfile().whenComplete(() => _inFlight = null);

  Future<void> _fetchProfile() async {
    // Only when there is nothing to show. A reopened Profile keeps the name
    // and photo on screen while the refetch runs behind them.
    isLoading = profile == null;
    errorMessage = null;
    notifyListeners();

    try {
      profile = await timedLoad('profile', _service.getProfile);
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveProfile({String? name, String? phone}) async {
    isSaving = true;
    errorMessage = null;
    notifyListeners();

    try {
      profile = await _service.updateProfile(name: name, phone: phone);
      isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      isSaving = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> uploadAndSavePhoto(File imageFile) async {
    isUploadingPhoto = true;
    photoUploadError = null;
    notifyListeners();

    try {
      final avatarUrl = await _service.uploadAvatar(imageFile);
      profile = await _service.updateProfile(avatarUrl: avatarUrl);
      isUploadingPhoto = false;
      notifyListeners();
      return true;
    } catch (e) {
      photoUploadError = e.toString().replaceFirst('Exception: ', '');
      isUploadingPhoto = false;
      notifyListeners();
      return false;
    }
  }
}