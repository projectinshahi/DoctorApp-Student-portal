// lib/core/utils/load_timer.dart
//
// How long each screen waited, printed to the terminal.
//
// The per-request line from ApiClient says how long the *server* took. This
// says how long the *screen* took, which is not the same number: a screen
// that makes two calls in a row waits for both, and that gap is exactly the
// kind of thing that hides behind "the app feels slow".
//
// Debug only. Never the response body — the auth endpoints carry tokens, and
// print() reaches logcat in release builds too.
import 'package:flutter/foundation.dart';

/// Times [body] and prints what it cost.
///
/// [screen] is what the student is looking at, not the endpoint —
/// "QBank subjects", not "/selection/content". Pass a short [detail] for what
/// came back, so a fast call returning nothing is distinguishable from a fast
/// call returning the page.
Future<T> timedLoad<T>(
  String screen,
  Future<T> Function() body, {
  String Function(T result)? detail,
}) async {
  if (!kDebugMode) return body();

  final watch = Stopwatch()..start();
  var outcome = 'ok';
  try {
    final result = await body();
    if (detail != null) outcome = detail(result);
    return result;
  } catch (error) {
    outcome = 'FAILED ${error.runtimeType}';
    rethrow;
  } finally {
    watch.stop();
    final ms = watch.elapsedMilliseconds;
    // A marker on anything a person would notice waiting for.
    final flag = ms >= 1000 ? '  <== SLOW' : '';
    debugPrint('SCREEN  ${ms}ms  $screen  ($outcome)$flag');
  }
}
