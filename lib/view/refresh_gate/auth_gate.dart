// lib/widgets/auth_gate.dart
import 'package:dr_app/view/Home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constant/local_storage.dart';
import '../../repository/refresh_api_provider.dart';
import '../Authendication/login/login_screen.dart';
import '../splash/splash_screen.dart';
import '../subjectSelection/select_exam_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.status == AuthStatus.unauthenticated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // The session can die while a pushed screen (QBank, a quiz, the
            // lesson player) is on top. Swapping this root to the login screen
            // doesn't remove those — without this the user stays on a dead
            // screen and backing out of it walks them straight out of the app.
            final navigator = Navigator.of(context);
            if (navigator.canPop()) navigator.popUntil((route) => route.isFirst);

            if (auth.sessionMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(auth.sessionMessage!)),
              );
              auth.clearSessionMessage();
            }
          });
          return const LoginScreen();
        }

        if (auth.status == AuthStatus.authenticated) {
          // NEW: branch on hasSelectedExam, same rule SplashScreen used to enforce alone
          if (!auth.hasSelectedExam) {
            return FutureBuilder<Map<String, String?>>(
              future: _loadTokensForExamSelection(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SplashScreen(); // brief loading while reading tokens
                }
                final data = snapshot.data!;
                return ExamSelectionScreen(
                  accessToken: data['accessToken'] ?? '',
                  refreshToken: data['refreshToken'] ?? '',
                  deviceId: data['deviceId'] ?? '',
                );
              },
            );
          }
          return const Homescreen();
        }

        return const SplashScreen(); // AuthStatus.unknown
      },
    );
  }

  Future<Map<String, String?>> _loadTokensForExamSelection() async {
    return {
      'accessToken': await LocalStorage.getAccessToken(),
      'refreshToken': await LocalStorage.getRefreshToken(),
      'deviceId': await LocalStorage.getDeviceId(),
    };
  }
}