import 'dart:async';
// lib/services/profile_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../View_model/profile_model.dart';
import '../core/constant/local_storage.dart';

class ProfileService {
  static const String _profileUrl = 'https://doctorapp-backend-30gd.onrender.com/api/users/me';
  static const String _signatureUrl = 'https://doctorapp-backend-30gd.onrender.com/api/uploads/signature';

  Future<ProfileModel> getProfile() async {
    final token = await LocalStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not logged in. Please log in again.');
    }

    final response = await http.get(
      Uri.parse(_profileUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      // For the next launch, so the greeting is on screen before the network
      // is asked. Not awaited: the caller already has its data.
      unawaited(LocalStorage.saveCached(
          LocalStorage.profileKey, jsonEncode(data['user'])));
      return ProfileModel.fromJson(data['user']);
    } else {
      throw Exception(data['error']?['message'] ?? 'Failed to load profile');
    }
  }

  Future<ProfileModel> updateProfile({
    String? name,
    String? phone,
    String? avatarUrl,
  }) async {
    final token = await LocalStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not logged in. Please log in again.');
    }

    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (phone != null) body['phone'] = phone;
    if (avatarUrl != null) body['avatarUrl'] = avatarUrl;

    final response = await http.put(
      Uri.parse(_profileUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return ProfileModel.fromJson(data['user']);
    } else {
      throw Exception(data['error']?['message'] ?? 'Failed to update profile');
    }
  }

  // Uploads directly to Cloudinary using a signed request,
  // then returns the resulting secure_url.
  Future<String> uploadAvatar(File imageFile) async {
    final token = await LocalStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not logged in. Please log in again.');
    }

    // Step 1: get a signed signature from our backend
    final sigResponse = await http.post(
      Uri.parse(_signatureUrl),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (sigResponse.statusCode != 200) {
      throw Exception('Failed to get upload signature');
    }

    final sigData = jsonDecode(sigResponse.body);

    // Step 2: upload the image directly to Cloudinary
    final uploadUri = Uri.parse(
      'https://api.cloudinary.com/v1_1/${sigData['cloudName']}/image/upload',
    );

    final request = http.MultipartRequest('POST', uploadUri)
      ..fields['api_key'] = sigData['apiKey']
      ..fields['timestamp'] = sigData['timestamp'].toString()
      ..fields['signature'] = sigData['signature']
      ..fields['folder'] = sigData['folder']
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    final streamedResponse = await request.send();
    final uploadResponseBody = await streamedResponse.stream.bytesToString();
    final uploadData = jsonDecode(uploadResponseBody);

    if (streamedResponse.statusCode != 200) {
      throw Exception(uploadData['error']?['message'] ?? 'Photo upload failed');
    }

    return uploadData['secure_url'];
  }
}