import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constant/local_storage.dart';
import '../Authendication/login/login_screen.dart';
import '../subjectSelection/select_exam_screen.dart';
import '../Home/home_screen.dart'; // adjust path

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    await Future.delayed(const Duration(seconds: 2));

    final String? accessToken = await LocalStorage.getAccessToken();
    final String? refreshToken = await LocalStorage.getRefreshToken();
    final String deviceId = await LocalStorage.getDeviceId();
    final bool hasSelectedExam = await LocalStorage.getHasSelectedExam(); // NEW

    debugPrint("==================================");
    debugPrint("Device ID       : $deviceId");
    debugPrint("Access Token    : $accessToken");
    debugPrint("Refresh Token   : $refreshToken");
    debugPrint("Has Selected Exam: $hasSelectedExam");
    debugPrint("==================================");

    if (!mounted) return;

    if (accessToken != null && accessToken.isNotEmpty) {
      if (hasSelectedExam) {
        // Already picked a course/exam before -> straight to Home
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const Homescreen(), // adjust constructor args if needed
          ),
        );
      } else {
        // Logged in but hasn't picked yet -> show the selection screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ExamSelectionScreen(
              accessToken: accessToken,
              refreshToken: refreshToken ?? "",
              deviceId: deviceId,
            ),
          ),
        );
      }
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}