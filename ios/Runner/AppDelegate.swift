import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// The same channel name the Android side uses, so Dart has one stream.
  private static let screenRecordingChannel = "dr_app/screen_recording"

  private var recordingEvents: FlutterEventSink?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterEventChannel(
      name: AppDelegate.screenRecordingChannel,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setStreamHandler(self)
  }

  /// True while the screen is being recorded OR mirrored to another display.
  ///
  /// iOS has no FLAG_SECURE, so unlike Android this signal is the whole
  /// defence for video: the app cannot stop a recording, only notice one and
  /// cover what it is showing.
  @objc private func captureStateChanged() {
    recordingEvents?(UIScreen.main.isCaptured)
  }
}

extension AppDelegate: FlutterStreamHandler {
  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    recordingEvents = events

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(captureStateChanged),
      name: UIScreen.capturedDidChangeNotification,
      object: nil
    )

    // Deliver the current state at once: the notification only fires on a
    // change, and a recording may already have been running.
    events(UIScreen.main.isCaptured)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    NotificationCenter.default.removeObserver(
      self,
      name: UIScreen.capturedDidChangeNotification,
      object: nil
    )
    recordingEvents = nil
    return nil
  }
}
