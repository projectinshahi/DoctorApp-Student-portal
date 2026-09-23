// lib/widget/app_refresh.dart
//
// Pull to refresh, in the app's green.
//
// Every browse screen already refetches when it comes back into view. This is
// the other half: the student pulling because they want it now, and seeing
// that something happened. A pull runs the screen's own refresh — the same
// call the automatic one makes — so the two cannot drift apart.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../core/theam /app_color.dart';

class AppRefresh extends StatelessWidget {
  final Future<void> Function() onRefresh;

  /// The scrollable to pull on. Give it
  /// `physics: const AlwaysScrollableScrollPhysics()`, or a list shorter than
  /// the screen refuses to move.
  final Widget child;

  final bool _fill;

  const AppRefresh({super.key, required this.onRefresh, required this.child})
      : _fill = false;

  /// For a child that does not scroll at all — an empty shelf, an error.
  ///
  /// Those are the screens a pull cannot otherwise reach, and the ones a
  /// student is most likely to try it on.
  const AppRefresh.fill(
      {super.key, required this.onRefresh, required this.child})
      : _fill = true;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColor.buttoncolor,
      backgroundColor: Colors.white,
      displacement: 28.h,
      child: _fill
          ? LayoutBuilder(
              // As tall as the viewport, so a message in the middle of an
              // empty screen can still be pulled down.
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: constraints.maxHeight),
                  child: child,
                ),
              ),
            )
          : child,
    );
  }
}
