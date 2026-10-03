// lib/widget/question_image.dart
//
// A question's image, wherever a question is drawn: the test paper, the
// review of it, the daily quiz.
//
// One copy because the three had grown their own, and they had already
// drifted — only the paper's version opened full screen, so the same ECG was
// zoomable while answering and a 90px thumbnail while reading the answer.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'app_loading.dart';

class QuestionImage extends StatelessWidget {
  final String url;

  /// How tall the spinner stands while the image downloads. The image itself
  /// is unconstrained — a tall ECG strip is not cropped to a square.
  final double? loadingHeight;

  const QuestionImage({super.key, required this.url, this.loadingHeight});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // The answer often lives in a detail — an ECG lead, one cell on a
      // slide — that is unreadable at column width.
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => _FullScreenImage(url: url),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: Image.network(
          url,
          fit: BoxFit.contain,
          // Decoded at the width it is actually drawn at. These are teaching
          // infographics exported at print size; decoding one at full size
          // costs seconds of frame time and tens of megabytes, and the pixels
          // beyond the phone's screen are thrown away regardless. Full
          // resolution is still there in the full-screen view, which is the
          // one place it can be seen.
          cacheWidth: (MediaQuery.sizeOf(context).width *
                  MediaQuery.devicePixelRatioOf(context))
              .round(),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            _logSize(progress.expectedTotalBytes);
            return AppLoading(height: loadingHeight ?? 160.h);
          },
          // A missing image must not take the question down with it — the
          // student can still read the options and answer.
          errorBuilder: (context, _, __) => Container(
            height: 90.h,
            alignment: Alignment.center,
            color: Colors.grey.shade200,
            child: Text('Image unavailable',
                style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600)),
          ),
        ),
      ),
    );
  }
}

/// Says how heavy an image is, once, in debug builds.
///
/// A slow image is either a slow download or a slow decode, and the fix is in
/// a different place for each — a smaller file on the server, or a smaller
/// decode here. The number says which.
final Set<int> _loggedSizes = {};

void _logSize(int? bytes) {
  if (!kDebugMode || bytes == null || !_loggedSizes.add(bytes)) return;
  debugPrint('QUESTION IMAGE  ${(bytes / 1024).round()} KB');
}

/// The image on its own, on black, pinch to zoom.
class _FullScreenImage extends StatelessWidget {
  final String url;

  const _FullScreenImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Center(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (context, _, __) => Text('Image unavailable',
                      style: TextStyle(fontSize: 13.sp, color: Colors.white70)),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8.h,
            right: 8.w,
            child: IconButton(
              onPressed: () => Navigator.maybePop(context),
              icon: Icon(Icons.close_rounded, size: 28.sp, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
