// lib/provider/profile_provider.dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../View_model/profile_model.dart';
import '../services/profile_service.dart';

class ProfileProvider extends ChangeNotifier {
  final ProfileService _service = ProfileService();

  bool isLoading = false;
  bool isSaving = false;
  bool isUploadingPhoto = false;
  String? errorMessage;
  String? photoUploadError;
  ProfileModel? profile;

  Future<void> loadProfile() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      profile = await _service.getProfile();
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