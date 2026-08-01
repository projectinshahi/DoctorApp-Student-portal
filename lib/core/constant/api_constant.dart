class ApiConstant {
  // 10.0.2.2 is the special alias Android emulators use to reach your computer's localhost.
  // If testing on a real physical device, replace with your computer's local network IP,
  // e.g. "http://192.168.1.5:3000/api"
  static const String baseUrl = 'http://10.0.2.2:3000/api';

  static const String googleSignIn = '$baseUrl/auth/google';
}