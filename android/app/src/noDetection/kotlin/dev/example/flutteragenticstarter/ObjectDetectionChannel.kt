package dev.example.flutteragenticstarter

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

internal class ObjectDetectionChannel(
    @Suppress("UNUSED_PARAMETER") context: Context,
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, "seemate/object_detection")

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "detect" -> result.error("model_unavailable", null, null)
                "dispose" -> result.success(null)
                else -> result.notImplemented()
            }
        }
    }

    fun close() {
        channel.setMethodCallHandler(null)
    }
}
