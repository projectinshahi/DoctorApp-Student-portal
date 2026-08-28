import 'dart:async';
import 'package:dr_app/view/Home/lessons/videoplay/FullscreenVideoPage.dart';
import 'package:dr_app/view/Home/lessons/videoplay/PdfViewerModal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../../core/utils/youtube_utils.dart';
import '../../../models/selection_content_model.dart';
import '../../../repository/saved_provider.dart';
import '../../../repository/selection_content_provider.dart';
import '../../../widget/pro_plan_dialog.dart';
import '../Qbank/quiz_screen.dart';    // adjust path to wherever you place this file

class StudentLessonDetailScreen extends StatefulWidget {
  final StudentLessonModel lesson;
  final List<StudentLessonModel> relatedLessons;

  const StudentLessonDetailScreen({
    super.key,
    required this.lesson,
    this.relatedLessons = const [],
  });

  @override
  State<StudentLessonDetailScreen> createState() => _StudentLessonDetailScreenState();
}

class _StudentLessonDetailScreenState extends State<StudentLessonDetailScreen> {
  static const Color kPrimary = Color(0xFF87986B);
  static const Color kBg = Color(0xFFEFF4E2);

  // ── Regular (Cloudinary/direct-file) video state ──
  VideoPlayerController? _controller;
  bool _isInitializing = false;
  String? _error;
  bool _started = false;
  bool _isMuted = false;
  bool _showControls = true;
  Timer? _hideControlsTimer;
  int _videoRetryCount = 0;
  static const int _maxVideoRetries = 3;

  // ── Playback speed state ──
  // NOTE: setPlaybackSpeed() takes effect immediately on the running
  // controller - it does NOT pause, seek, or restart playback, which is
  // exactly what satisfies "Speed changes apply immediately without
  // restarting playback".
  double _playbackSpeed = 1.0;
  static const List<double> _speedOptions = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  // ── YouTube-specific state ──
  YoutubePlayerController? _ytController;
  bool _isYoutube = false;

  late StudentLessonModel _lesson;

  @override
  void initState() {
    super.initState();
    _lesson = widget.lesson;
    // A locked lesson never touches the player: build() hands the whole screen
    // to the paywall instead, the same way the quiz screen does.
    if (_lesson.locked) return;
    if (_lesson.hasVideo && _lesson.videoUrl != null && _lesson.videoUrl!.isNotEmpty) {
      _setupVideo();
    }
  }

  /// Called after a successful subscribe. The plans screen already awaits a
  /// full SelectionContentProvider reload before it pops, so the unlocked
  /// lesson — videoUrl and all — is already in the tree; the copy this screen
  /// holds is the stale, stripped one. Swap it in instead of re-fetching.
  void _reloadUnlockedLesson() {
    if (!mounted) return;
    final lessons = context.read<SelectionContentProvider>().content?.allLessons ??
        const <StudentLessonModel>[];
    final index = lessons.indexWhere((l) => l.id == _lesson.id);

    // Still locked (or gone) means the plan they bought doesn't cover this
    // lesson. Leave, so the list behind re-renders with the access that is
    // now real rather than stranding them on a paywall they just paid past.
    if (index == -1 || lessons[index].locked) {
      Navigator.pop(context, true);
      return;
    }
    _switchToLesson(lessons[index]);
  }

