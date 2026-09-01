import 'package:dr_app/core/utils/capture_watch.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = EventChannel('dr_app/screen_recording');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// Pushes a value up the EventChannel the way the platform would.
  Future<void> emit(dynamic value) async {
    await messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeSuccessEnvelope(value),
      (_) {},
    );
  }

  setUp(() {
    CaptureWatch.instance.stop();
    messenger.setMockStreamHandler(
      channel,
      MockStreamHandler.inline(onListen: (arguments, sink) {}),
    );
    CaptureWatch.instance.start();
  });

  tearDown(() {
    CaptureWatch.instance.stop();
    messenger.setMockStreamHandler(channel, null);
  });

  test('a capture raises the flag, and ending it lowers it again', () async {
    expect(CaptureWatch.instance.isCapturing.value, isFalse);

    await emit(true);
    expect(CaptureWatch.instance.isCapturing.value, isTrue);

    await emit(false);
    expect(CaptureWatch.instance.isCapturing.value, isFalse);
  });

  test('listeners are notified, which is what stops playback', () async {
    var fired = 0;
    void listener() => fired++;
    CaptureWatch.instance.isCapturing.addListener(listener);
    addTearDown(() => CaptureWatch.instance.isCapturing.removeListener(listener));

    await emit(true);

    // The video player pauses off this notification. Without it the audio
    // keeps playing behind the black cover and the recording gets the
    // whole soundtrack.
    expect(fired, 1);
    expect(CaptureWatch.instance.isCapturing.value, isTrue);
  });

  test('a platform that cannot answer is not a platform that is recording',
      () async {
    await emit(true);
    expect(CaptureWatch.instance.isCapturing.value, isTrue);

    // Anything that is not exactly `true` means no capture. Treating an
    // unexpected payload as "capturing" would black out the app for good.
    await emit(null);
    expect(CaptureWatch.instance.isCapturing.value, isFalse);
  });

  test('start is idempotent, so a hot restart does not double-subscribe',
      () async {
    CaptureWatch.instance.start();
    CaptureWatch.instance.start();

    await emit(true);
    expect(CaptureWatch.instance.isCapturing.value, isTrue);
  });
}
