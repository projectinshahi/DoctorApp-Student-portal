// lib/widget/app_logo.dart
//
// The Dr. SKM's Academy badge, wherever it appears.
//
// One definition rather than three: the splash, the login screen and the
// sign-in loading screen all showed a plain green rounded square standing in
// for it, and each would otherwise need the same clipping and the same
// fallback written again.
import 'package:flutter/material.dart';

import '../core/theam /app_color.dart';

class AppLogo extends StatelessWidget {
  /// Width and height. The badge is round, so this is its diameter.
  final double size;

  const AppLogo({super.key, required this.size});

  static const String asset = 'asset/icons/app_logo.png';

  @override
  Widget build(BuildContext context) {
    // Clipped rather than dropped in as a rectangle: the artwork is 1250x1042
    // with a wide margin around the roundel, so unclipped it either sits
    // small inside its box or shows that margin as a pale rectangle against
    // the cream background. cover crops the margin and lets the badge fill
    // the space.
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          // A fresh clone that has not added the logo yet still launches,
          // instead of showing a red error box on the first screen a
          // developer sees.
          errorBuilder: (context, _, __) => Container(
            color: AppColor.buttoncolor,
            child: Icon(Icons.menu_book_rounded,
                size: size * 0.42, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
