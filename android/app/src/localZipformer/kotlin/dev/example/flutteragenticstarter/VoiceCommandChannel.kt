package dev.example.flutteragenticstarter

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import com.k2fsa.sherpa.onnx.FeatureConfig
import com.k2fsa.sherpa.onnx.OfflineModelConfig
import com.k2fsa.sherpa.onnx.OfflineRecognizer
import com.k2fsa.sherpa.onnx.OfflineRecognizerConfig
import com.k2fsa.sherpa.onnx.OfflineTransducerModelConfig
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

internal class VoiceCommandChannel(context: Context, messenger: BinaryMessenger) {
    private val appContext = context.applicationContext
    private val models = ZipformerModelFiles(appContext)
    private val channel = MethodChannel(messenger, "seemate/voice_commands")
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private var session: ListeningSession? = null
    // Access and release are confined to the worker, including during disposal.
    private var recognizer: OfflineRecognizer? = null

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isOfflineAvailable" -> result.success(models.isAvailable())
                // This recognizer transcribes whole audio. Dart validates exact command phrases.
                "listen" -> listen(
                    call.argument<Int>("timeoutMs") ?: 5_000,
                    call.argument<Number>("requestId"),
                    result,
                )
                "stop" -> stop(result, releaseModel = false)
                "dispose" -> stop(result, releaseModel = true)
                else -> result.notImplemented()
            }
        }
    }

    fun close() {
        channel.setMethodCallHandler(null)
        session?.let { active ->
            active.cancelled.set(true)
            active.reply(Outcome(Status.CANCELLED))
        }
        session = null
        worker.execute { releaseRecognizer() }
        worker.shutdown()
    }

    private fun hasMicrophonePermission(): Boolean =
        appContext.checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED

    private fun listen(timeoutMs: Int, requestId: Number?, result: MethodChannel.Result) {
        val failure = when {
            session != null -> Status.BUSY
            !models.isAvailable() -> Status.UNAVAILABLE
            !hasMicrophonePermission() -> Status.PERMISSION_DENIED
            else -> null
        }
        if (failure != null) {
            result.success(Outcome(failure).toWire())
            return
        }
        val current = ListeningSession(timeoutMs.coerceIn(1, 10_000), requestId, result)
        session = current
        worker.execute {
            val outcome = runSession(current)
            main.post {
                if (session === current) {
                    session = null
                    current.reply(if (current.cancelled.get()) Outcome(Status.CANCELLED) else outcome)
                }
            }
        }
    }

    private fun stop(result: MethodChannel.Result, releaseModel: Boolean) {
        session?.cancelled?.set(true)
        // Serial execution waits for capture/decode cleanup before acknowledging stop.
        worker.execute {
            if (releaseModel) releaseRecognizer()
            main.post { result.success(null) }
        }
    }

    private fun releaseRecognizer() {
        recognizer?.release()
        recognizer = null
    }

    private fun runSession(current: ListeningSession): Outcome = try {
        val model = getRecognizer(current)
        if (model == null || current.cancelled.get()) Outcome(Status.CANCELLED)
        else capture(current, model)
    } catch (_: SecurityException) {
        Outcome(Status.PERMISSION_DENIED)
    } catch (_: Exception) {
        Outcome(Status.ERROR)
    } catch (_: LinkageError) {
        Outcome(Status.UNAVAILABLE)
    }

    private fun getRecognizer(current: ListeningSession): OfflineRecognizer? {
        recognizer?.let { return it }
        val directory = models.prepare(current.cancelled) ?: return null
        if (current.cancelled.get()) return null
        val config = OfflineRecognizerConfig(
            featConfig = FeatureConfig(sampleRate = SAMPLE_RATE, featureDim = 80, dither = 0.0f),
            modelConfig = OfflineModelConfig(
                transducer = OfflineTransducerModelConfig(
                    encoder = directory.resolve("encoder.int8.onnx").path,
                    decoder = directory.resolve("decoder.onnx").path,
                    joiner = directory.resolve("joiner.int8.onnx").path,
                ),
                tokens = directory.resolve("tokens.txt").path,
                numThreads = 2,
                provider = "cpu",
                debug = false,
                modelType = "transducer",
            ),
            decodingMethod = "greedy_search",
        )
        return OfflineRecognizer(config = config).also { recognizer = it }
    }

    @SuppressLint("MissingPermission") // Checked before and after model initialization.
    private fun capture(current: ListeningSession, model: OfflineRecognizer): Outcome {
        if (current.cancelled.get()) return Outcome(Status.CANCELLED)
        if (!hasMicrophonePermission()) return Outcome(Status.PERMISSION_DENIED)
        val minimum = AudioRecord.getMinBufferSize(
            SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT,
        )
        if (minimum <= 0) return Outcome(Status.AUDIO_UNAVAILABLE)
        val samples = ShortArray(SAMPLE_RATE / 10)
        val waveform = FloatArray(maxOf(1, SAMPLE_RATE * current.timeoutMs / 1_000))
        var length = 0
        val microphone = AudioRecord(
            MediaRecorder.AudioSource.VOICE_RECOGNITION, SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT,
            maxOf(minimum, samples.size * Short.SIZE_BYTES * 2),
        )
        try {
            if (microphone.state != AudioRecord.STATE_INITIALIZED) {
                return Outcome(Status.AUDIO_UNAVAILABLE)
            }
            if (current.cancelled.get()) return Outcome(Status.CANCELLED)
            microphone.startRecording()
            if (microphone.recordingState != AudioRecord.RECORDSTATE_RECORDING) {
                return Outcome(Status.AUDIO_UNAVAILABLE)
            }
            current.requestId?.let { requestId ->
                main.post {
                    if (session === current && !current.cancelled.get()) {
                        channel.invokeMethod("listeningStarted", requestId)
                    }
                }
            }
            val deadline = SystemClock.elapsedRealtime() + current.timeoutMs
            while (!current.cancelled.get() && SystemClock.elapsedRealtime() < deadline && length < waveform.size) {
                val count = microphone.read(
                    samples, 0, minOf(samples.size, waveform.size - length), AudioRecord.READ_NON_BLOCKING,
                )
                if (count < 0) return Outcome(Status.AUDIO_UNAVAILABLE)
                if (count == 0) SystemClock.sleep(15)
                else for (index in 0 until count) waveform[length++] = samples[index] / 32768.0f
            }
        } finally {
            if (microphone.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
                runCatching { microphone.stop() }
            }
            microphone.release()
            samples.fill(0)
        }
        if (current.cancelled.get()) return Outcome(Status.CANCELLED)
        if (length == 0) return Outcome(Status.AUDIO_UNAVAILABLE)
        val stream = model.createStream()
        try {
            val audio = waveform.copyOf(length)
            try {
                stream.acceptWaveform(audio, SAMPLE_RATE)
            } finally {
                audio.fill(0.0f)
            }
            if (current.cancelled.get()) return Outcome(Status.CANCELLED)
            model.decode(stream)
            if (current.cancelled.get()) return Outcome(Status.CANCELLED)
            val text = model.getResult(stream).text.trim()
            return if (text.isEmpty()) Outcome(Status.NO_MATCH) else Outcome(Status.RECOGNIZED, text)
        } finally {
            waveform.fill(0.0f)
            stream.release()
        }
    }

    private class ListeningSession(
        val timeoutMs: Int,
        val requestId: Number?,
        private val result: MethodChannel.Result,
    ) {
        val cancelled = AtomicBoolean()
        fun reply(outcome: Outcome) = result.success(outcome.toWire())
    }

    private enum class Status(val wire: String) {
        RECOGNIZED("recognized"), NO_MATCH("no_match"), AUDIO_UNAVAILABLE("audio_unavailable"),
        UNAVAILABLE("unavailable"), PERMISSION_DENIED("permission_denied"), BUSY("busy"),
        CANCELLED("cancelled"), ERROR("error"),
    }

    private class Outcome(private val status: Status, private val text: String? = null) {
        fun toWire(): Map<String, Any?> = mapOf("status" to status.wire, "text" to text)
    }

    private companion object {
        const val SAMPLE_RATE = 16_000
    }
}
