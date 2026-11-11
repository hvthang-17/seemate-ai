package dev.example.flutteragenticstarter

import android.content.Context
import android.media.AudioAttributes
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.speech.tts.Voice
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

internal class SpeechChannel(context: Context, messenger: BinaryMessenger) {
    private val appContext = context.applicationContext
    private val channel = MethodChannel(messenger, "seemate/speech")
    private val main = Handler(Looper.getMainLooper())
    private val engineWaiters = mutableListOf<(TextToSpeech?) -> Unit>()
    private var engine: TextToSpeech? = null
    private var initializing = false
    private var initializationTimeout: Runnable? = null
    private var pending: PendingSpeech? = null
    private var playback: Playback? = null

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkVoiceReadiness" -> withEngine { tts -> result.success(readiness(tts)) }
                "speak" -> speak(call, result)
                "stop" -> if (interrupt()) {
                    result.success(null)
                } else {
                    result.error("speech_stop_failed", null, null)
                }
                "dispose" -> {
                    releaseEngine()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    fun close() {
        channel.setMethodCallHandler(null)
        releaseEngine()
    }

    private fun withEngine(use: (TextToSpeech?) -> Unit) {
        val existing = engine
        if (existing != null && !initializing) {
            use(existing)
            return
        }
        engineWaiters.add(use)
        if (initializing) return

        initializing = true
        try {
            lateinit var candidate: TextToSpeech
            candidate = TextToSpeech(appContext) { status ->
                main.post { finishInitialization(candidate, status) }
            }
            engine = candidate
            val timeout = Runnable { finishInitialization(candidate, TextToSpeech.ERROR) }
            initializationTimeout = timeout
            main.postDelayed(timeout, 5_000)
        } catch (_: RuntimeException) {
            initializing = false
            completeWaiters(null)
        }
    }

    private fun finishInitialization(candidate: TextToSpeech, status: Int) {
        if (engine !== candidate || !initializing) return
        initializationTimeout?.let(main::removeCallbacks)
        initializationTimeout = null
        initializing = false

        val ready = status == TextToSpeech.SUCCESS && runCatching {
            candidate.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ASSISTANCE_ACCESSIBILITY)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build(),
            )
            candidate.setOnUtteranceProgressListener(progressListener) == TextToSpeech.SUCCESS
        }.getOrDefault(false)
        if (!ready) {
            engine = null
            runCatching { candidate.shutdown() }
        }
        completeWaiters(engine)
    }

    private fun completeWaiters(tts: TextToSpeech?) {
        val waiters = engineWaiters.toList()
        engineWaiters.clear()
        waiters.forEach { it(tts) }
    }

    private fun installedVietnameseVoice(voices: Set<Voice>): Voice? = voices
        .filter {
            it.locale.language == "vi" && it.locale.country == "VN" &&
                !it.isNetworkConnectionRequired &&
                TextToSpeech.Engine.KEY_FEATURE_NOT_INSTALLED !in it.features.orEmpty()
        }
        .sortedWith(compareByDescending<Voice> { it.quality }.thenBy { it.latency }.thenBy { it.name })
        .firstOrNull()

    private fun readiness(tts: TextToSpeech?): Map<String, Any?> {
        val voices = runCatching { tts?.voices.orEmpty() }.getOrDefault(emptySet())
        val voice = installedVietnameseVoice(voices)
        return mapOf(
            "available" to (voice != null || voices.any {
                it.locale.language == "vi" && it.locale.country == "VN" && it.isNetworkConnectionRequired
            }),
            "offline" to (voice != null),
            "engineName" to runCatching { tts?.defaultEngine }.getOrNull(),
            "voiceName" to voice?.name,
        )
    }

    private fun speak(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id")
        val text = call.argument<String>("text")
        val rate = call.argument<Double>("rate")
        if (id.isNullOrEmpty() || text.isNullOrBlank() || rate == null || rate !in 0.5..2.0 ||
            pending != null || playback != null
        ) {
            result.success(false)
            return
        }
        pending = PendingSpeech(id, text, rate.toFloat(), result)
        withEngine { tts -> startPending(id, tts) }
    }

    private fun startPending(id: String, tts: TextToSpeech?) {
        val request = pending?.takeIf { it.id == id } ?: return
        pending = null
        val accepted = tts != null && runCatching {
            val voice = installedVietnameseVoice(tts.voices.orEmpty()) ?: return@runCatching false
            if (tts.setVoice(voice) != TextToSpeech.SUCCESS ||
                tts.setSpeechRate(request.rate) != TextToSpeech.SUCCESS
            ) {
                return@runCatching false
            }

            val current = Playback(id, splitForEngine(request.text))
            playback = current
            enqueueChunk(tts, current)
        }.getOrDefault(false)
        if (!accepted) playback = null
        request.result.success(accepted)
    }

    private fun enqueueChunk(tts: TextToSpeech, current: Playback): Boolean =
        tts.speak(
            current.chunks[current.index],
            TextToSpeech.QUEUE_FLUSH,
            Bundle(),
            current.utteranceId,
        ) == TextToSpeech.SUCCESS

    private val progressListener = object : UtteranceProgressListener() {
        override fun onStart(utteranceId: String) = onCurrent(utteranceId) { current ->
            if (current.index == 0) emit(current.id, "speaking")
        }

        override fun onDone(utteranceId: String) = onCurrent(utteranceId) { current ->
            if (++current.index == current.chunks.size) {
                finish(current, "done")
            } else {
                val tts = engine
                if (tts == null || !runCatching { enqueueChunk(tts, current) }.getOrDefault(false)) {
                    finish(current, "error")
                }
            }
        }

        @Deprecated("Required by Android's UtteranceProgressListener")
        override fun onError(utteranceId: String) = onCurrent(utteranceId) { finish(it, "error") }

        override fun onError(utteranceId: String, errorCode: Int) =
            onCurrent(utteranceId) { finish(it, "error") }

        override fun onStop(utteranceId: String, interrupted: Boolean) =
            onCurrent(utteranceId) { finish(it, "stopped") }
    }

    private fun onCurrent(utteranceId: String, action: (Playback) -> Unit) {
        main.post {
            val current = playback?.takeIf { it.utteranceId == utteranceId } ?: return@post
            action(current)
        }
    }

    private fun finish(current: Playback, state: String) {
        playback = null
        emit(current.id, state)
    }

    private fun emit(id: String, state: String) {
        channel.invokeMethod("utteranceEvent", mapOf("id" to id, "state" to state))
    }

    private fun interrupt(): Boolean {
        pending?.result?.success(false)
        pending = null
        playback = null
        val tts = engine
        if (tts == null || initializing) return true
        return runCatching { tts.stop() == TextToSpeech.SUCCESS }.getOrDefault(false)
    }

    private fun releaseEngine() {
        interrupt()
        initializationTimeout?.let(main::removeCallbacks)
        initializationTimeout = null
        val released = engine
        engine = null
        initializing = false
        completeWaiters(null)
        runCatching { released?.shutdown() }
    }

    private fun splitForEngine(text: String): List<String> {
        val limit = TextToSpeech.getMaxSpeechInputLength()
        val chunks = mutableListOf<String>()
        var start = 0
        while (start < text.length) {
            var end = start + minOf(limit, text.length - start)
            if (end < text.length) {
                if (text[end - 1].isHighSurrogate() && text[end].isLowSurrogate()) end--
                val separator = text.lastIndexOfAny(charArrayOf(' ', '\n', '\t'), end - 1)
                if (separator >= start + limit / 2) end = separator + 1
            }
            chunks.add(text.substring(start, end))
            start = end
        }
        return chunks
    }

    private class PendingSpeech(
        val id: String,
        val text: String,
        val rate: Float,
        val result: MethodChannel.Result,
    )

    private class Playback(val id: String, val chunks: List<String>) {
        var index = 0
        val utteranceId: String get() = "$id-$index"
    }
}
