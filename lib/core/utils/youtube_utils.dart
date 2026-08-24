/// Detects YouTube URLs and extracts the video ID, so the detail screen
/// can route to a YouTube-specific player instead of ExoPlayer, which
/// cannot play YouTube page URLs (they're HTML, not a raw video stream).
class YoutubeUtils {
  static bool isYoutubeUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('youtube.com') || lower.contains('youtu.be');
  }

  static String? extractVideoId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    // youtu.be/VIDEO_ID
    if (uri.host.contains('youtu.be')) {
      final segments = uri.pathSegments;
      return segments.isNotEmpty ? segments.first : null;
    }

    // youtube.com/watch?v=VIDEO_ID
    if (uri.queryParameters.containsKey('v')) {
      return uri.queryParameters['v'];
    }

    // youtube.com/embed/VIDEO_ID or /shorts/VIDEO_ID
    final segments = uri.pathSegments;
    if (segments.length >= 2 && (segments[0] == 'embed' || segments[0] == 'shorts')) {
      return segments[1];
    }

    return null;
  }
}