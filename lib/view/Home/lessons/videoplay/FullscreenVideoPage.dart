import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

/// Fullscreen page for direct (non-YouTube) video playback.
///
/// This is the only screen in the app that turns. `main()` pins everything to
/// portrait; this page asks for landscape while it is up and puts portrait
/// back when it leaves — the same contract youtube_player_flutter follows for
/// its own fullscreen, so both routes return the app to one known state.
///
/// Sizes here are deliberately raw logical pixels rather than ScreenUtil's
/// `.w`/`.h`. Those scale against a 440x956 portrait design; in landscape the
/// axes swap and the controls come out stretched on one and squashed on the
/// other.
class FullscreenVideoPage extends StatefulWidget {
  final VideoPlayerController controller;
  final double playbackSpeed;
  final ValueChanged<double> onSpeedChanged;

  const FullscreenVideoPage({
    super.key,
    required this.controller,
    required this.playbackSpeed,
    required this.onSpeedChanged,
  });

  @override
  State<FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<FullscreenVideoPage> {
  late double _speed;
  static const List<double> _speedOptions = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  static const Color _kPrimary = Color(0xFF87986B);

  @override
  void initState() {
    super.initState();
    _speed = widget.playbackSpeed;

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // The status and navigation bars would otherwise sit over a video already
    // using the whole screen. Sticky, so a stray swipe brings them back
    // briefly rather than for good.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    // Restored here rather than at the pop site, so the close button, a back
    // gesture and a route removed from underneath all land the same way.
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _setSpeed(double speed) async {
    await widget.controller.setPlaybackSpeed(speed);
    if (!mounted) return;
    setState(() => _speed = speed);
    widget.onSpeedChanged(speed);
  }

  void _openSpeedSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          // In landscape the sheet has little height to work with, and six
          // options plus a title do not fit. Scrolling beats clipping.
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 14),
                const Text(
                  'Playback speed',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15),
                ),
                const SizedBox(height: 6),
                for (final speed in _speedOptions)
                  ListTile(
                    dense: true,
                    onTap: () {
                      Navigator.pop(ctx);
                      _setSpeed(speed);
                    },
                    title: Text(
                      speed == 1.0 ? '1x (Normal)' : '${speed}x',
                      style: TextStyle(
                        color: speed == _speed ? _kPrimary : Colors.white,
                        fontWeight:
                            speed == _speed ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                    trailing: speed == _speed
                        ? const Icon(Icons.check_rounded, color: _kPrimary)
                        : null,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  static const TextStyle _timeStyle = TextStyle(
    color: Colors.white,
    fontSize: 12,
    // Fixed-width digits, so the scrubber does not shift as the clock runs.
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static String _clock(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final minutes = two(d.inMinutes.remainder(60));
    final seconds = two(d.inSeconds.remainder(60));
    return d.inHours > 0 ? '${d.inHours}:$minutes:$seconds' : '$minutes:$seconds';
  }

  Widget _pill({required Widget child, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(20),
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // The video itself, letterboxed inside whatever the screen is.
          Center(
            child: ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: widget.controller,
              builder: (context, value, _) {
                // A controller that is not ready yet reports an aspectRatio
                // of 1.0, which shows the video as a square until the first
                // frame lands. 16:9 is the honest guess in the meantime.
                final ratio = value.isInitialized && value.aspectRatio > 0
                    ? value.aspectRatio
                    : 16 / 9;
                return AspectRatio(
                  aspectRatio: ratio,
                  child: VideoPlayer(widget.controller),
                );
              },
            ),
          ),

          // One SafeArea around every control. Each used to be a Positioned
          // with a SafeArea *inside* it, which applied the full screen inset
          // as padding on top of an offset already measured from the screen
          // edge — so in landscape, where the notch is on one side, both
          // buttons sat in the wrong place.
          SafeArea(
            child: Stack(
              children: [
                // Minimise, not a close X. This returns to the lesson page
                // with the same controller still playing, so it is a change
                // of size rather than the end of the video — and the icon
                // should say so.
                Align(
                  alignment: Alignment.topLeft,
                  child: _pill(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.fullscreen_exit_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
                Align(
                  alignment: Alignment.topRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ValueListenableBuilder<VideoPlayerValue>(
                        valueListenable: widget.controller,
                        builder: (context, value, _) => _pill(
                          onTap: () => widget.controller
                              .setVolume(value.volume > 0 ? 0 : 1),
                          child: Icon(
                            value.volume > 0
                                ? Icons.volume_up_rounded
                                : Icons.volume_off_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      _pill(
                        onTap: _openSpeedSelector,
                        child: Text(
                          _speed == 1.0 ? '1x' : '${_speed}x',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

                // Scrubber and clock. Fullscreen had neither, so there was no
                // way to seek or to see how much was left without minimising.
                Align(
                  alignment: Alignment.bottomCenter,
                  child: ValueListenableBuilder<VideoPlayerValue>(
                    valueListenable: widget.controller,
                    builder: (context, value, _) {
                      final total = value.duration.inMilliseconds.toDouble();
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: Row(
                          children: [
                            Text(_clock(value.position),
                                style: _timeStyle),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 6),
                                  overlayShape: const RoundSliderOverlayShape(
                                      overlayRadius: 12),
                                  activeTrackColor: Colors.white,
                                  inactiveTrackColor: Colors.white24,
                                  thumbColor: Colors.white,
                                ),
                                child: Slider(
                                  min: 0,
                                  // A zero duration before the video is ready
                                  // would make max == min, which Slider
                                  // asserts on.
                                  max: total.clamp(1, double.infinity),
                                  value: value.position.inMilliseconds
                                      .toDouble()
                                      .clamp(0, total.clamp(1, double.infinity)),
                                  onChanged: (v) => widget.controller
                                      .seekTo(Duration(milliseconds: v.toInt())),
                                ),
                              ),
                            ),
                            Text(_clock(value.duration), style: _timeStyle),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                // Bound to the controller, so the icon follows the video. It
                // used to flip only on tap, and so read "pause" for a video
                // that had already finished.
                Align(
                  alignment: Alignment.center,
                  child: ValueListenableBuilder<VideoPlayerValue>(
                    valueListenable: widget.controller,
                    builder: (context, value, _) => IconButton(
                      iconSize: 56,
                      icon: Icon(
                        value.isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                        color: Colors.white,
                      ),
                      onPressed: () => value.isPlaying
                          ? widget.controller.pause()
                          : widget.controller.play(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
