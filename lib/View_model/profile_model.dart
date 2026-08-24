// lib/models/profile_model.dart

class SelectedCourseInfo {
  final int id;
  final String title;
  final String? thumbnail;
  final String? accessType; // NEW — needed to know if the course is free/premium

  SelectedCourseInfo({
    required this.id,
    required this.title,
    this.thumbnail,
    this.accessType,
  });

  factory SelectedCourseInfo.fromJson(Map<String, dynamic> json) {
    return SelectedCourseInfo(
      id: json['id'],
      title: json['title'],
      thumbnail: json['thumbnail'],
      accessType: json['accessType'],
    );
  }
}

class SelectedCourseTypeInfo {
  final int id;
  final String title;

  SelectedCourseTypeInfo({required this.id, required this.title});

  factory SelectedCourseTypeInfo.fromJson(Map<String, dynamic> json) {
    return SelectedCourseTypeInfo(
      id: json['id'],
      title: json['title'],
    );
  }
}

// NEW: mirrors the backend's subscriptionInfo object
class SubscriptionInfo {
  final bool isPremiumCourse;
  final bool hasPaid;
  final Map<String, dynamic>? subscription; // raw map is enough for now — expand to a typed model later if needed

  SubscriptionInfo({
    required this.isPremiumCourse,
    required this.hasPaid,
    this.subscription,
  });

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) {
    return SubscriptionInfo(
      isPremiumCourse: json['isPremiumCourse'] ?? false,
      hasPaid: json['hasPaid'] ?? false,
      subscription: json['subscription'],
    );
  }
}

class ProfileModel {
  final int id;
  final String email;
  final String? name;
  final String? phone;
  final String? avatarUrl;
  final String role;
  final String status;
  final SelectedCourseInfo? selectedCourse;
  final SelectedCourseTypeInfo? selectedCourseType;
  final SubscriptionInfo? subscriptionInfo; // NEW

  ProfileModel({
    required this.id,
    required this.email,
    this.name,
    this.phone,
    this.avatarUrl,
    required this.role,
    required this.status,
    this.selectedCourse,
    this.selectedCourseType,
    this.subscriptionInfo,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'],
      email: json['email'],
      name: json['name'],
      phone: json['phone'],
      avatarUrl: json['avatarUrl'],
      role: json['role'],
      status: json['status'],
      selectedCourse: json['selectedCourse'] != null
          ? SelectedCourseInfo.fromJson(json['selectedCourse'])
          : null,
      selectedCourseType: json['selectedCourseType'] != null
          ? SelectedCourseTypeInfo.fromJson(json['selectedCourseType'])
          : null,
      subscriptionInfo: json['subscriptionInfo'] != null
          ? SubscriptionInfo.fromJson(json['subscriptionInfo'])
          : null,
    );
  }
}