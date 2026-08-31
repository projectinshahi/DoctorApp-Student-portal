package com.keerthana.dr_app

import android.content.Context
import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import java.util.function.Consumer

/**
 * Tells Flutter when the screen is being recorded.
 *
 * Blocking the recording is already handled elsewhere: FLAG_SECURE, set by
 * the no_screenshot plugin, blanks captured frames, so a recording of this
 * app comes out solid black. What FLAG_SECURE cannot do is say that a
 * recording started — which is what the on-screen warning needs.
 *
 * Requires Android 15 (API 35). Below that the platform exposes no such
 * signal at all: those devices still get the black recording, just no
 * message. That is a real gap, not an oversight.
 */
class MainActivity : FlutterActivity() {

    private companion object {
        const val CHANNEL = "dr_app/screen_recording"
        const val MIN_SDK_FOR_CALLBACK = 35
    }

    private var events: EventChannel.EventSink? = null
    private var callback: Consumer<Int>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    events = sink
                    registerCallback()
                }

                override fun onCancel(arguments: Any?) {
                    unregisterCallback()
                    events = null
                }
            }
        )
    }

    /**
     * `addScreenRecordingCallback` returns the state at the moment of
     * registration, so the very first value is delivered here rather than
     * needing a separate query — the callback itself only fires on change,
     * and a recording may already have been running when this screen opened.
     */
    private fun registerCallback() {
        if (Build.VERSION.SDK_INT < MIN_SDK_FOR_CALLBACK || callback != null) return

        val manager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val consumer = Consumer<Int> { state ->
            events?.success(state == WindowManager.SCREEN_RECORDING_STATE_VISIBLE)
        }
        callback = consumer

        try {
            val current = manager.addScreenRecordingCallback(mainExecutor, consumer)
            events?.success(current == WindowManager.SCREEN_RECORDING_STATE_VISIBLE)
        } catch (e: SecurityException) {
            // DETECT_SCREEN_RECORDING missing or refused by the platform. The
            // recording is still blank; the app just cannot say so. Reporting
            // "not recording" is the safe reading — never claim a recording
            // that is not happening.
            callback = null
            events?.success(false)
        }
    }

    private fun unregisterCallback() {
        if (Build.VERSION.SDK_INT < MIN_SDK_FOR_CALLBACK) return
        val consumer = callback ?: return
        val manager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        manager.removeScreenRecordingCallback(consumer)
        callback = null
    }

    override fun onDestroy() {
        unregisterCallback()
        super.onDestroy()
    }
}
