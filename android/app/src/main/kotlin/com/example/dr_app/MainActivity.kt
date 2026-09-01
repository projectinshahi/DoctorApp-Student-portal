package com.keerthana.dr_app

import android.content.Context
import android.hardware.display.DisplayManager
import android.os.Build
import android.view.Display
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import java.util.function.Consumer

/**
 * Tells Flutter when the screen is being captured — recorded, cast, or
 * mirrored to another display.
 *
 * Blocking the capture is handled elsewhere: FLAG_SECURE, set by the
 * no_screenshot plugin, blanks captured frames, so a recording of this app
 * comes out solid black. What FLAG_SECURE cannot do is *say* that a capture
 * started, which is what stopping playback and warning the student need.
 *
 * Two independent signals feed one boolean:
 *
 *  * **Recording** — `addScreenRecordingCallback`, Android 15 (API 35) and
 *    up. Below that the platform exposes no recording signal at all: those
 *    devices still get blank frames, just no message and no pause. A real
 *    gap, and not one the app can close.
 *
 *  * **Mirroring / casting** — a presentation display, from `DisplayManager`,
 *    on every supported version. This is the half that works everywhere, and
 *    it is what catches a phone plugged into a projector.
 */
class MainActivity : FlutterActivity() {

    private companion object {
        const val CHANNEL = "dr_app/screen_recording"
        const val MIN_SDK_FOR_CALLBACK = 35
    }

    private var events: EventChannel.EventSink? = null
    private var recordingCallback: Consumer<Int>? = null
    private var displayListener: DisplayManager.DisplayListener? = null

    private var isRecording = false
    private var isMirroring = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    events = sink
                    registerRecording()
                    registerDisplays()
                }

                override fun onCancel(arguments: Any?) {
                    unregisterRecording()
                    unregisterDisplays()
                    events = null
                }
            }
        )
    }

    /** Either signal is enough to hide the content, so they OR together. */
    private fun emit() {
        events?.success(isRecording || isMirroring)
    }

    // ── Recording (API 35+) ──────────────────────────────────────
    /**
     * `addScreenRecordingCallback` returns the state at the moment of
     * registration, so the very first value is delivered here rather than
     * needing a separate query — the callback itself only fires on change,
     * and a recording may already have been running when the app opened.
     */
    private fun registerRecording() {
        if (Build.VERSION.SDK_INT < MIN_SDK_FOR_CALLBACK || recordingCallback != null) return

        val manager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val consumer = Consumer<Int> { state ->
            isRecording = state == WindowManager.SCREEN_RECORDING_STATE_VISIBLE
            emit()
        }
        recordingCallback = consumer

        try {
            val current = manager.addScreenRecordingCallback(mainExecutor, consumer)
            isRecording = current == WindowManager.SCREEN_RECORDING_STATE_VISIBLE
            emit()
        } catch (e: SecurityException) {
            // DETECT_SCREEN_RECORDING missing or refused by the platform. The
            // recording is still blank; the app just cannot say so. Reporting
            // "not recording" is the safe reading — never claim a recording
            // that is not happening.
            recordingCallback = null
            isRecording = false
            emit()
        }
    }

    private fun unregisterRecording() {
        if (Build.VERSION.SDK_INT < MIN_SDK_FOR_CALLBACK) return
        val consumer = recordingCallback ?: return
        val manager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        manager.removeScreenRecordingCallback(consumer)
        recordingCallback = null
    }

    // ── Mirroring / casting (all versions) ───────────────────────
    /**
     * A presentation display is a second screen the system is driving — Cast,
     * a wireless dongle, or an HDMI cable. Available on every supported
     * version, which makes it the only capture signal older devices have.
     */
    private fun mirroringNow(manager: DisplayManager): Boolean =
        manager.getDisplays(DisplayManager.DISPLAY_CATEGORY_PRESENTATION).any {
            it.state != Display.STATE_OFF
        }

    private fun registerDisplays() {
        if (displayListener != null) return

        val manager = getSystemService(Context.DISPLAY_SERVICE) as DisplayManager

        val listener = object : DisplayManager.DisplayListener {
            private fun refresh() {
                isMirroring = mirroringNow(manager)
                emit()
            }

            override fun onDisplayAdded(displayId: Int) = refresh()
            override fun onDisplayRemoved(displayId: Int) = refresh()
            override fun onDisplayChanged(displayId: Int) = refresh()
        }
        displayListener = listener
        manager.registerDisplayListener(listener, null)

        // A projector already plugged in when the app opened fires no event.
        isMirroring = mirroringNow(manager)
        emit()
    }

    private fun unregisterDisplays() {
        val listener = displayListener ?: return
        val manager = getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        manager.unregisterDisplayListener(listener)
        displayListener = null
    }

    override fun onDestroy() {
        unregisterRecording()
        unregisterDisplays()
        super.onDestroy()
    }
}
