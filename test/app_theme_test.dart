import 'package:dr_app/core/theam%20/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the theme does not fill text fields', () {
    // Four fields in the app draw their own container and set
    // InputBorder.none inside it — the two auth screens and the two search
    // bars. A global fill painted a white box inside each of those, which is
    // the one thing a theme cannot know about. Fields that want a fill say so
    // themselves (Profile's name and phone, the comment composer).
    final decoration = AppTheme.light.inputDecorationTheme;
    expect(decoration.filled, isNot(true));
    expect(decoration.fillColor, isNull);
  });

  test('the rest of the input theme is still set', () {
    // Removing the fill must not take the shape and focus colour with it.
    final decoration = AppTheme.light.inputDecorationTheme;
    expect(decoration.border, isA<OutlineInputBorder>());
    expect(decoration.focusedBorder, isA<OutlineInputBorder>());
  });
}
