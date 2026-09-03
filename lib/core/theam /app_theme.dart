// lib/core/theam/app_theme.dart
//
// One theme for the whole app.
//
// Every screen used to hardcode its own colours, which had two costs. Any
// screen somebody forgot looked like a different app — the course picker was
// grey and black for months. And stock Material widgets came out in
// Flutter's defaults: a dialog nobody styled was white under a lilac tint, a
// CircularProgressIndicator nobody styled was blue.
//
// Setting it here means a widget that is *not* styled still looks right,
// which is the opposite of the situation before.
import 'package:flutter/material.dart';

import 'app_color.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColor.buttoncolor,
      primary: AppColor.buttoncolor,
      surface: AppColor.Screenbackground,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColor.Screenbackground,

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColor.Screenbackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColor.Textcolor,
      ),

      // surfaceTintColor is the one that catches people out: Material 3
      // paints a lilac wash over any raised surface, so a dialog set to the
      // app's cream still came out mauve until this is cleared.
      dialogTheme: DialogThemeData(
        backgroundColor: AppColor.Screenbackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),

      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColor.buttoncolor,
          foregroundColor: AppColor.Buttontextcolor,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColor.buttoncolor),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColor.buttoncolor,
          side: const BorderSide(color: AppColor.buttoncolor),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),

      // Was Flutter's blue on every unstyled spinner in the app.
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColor.buttoncolor,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColor.buttoncolor
              : null,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColor.buttoncolor, width: 1.4),
        ),
      ),

      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColor.buttoncolor,
        selectionHandleColor: AppColor.buttoncolor,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColor.buttoncolor,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      tabBarTheme: const TabBarThemeData(
        labelColor: AppColor.buttoncolor,
        indicatorColor: AppColor.buttoncolor,
        dividerColor: Colors.transparent,
      ),
    );
  }
}
