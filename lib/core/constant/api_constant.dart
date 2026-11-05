class ApiConstant {
  /// The backend server. Change this one line to point the app elsewhere.
  static const String host = 'https://doctorapp-backend-cl2h.onrender.com';

  /// Every endpoint lives under /api: the server answers /api/health, and
  /// /health is a 404.
  static const String baseUrl = '$host/api';

  static const String googleSignIn = '$baseUrl/auth/google';
  static const String appleSignIn = '$baseUrl/auth/apple';
  static const String appleCallback = '$baseUrl/auth/apple/callback';
  static const String register = '$baseUrl/auth/register';
  static const String login = '$baseUrl/auth/login';
  static const String verifyOtp = '$baseUrl/auth/verify-otp';
  static const String resendOtp = '$baseUrl/auth/resend-otp';
  static const String forgotPassword = '$baseUrl/auth/forgot-password';
  static const String resetPassword = '$baseUrl/auth/reset-password';
  static const String refresh = '$baseUrl/auth/refresh';
  static const String logout = '$baseUrl/auth/logout';
}
