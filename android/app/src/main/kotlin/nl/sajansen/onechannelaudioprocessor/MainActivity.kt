package nl.sajansen.onechannelaudioprocessor

import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val VOLUME_EVENT_CHANNEL = "nl.sajansen.onechannelaudioprocessor/volume_keys"
    private val VOLUME_METHOD_CHANNEL = "nl.sajansen.onechannelaudioprocessor/volume_control"

    private var eventSink: EventChannel.EventSink? = null
    private var interceptVolume = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // EventChannel for broadcasting key presses
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, VOLUME_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })

        // MethodChannel for toggling interception ON/OFF
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VOLUME_METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "setIntercept") {
                    interceptVolume = call.arguments as Boolean
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (interceptVolume) {
            when (keyCode) {
                KeyEvent.KEYCODE_VOLUME_UP -> {
                    eventSink?.success("UP")
                    return true
                }

                KeyEvent.KEYCODE_VOLUME_DOWN -> {
                    eventSink?.success("DOWN")
                    return true
                }
            }
        }
        return super.onKeyDown(keyCode, event)
    }

    override fun onKeyUp(keyCode: Int, event: KeyEvent?): Boolean {
        if (interceptVolume) {
            when (keyCode) {
                KeyEvent.KEYCODE_VOLUME_UP, KeyEvent.KEYCODE_VOLUME_DOWN -> return true
            }
        }
        return super.onKeyUp(keyCode, event)
    }
}