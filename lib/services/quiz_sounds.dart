// lib/services/quiz_sounds.dart
//
// The right and wrong answer sounds, played only when the student has turned
// Sound effect on in Settings. SettingsProvider keeps [enabled] in step.
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class QuizSounds {
  const QuizSounds._();

  static bool enabled = false;

  static AudioPlayer? _player;

  /// Plays the sound for a verdict. Null — no verdict yet, or a save that
  /// failed — plays nothing.
  static Future<void> verdict(bool? correct) async {
    if (!enabled || correct == null) return;
    try {
      final player = _player ??= _create();
      await player.stop();
      await player.play(
          AssetSource(correct ? 'sounds/correct.wav' : 'sounds/wrong.wav'));
    } catch (error) {
      // A sound is feedback, never a reason for an answer to fail.
      if (kDebugMode) debugPrint('SOUND  not played: $error');
    }
  }

  static AudioPlayer _create() {
    // The app's assets live under asset/, not the package default assets/.
    final player = AudioPlayer()..audioCache = AudioCache(prefix: 'asset/');
    if (defaultTargetPlatform == TargetPlatform.android) {
      // SoundPool: made for clips this short, and starts without a lag.
      player.setPlayerMode(PlayerMode.lowLatency);
    }
    return player;
  }
}
