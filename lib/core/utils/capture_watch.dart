// lib/core/utils/capture_watch.dart
//
// One place that knows whether the screen is being captured.
//
// Two things need this answer and they are far apart in the tree: the guard
// overlay sits above the Navigator, the video player sits deep inside a
// lesson. A second EventChannel subscription would be a second, disagreeing
// answer — the platform delivers the current state on subscribe, so two
// listeners can genuinely diverge mid-stream. Hence one stream, one flag.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// True while the screen is being recorded, cast, or mirrored.
///
/// Fed by `dr_app/screen_recording`, which both platforms implement:
///
///  * Android — the API 35 recording callback OR a presentation display.
///  * iOS — `UIScreen.isCaptured`, which covers recording and AirPlay alike.
class CaptureWatch {
  CaptureWatch._();

  static final CaptureWatch instance = CaptureWatch._();

  static const _channel = EventChannel('dr_app/screen_recording');

  /// Listen to this to react to capture starting or stopping.
  final ValueNotifier<bool> isCapturing = ValueNotifier<bool>(false);

  StreamSubscription<dynamic>? _events;

  void start() {
    // Idempotent: the guard mounts once, but hot restart can call this again.
    if (_events != null) return;

    _events = _channel.receiveBroadcastStream().listen(
      (event) => isCapturing.value = event == true,
      // A platform that cannot answer is not a platform that is recording.
      // Failing open here would black out the app on every device where the
      // channel is missing.
      onError: (_) => isCapturing.value = false,
    );
  }

  void stop() {
    _events?.cancel();
    _events = null;
    isCapturing.value = false;
  }
}
