// lib/core/utils/app_navigator.dart
//
// The app's one navigator.
//
// Session loss can happen while a pushed screen is on top — a quiz, the
// player, a test paper. Reacting to it needs the Navigator itself, from
// outside any particular screen's context, because the screen that must be
// removed is often the one holding that context.
import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
