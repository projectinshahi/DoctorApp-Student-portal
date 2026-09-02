import 'package:flutter/material.dart';

import '../../widget/app_shimmer.dart';

/// The loading face of [AuthGate], and nothing more.
///
/// This used to run its own copy of the routing rules — read the tokens,
/// read the local `hasSelectedExam`, then `pushReplacement` to Home, the
/// course picker or Login. Two problems with that:
///
///  * It **replaced AuthGate**, which is what listens for the session dying.
///    Once splash had run, a SESSION_ENDED reset nothing.
///
///  * It decided from the local flag alone. A reinstall or a new phone has no
///    flag, so it sent a student who picked a course months ago back to the
///    picker — even after AuthGate had already asked the server and knew
///    better. Two deciders, and the wrong one ran last.
///
/// So it now decides nothing. AuthGate owns the branch; this is what the
/// student looks at while it does.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: ScreenShimmer(layout: ShimmerLayout.splash),
    );
  }
}