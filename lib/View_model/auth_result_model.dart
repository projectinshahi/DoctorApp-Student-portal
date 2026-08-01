class AuthResultModel {
  final String accessToken;
  final String refreshToken;
  final bool isNewUser;
  final UserModel user;

  AuthResultModel({
    required this.accessToken,
    required this.refreshToken,
    required this.isNewUser,
    required this.user,
  });

  factory AuthResultModel.fromJson(Map<String, dynamic> json) {
    return AuthResultModel(
      accessToken: json['accessToken'],
      refreshToken: json['refreshToken'],
      isNewUser: json['isNewUser'] ?? false,
      user: UserModel.fromJson(json['user']),
    );
  }
}

class UserModel {
  final int id;
  final String email;
  final String? name;
  final String role;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      email: json['email'],
      name: json['name'],
      role: json['role'],
    );
  }
}