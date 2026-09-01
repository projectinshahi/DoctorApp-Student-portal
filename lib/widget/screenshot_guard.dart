// lib/widget/screenshot_guard.dart
//
// App-wide screenshot / screen-recording block. Wraps the whole MaterialApp
// so every route is covered by one switch — dialogs, the video player and the
// quiz included — instead of each screen having to remember to opt in.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../core/utils/capture_watch.dart';
import 'package:no_screenshot/no_screenshot.dart';
import 'package:no_screenshot/screenshot_snapshot.dart';

/// Blocks capture app-wide and flashes [message] in the centre of the screen
/// when the OS tells us a capture was attempted.
///
/// Blocking and warning are two separate mechanisms, and they do NOT both
/// land on both platforms:
///
///  * **Android** — `screenshotOff()` sets `FLAG_SECURE`, so the saved image
///    comes out entirely black. `Activity.ScreenCaptureCallback` (API 34+)
///    still fires, because the OS did run a capture — it just handed back a
///    blank one. So both halves land: the content is protected AND the
///    banner shows. Below API 34 the plugin falls back to a MediaStore
///    observer, which will not see a blocked capture; those devices get the
///    protection but not the banner.
///  * **iOS** — there is no `FLAG_SECURE`. The plugin blanks the captured
///    image instead, and `userDidTakeScreenshot` fires, so the banner shows
///    there too.
///
/// The prevention claim is persisted natively, so it survives a process
/// restart — protection is on from launch, before the first frame.
class ScreenshotGuard extends StatefulWidget {
  final Widget child;

  /// Shown centred, briefly, when a capture attempt is reported.
  final String message;

  const ScreenshotGuard({
    super.key,
    required this.child,
    this.message = 'Screenshots are not allowed.\nThis content is protected.',
  });

  @override
  State<ScreenshotGuard> createState() => _ScreenshotGuardState();
}

class _ScreenshotGuardState extends State<ScreenshotGuard>
    with WidgetsBindingObserver {
  final _noScreenshot = NoScreenshot.instance;

  StreamSubscription<ScreenshotSnapshot>? _events;
  Timer? _hideTimer;
  bool _showWarning = false;

  /// Shared with the video player, which pauses off the same flag. Unlike the
  /// screenshot warning this is not a 2.5s flash — the cover stays up for as
  /// long as the capture runs, because the danger is ongoing rather than a
  /// moment.
  final _capture = CaptureWatch.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _capture.start();
    _protect();
  }

  Future<void> _protect() async {
    await _noScreenshot.screenshotOff();
    await _noScreenshot.startScreenshotListening();

    // Only subscribe once — _protect() also runs on every resume.
    _events ??= _noScreenshot.screenshotStream.listen((snapshot) {
      if (snapshot.wasScreenshotTaken) _flashWarning();
    });

  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // FLAG_SECURE lives on the Android window, and the window is rebuilt when
    // the activity is recreated (rotation, a config change, being restored
    // from the background). Re-assert it on resume or protection quietly
    // lapses on exactly the screens a user would come back to.
    if (state == AppLifecycleState.resumed) _protect();
  }

  void _flashWarning() {
    if (!mounted) return;
    setState(() => _showWarning = true);
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _showWarning = false);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _events?.cancel();
    _noScreenshot.stopScreenshotListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // While a recording runs, cover the app entirely. On Android the
        // captured frames are already blank, but the person holding the phone
        // can still be filming the screen with a second device — and on iOS,
        // where there is no FLAG_SECURE, this cover IS the protection.
        ValueListenableBuilder<bool>(
          valueListenable: _capture.isCapturing,
          builder: (context, capturing, _) => capturing
              ? Positioned.fill(
                  child: Material(
                    color: Colors.black,
                    child: _WarningBanner(
                      message: 'Screen recording or mirroring detected.\n'
                          'Playback has stopped and this content is hidden.',
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),

        // IgnorePointer so the warning never eats a tap meant for the app.
        IgnorePointer(
          child: AnimatedOpacity(
            opacity: _showWarning ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            // `builder` sits ABOVE the Navigator, so nothing here has a
            // Material ancestor and bare Text paints with debug's yellow
            // double underlines. Supply one.
            child: Material(
              type: MaterialType.transparency,
              child: _WarningBanner(message: widget.message),
            ),
          ),
        ),
      ],
    );
  }
}

class _WarningBanner extends StatelessWidget {
  final String message;

  const _WarningBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 40.w),
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 22.w),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.screenshot_monitor_rounded, color: Colors.white, size: 34.sp),
            SizedBox(height: 12.w),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