  void _setupVideo() {
    final url = _lesson.videoUrl;
    if (url == null || url.isEmpty) return;

    if (YoutubeUtils.isYoutubeUrl(url)) {
      final videoId = YoutubeUtils.extractVideoId(url);
      if (videoId == null) {
        setState(() {
          _isYoutube = true;
          _error = 'Could not read this YouTube link.';
        });
        return;
      }
      setState(() => _isYoutube = true);
      _ytController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
        ),
      );
    } else {
      setState(() => _isYoutube = false);
      _initVideo();
    }
  }

  Future<void> _initVideo({bool isRetry = false}) async {
    _controller?.dispose();
    setState(() {
      _controller = null;
      _isInitializing = true;
      _error = null;
      _started = false;
      _playbackSpeed = 1.0; // reset speed for a fresh video
    });

    if (!isRetry) _videoRetryCount = 0;

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(_lesson.videoUrl!));
      await controller.initialize();
      controller.addListener(() {
        if (mounted) setState(() {});
      });
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _isInitializing = false;
        _videoRetryCount = 0;
      });
    } catch (e) {
      if (!mounted) return;

      final errorText = e.toString();
      final isRateLimited = errorText.contains('429');
      final isBadFormat = errorText.contains('UnrecognizedInputFormatException') ||
          errorText.contains('NoDeclaredBrand');

      if (isRateLimited && _videoRetryCount < _maxVideoRetries) {
        _videoRetryCount++;
        final delaySeconds = _videoRetryCount * 2;
        setState(() => _error = 'Video server is busy - retrying in $delaySeconds s...');
        await Future.delayed(Duration(seconds: delaySeconds));
        if (!mounted) return;
        _initVideo(isRetry: true);
        return;
      }

      setState(() {
        if (isRateLimited) {
          _error = 'The video server is currently busy. Please try again shortly.';
        } else if (isBadFormat) {
          _error = 'This video link isn\'t a playable video file.';
        } else {
          _error = 'Failed to load video.';
        }
        _isInitializing = false;
      });
    }
  }

  /// Applies a new playback speed to the currently-running controller.
  /// Called directly on the live VideoPlayerController - never disposes
  /// or re-initializes anything, so playback continues uninterrupted
  /// from the exact same position, just faster/slower.
  Future<void> _setPlaybackSpeed(double speed) async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    await _controller!.setPlaybackSpeed(speed);
    if (!mounted) return;
    setState(() => _playbackSpeed = speed);
    _resetHideTimer();
  }

  void _openSpeedSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36.w,
                  height: 4.h,
                  margin: EdgeInsets.only(bottom: 14.h),
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Playback speed',
                      style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: Colors.black87),
                    ),
                  ),
                ),
                SizedBox(height: 8.h),
                for (final speed in _speedOptions)
                  ListTile(
                    onTap: () {
                      Navigator.pop(ctx);
                      _setPlaybackSpeed(speed);
                    },
                    title: Text(
                      speed == 1.0 ? '1x (Normal)' : '${speed}x',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: speed == _playbackSpeed ? FontWeight.w700 : FontWeight.w400,
                        color: speed == _playbackSpeed ? kPrimary : Colors.black87,
                      ),
                    ),
                    trailing: speed == _playbackSpeed
                        ? Icon(Icons.check_rounded, color: kPrimary, size: 20.sp)
                        : null,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _switchToLesson(StudentLessonModel lesson) {
    setState(() => _lesson = lesson);
    _hideControlsTimer?.cancel();
    _videoRetryCount = 0;
    _playbackSpeed = 1.0;

    _controller?.dispose();
    _controller = null;
    _ytController?.dispose();
    _ytController = null;

    if (lesson.hasVideo && lesson.videoUrl != null && lesson.videoUrl!.isNotEmpty) {
      _setupVideo();
    }
  }

  void _resetHideTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _controller?.value.isPlaying == true) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _resetHideTimer();
  }

  void _togglePlay() {
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _hideControlsTimer?.cancel();
      } else {
        _controller!.play();
        _resetHideTimer();
      }
    });
  }

  void _skipForward() {
    final pos = _controller!.value.position;
    final dur = _controller!.value.duration;
    final target = pos + const Duration(seconds: 10);
    _controller!.seekTo(target > dur ? dur : target);
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _controller!.setVolume(_isMuted ? 0 : 1);
    });
  }

  void _openFullscreen() {
    if (_controller == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullscreenVideoPage(
          controller: _controller!,
          playbackSpeed: _playbackSpeed,
          onSpeedChanged: (s) => setState(() => _playbackSpeed = s),
        ),
      ),
    );
  }

  void _openPdfModal(String pdfUrl, String title) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PdfViewerModal(pdfUrl: pdfUrl, title: title),
    );
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final minutes = two(d.inMinutes.remainder(60));
    final seconds = two(d.inSeconds.remainder(60));
    return d.inHours > 0 ? '${two(d.inHours)}:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  void dispose() {
    _controller?.dispose();
    _ytController?.dispose();
    _hideControlsTimer?.cancel();
    super.dispose();
  }

  Widget _buildYoutubePlayer() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white54, size: 30),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
          ],
        ),
      );
    }
    if (_ytController == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4));
    }
    return YoutubePlayer(
      controller: _ytController!,
      showVideoProgressIndicator: true,
      progressIndicatorColor: kPrimary,
    );
  }

  Widget _buildDirectVideoPlayer() {
    Widget content;

    if (_error != null) {
      content = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white54, size: 30),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.white)),
            TextButton(onPressed: _initVideo, child: const Text('Retry', style: TextStyle(color: Colors.white))),
          ],
        ),
      );
    } else if (_isInitializing || _controller == null || !_controller!.value.isInitialized) {
      content = Stack(
        fit: StackFit.expand,
        children: [
          if (_lesson.thumbnailUrl != null) Image.network(_lesson.thumbnailUrl!, fit: BoxFit.cover),
          Container(color: Colors.black45),
          const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4)),
        ],
      );
    } else if (!_started) {
      content = Stack(
        fit: StackFit.expand,
        children: [
          if (_lesson.thumbnailUrl != null) Image.network(_lesson.thumbnailUrl!, fit: BoxFit.cover),
          Container(color: Colors.black38),
          Center(
            child: GestureDetector(
              onTap: () {
                setState(() => _started = true);
                _controller!.play();
                _resetHideTimer();
              },
              child: Container(
                padding: EdgeInsets.all(16.w),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Icon(Icons.play_arrow_rounded, size: 34.sp, color: kPrimary),
              ),
            ),
          ),
        ],
      );
    } else {
      final value = _controller!.value;
      content = GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: value.size.width,
                height: value.size.height,
                child: VideoPlayer(_controller!),
              ),
            ),
            AnimatedOpacity(
              opacity: _showControls ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_showControls,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black.withOpacity(0.35), Colors.transparent, Colors.black.withOpacity(0.55)],
                      stops: const [0, 0.4, 1],
                    ),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: EdgeInsets.all(6.w),
                                decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                                child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16.sp),
                              ),
                            ),
                            const Spacer(),
                            // ── Speed badge, next to the AI badge ──
                            GestureDetector(
                              onTap: _openSpeedSelector,
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
                                margin: EdgeInsets.only(right: 8.w),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.85),
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                                child: Text(
                                  _playbackSpeed == 1.0 ? '1x' : '${_playbackSpeed}x',
                                  style: TextStyle(fontSize: 10.5.sp, fontWeight: FontWeight.w700, color: kPrimary),
                                ),
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.auto_awesome, size: 11.sp, color: kPrimary),
                                  SizedBox(width: 3.w),
                                  Text('AI', style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w700, color: kPrimary)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: EdgeInsets.fromLTRB(10.w, 0, 10.w, 10.h),
                        child: Column(
                          children: [
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                activeTrackColor: Colors.white,
                                inactiveTrackColor: Colors.white24,
                                thumbColor: Colors.white,
                              ),
                              child: Slider(
                                min: 0,
                                max: value.duration.inMilliseconds.toDouble().clamp(1, double.infinity),
                                value: value.position.inMilliseconds
                                    .toDouble()
                                    .clamp(0, value.duration.inMilliseconds.toDouble()),
                                onChanged: (v) {
                                  _controller!.seekTo(Duration(milliseconds: v.toInt()));
                                  _resetHideTimer();
                                },
                              ),
                            ),
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: _togglePlay,
                                  child: Icon(
                                    value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 26.sp,
                                  ),
                                ),
                                SizedBox(width: 10.w),
                                Text(_formatDuration(value.position), style: TextStyle(color: Colors.white, fontSize: 11.sp)),
                                const Spacer(),
                                // ── Speed control button, next to skip/mute/fullscreen ──
                                GestureDetector(
                                  onTap: _openSpeedSelector,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.white70),
                                      borderRadius: BorderRadius.circular(6.r),
                                    ),
                                    child: Text(
                                      _playbackSpeed == 1.0 ? '1x' : '${_playbackSpeed}x',
                                      style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 14.w),
                                GestureDetector(
                                  onTap: _skipForward,
                                  child: Icon(Icons.fast_forward_rounded, color: Colors.white, size: 20.sp),
                                ),
                                SizedBox(width: 14.w),
                                GestureDetector(
                                  onTap: _toggleMute,
                                  child: Icon(
                                    _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                    color: Colors.white,
                                    size: 20.sp,
                                  ),
                                ),
                                SizedBox(width: 14.w),
                                GestureDetector(
                                  onTap: _openFullscreen,
                                  child: Icon(Icons.fullscreen_rounded, color: Colors.white, size: 22.sp),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return content;
  }

  Widget _buildVideoPlayer() {
    final hasValidVideoUrl = _lesson.videoUrl != null && _lesson.videoUrl!.isNotEmpty;
    if (!_lesson.hasVideo || !hasValidVideoUrl) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            color: Colors.black,
            child: _isYoutube ? _buildYoutubePlayer() : _buildDirectVideoPlayer(),
          ),
        ),
        if (_isYoutube || !_started || _error != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8.h,
            left: 12.w,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: EdgeInsets.all(8.w),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16.sp),
              ),
            ),
          ),
      ],
    );
  }

  // ── Subject / views / duration row, matching the screenshot ──
  Widget _buildMetaRow() {
    final durationText = (!_isYoutube && _controller?.value.isInitialized == true)
        ? _formatDuration(_controller!.value.duration)
        : null;

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 6.h, 20.w, 0),
      child: Row(
        children: [
          if (_lesson.description != null && _lesson.description!.isNotEmpty)
            Text(
              _lesson.description!,
              style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade600),
            ),
          if (durationText != null) ...[
            if (_lesson.description != null && _lesson.description!.isNotEmpty) ...[
              SizedBox(width: 10.w),
              Icon(Icons.circle, size: 4.sp, color: Colors.grey.shade400),
              SizedBox(width: 10.w),
            ],
            Text(durationText, style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade600)),
          ],
        ],
      ),
    );
  }

  // ── "View Notes" full-width button, matching the screenshot ──
  Widget _buildViewNotesButton() {
    final hasValidNoteUrl = _lesson.noteUrl != null && _lesson.noteUrl!.isNotEmpty;
    if (!_lesson.hasNote || !hasValidNoteUrl) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 0),
      child: SizedBox(
        width: double.infinity,
        height: 52.h,
        child: ElevatedButton.icon(
          onPressed: () => _openPdfModal(_lesson.noteUrl!, _lesson.title),
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.r)),
          ),
          icon: Icon(Icons.description_outlined, size: 20.sp),
          label: Text('View Notes', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  // ── Quiz lesson: same full-width card slot the video/notes use ──
  Widget _buildQuizCard() {
    if (!_lesson.isQuiz) return const SizedBox.shrink();

    final count = _lesson.quizQuestionCount;

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 0),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40.w,
                  height: 40.w,
                  decoration: BoxDecoration(
                    color: kPrimary.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(Icons.quiz_rounded, size: 20.sp, color: kPrimary),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MCQ practice',
                        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: Colors.black87),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        // null means "unknown", not "zero" — don't print 0.
                        count == null ? 'Answer and check yourself' : '$count questions',
                        style: TextStyle(fontSize: 11.5.sp, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            SizedBox(
              width: double.infinity,
              height: 48.h,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuizScreen(lessonId: _lesson.id, lessonTitle: _lesson.title),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.r)),
                ),
                icon: Icon(Icons.play_arrow_rounded, size: 20.sp),
                label: Text('Start Quiz', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRelatedVideos() {
    final related = widget.relatedLessons.where((l) => l.id != _lesson.id).toList();
    if (related.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 24.h, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(right: 20.w),
            child: Text('Continue watching', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: Colors.black87)),
          ),
          SizedBox(height: 12.h),
          SizedBox(
            height: 118.h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: related.length,
              separatorBuilder: (_, __) => SizedBox(width: 12.w),
              itemBuilder: (context, index) {
                final item = related[index];
                return GestureDetector(
                  // Locked ones switch in too — build() shows them the
                  // paywall, so there is one locked-lesson screen, not two.
                  onTap: () => _switchToLesson(item),
                  child: SizedBox(
                    width: 160.w,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10.r),
                              child: item.thumbnailUrl != null
                                  ? Image.network(item.thumbnailUrl!, width: 160.w, height: 78.h, fit: BoxFit.cover)
                                  : Container(width: 160.w, height: 78.h, color: kPrimary),
                            ),
                            if (item.hasVideo && !item.locked)
                              Positioned(
                                left: 6,
                                bottom: 6,
                                child: Container(
                                  padding: EdgeInsets.all(4.w),
                                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                                  child: Icon(Icons.play_arrow_rounded, size: 13.sp, color: Colors.white),
                                ),
                              ),
                            if (item.locked)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.45),
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                  child: Icon(Icons.lock_rounded, color: Colors.white, size: 20.sp),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5.sp, fontWeight: FontWeight.w600, color: Colors.black87, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// The locked state, built the same way the quiz screen builds its own:
  /// a plain app bar over a full-screen [ProPlanPaywall], not a dialog thrown
  /// on top of a player that was never allowed to load. Subscribing reloads
  /// the lesson in place, so the video starts here rather than sending them
  /// back to the list to find it again.
  Widget _buildPaywallScreen() {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        foregroundColor: Colors.black87,
        titleSpacing: 0,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: Icon(Icons.chevron_left_rounded, size: 30.sp, color: Colors.black87),
        ),
        title: Text(
          _lesson.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w700, color: Colors.black87),
        ),
      ),
      body: SafeArea(
        child: ProPlanPaywall(
          message: 'This video is available for pro users of this course. '
              'Want to check Pro plans?',
          onSubscribed: _reloadUnlockedLesson,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Locked lesson → the paywall owns the screen, same model as the quiz.
    if (_lesson.locked) return _buildPaywallScreen();

    final hasValidVideoUrl = _lesson.videoUrl != null && _lesson.videoUrl!.isNotEmpty;
    final isVideoAvailable = _lesson.hasVideo && hasValidVideoUrl;

    return Scaffold(
      backgroundColor: kBg,
      appBar: !isVideoAvailable
          ? AppBar(
        backgroundColor: kBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Lesson Details',
          style: TextStyle(color: Colors.black87, fontSize: 16.sp, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      )
          : null,
      body: SafeArea(
        top: !isVideoAvailable,
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildVideoPlayer(),

              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        _lesson.title,
                        style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w800, color: Colors.black, height: 1.3),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      // Was a local setState that died with the screen.
                      // Now /saved-lessons, so it survives the app closing
                      // and follows the account to another device.
                      child: GestureDetector(
                        onTap: () =>
                            context.read<SavedProvider>().toggleLesson(_lesson.id),
                        child: Icon(
                          context.watch<SavedProvider>().isLessonSaved(_lesson.id)
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: kPrimary,
                          size: 20.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              _buildMetaRow(),
              _buildQuizCard(),
              _buildViewNotesButton(),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                child: Divider(color: Colors.grey.shade300, height: 1),
              ),

              _buildRelatedVideos(),

              SizedBox(height: 30.h),
            ],
          ),
        ),
      ),
    );
  }
}