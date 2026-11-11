package dev.example.flutteragenticstarter

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

internal class VoiceCommandChannel(
    @Suppress("UNUSED_PARAMETER") context: Context,
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, "seemate/voice_commands")

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isOfflineAvailable" -> result.success(false)
                "listen" -> result.success(mapOf("status" to "unavailable"))
                "stop", "dispose" -> result.success(null)
                else -> result.notImplemented()
            }
        }
    }

    fun close() {
        channel.setMethodCallHandler(null)
    }
}
