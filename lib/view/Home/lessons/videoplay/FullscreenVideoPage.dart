import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:video_player/video_player.dart';

/// Fullscreen page for direct (non-YouTube) video playback, with a
/// playback-speed selector. Renamed from the original private
/// `_FullscreenVideoPage` to a public class so it can be imported and used
/// from `student_lesson_detail_screen.dart`.
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

  @override
  void initState() {
    super.initState();
    _speed = widget.playbackSpeed;
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 14.h),
              Text('Playback speed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15.sp)),
              const SizedBox(height: 6),
              for (final speed in _speedOptions)
                ListTile(
                  onTap: () {
                    Navigator.pop(ctx);
                    _setSpeed(speed);
                  },
                  title: Text(
                    speed == 1.0 ? '1x (Normal)' : '${speed}x',
                    style: TextStyle(
                      color: speed == _speed ? const Color(0xFF87986B) : Colors.white,
                      fontWeight: speed == _speed ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                  trailing: speed == _speed ? const Icon(Icons.check_rounded, color: Color(0xFF87986B)) : null,
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: widget.controller.value.aspectRatio,
              child: VideoPlayer(widget.controller),
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: SafeArea(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20)),
                  child: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: SafeArea(
              child: GestureDetector(
                onTap: _openSpeedSelector,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    _speed == 1.0 ? '1x' : '${_speed}x',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: IconButton(
              icon: Icon(
                widget.controller.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                color: Colors.white,
                size: 56.sp,
              ),
              onPressed: () {
                setState(() {
                  widget.controller.value.isPlaying ? widget.controller.pause() : widget.controller.play();
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}