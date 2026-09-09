import 'package:dr_app/view/Home/lessons/videoplay/FullscreenVideoPage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';

/// Records what the app asks the platform to do with the screen.
///
/// The orientation calls are the whole feature and they leave no trace in the
/// widget tree — the only way to check them is at the channel.
class _Chrome {
  final orientations = <List<String>>[];
  final uiModes = <String>[];

  void install(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          orientations.add(List<String>.from(call.arguments as List));
        }
        if (call.method == 'SystemChrome.setEnabledSystemUIMode') {
          uiModes.add(call.arguments.toString());
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
  }
}

void main() {
  testWidgets('fullscreen turns landscape, and leaving turns it back',
      (tester) async {
    final chrome = _Chrome()..install(tester);

    // A controller over a url nothing serves: it never initialises, which is
    // also the state the page has to render on its first frame.
    final controller =
        VideoPlayerController.networkUrl(Uri.parse('https://x/v.mp4'));
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: FullscreenVideoPage(
        controller: controller,
        playbackSpeed: 1.0,
        onSpeedChanged: (_) {},
      ),
    ));

    expect(chrome.orientations.single,
        ['DeviceOrientation.landscapeLeft', 'DeviceOrientation.landscapeRight']);
    expect(chrome.uiModes.single, contains('immersiveSticky'));

    // An uninitialised controller reports 1.0; showing the video as a square
    // until the first frame is the bug the 16:9 guess avoids.
    expect(tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio,
        16 / 9);

    // Leaving must put portrait back, or the whole app stays rotated.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();

    expect(chrome.orientations.last, ['DeviceOrientation.portraitUp']);
    expect(chrome.uiModes.last, contains('edgeToEdge'));
  });

  testWidgets('every control sits inside one SafeArea', (tester) async {
    // Each used to carry its own SafeArea *inside* a Positioned, which
    // double-counted the inset and put the buttons in the wrong place in
    // landscape, where the notch is on one side.
    final controller =
        VideoPlayerController.networkUrl(Uri.parse('https://x/v.mp4'));
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: FullscreenVideoPage(
        controller: controller,
        playbackSpeed: 1.0,
        onSpeedChanged: (_) {},
      ),
    ));

    expect(find.byType(SafeArea), findsOneWidget);
    for (final icon in [
      // Minimise, not close: it returns to the lesson with the same
      // controller still playing.
      Icons.fullscreen_exit_rounded,
      Icons.volume_up_rounded,
    ]) {
      expect(
        find.descendant(
            of: find.byType(SafeArea), matching: find.byIcon(icon)),
        findsOneWidget,
        reason: '$icon must sit inside the one SafeArea',
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('the scrubber survives a video whose duration is not known yet',
      (tester) async {
    // An uninitialised controller reports Duration.zero, and a Slider whose
    // max equals its min asserts. This is the state of the very first frame.
    final controller =
        VideoPlayerController.networkUrl(Uri.parse('https://x/v.mp4'));
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: FullscreenVideoPage(
        controller: controller,
        playbackSpeed: 1.0,
        onSpeedChanged: (_) {},
      ),
    ));

    expect(find.byType(Slider), findsOneWidget);
    // Elapsed and total, so there is no need to minimise to see how much is
    // left — fullscreen had no clock at all before.
    expect(find.text('00:00'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
