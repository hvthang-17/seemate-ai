package dev.example.flutteragenticstarter

import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.TextRecognizer
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/** One-shot, bundled Latin OCR. Camera buffers and recognized text stay in memory. */
internal class TextRecognitionChannel(messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "seemate/text_recognition")
    private val worker = Executors.newSingleThreadExecutor()
    private var detached = false

    // Recognizer and request state are confined to the worker.
    private var recognizer: TextRecognizer? = null
    private var reading = false
    private var disposeAfterRead = false
    private var closing = false

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "read" -> worker.execute { read(call, result) }
                "dispose" -> worker.execute {
                    releaseRecognizerWhenIdle()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    fun close() {
        if (detached) return
        detached = true
        channel.setMethodCallHandler(null)
        worker.execute {
            closing = true
            releaseRecognizerWhenIdle()
        }
    }

    private fun read(call: MethodCall, result: MethodChannel.Result) {
        if (reading) {
            result.error("ocr_busy", null, null)
            return
        }
        val image = try {
            inputImage(call)
        } catch (_: RuntimeException) {
            result.error("invalid_image", null, null)
            return
        }

        try {
            val model = recognizer ?: TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
                .also { recognizer = it }
            val task = model.process(image)
            reading = true
            task.addOnCompleteListener(worker) { completed ->
                reading = false
                try {
                    if (!closing && !disposeAfterRead) {
                        if (completed.isSuccessful) {
                            val text = completed.result
                            result.success(
                                mapOf(
                                    "text" to text.text,
                                    "lines" to text.textBlocks.flatMap { block ->
                                        block.lines.map { it.text }
                                    },
                                ),
                            )
                        } else {
                            result.error("ocr_failed", null, null)
                        }
                    } else if (!closing) {
                        result.error("ocr_disposed", null, null)
                    }
                } finally {
                    if (disposeAfterRead) releaseRecognizerWhenIdle()
                }
            }
        } catch (_: RuntimeException) {
            reading = false
            result.error("ocr_failed", null, null)
        } catch (_: LinkageError) {
            reading = false
            result.error("ocr_failed", null, null)
        }
    }

    private fun releaseRecognizerWhenIdle() {
        disposeAfterRead = reading
        if (reading) return
        val model = recognizer
        recognizer = null
        try {
            model?.close()
        } catch (_: RuntimeException) {
            // A failing cleanup cannot keep the channel or worker alive.
        } finally {
            if (closing) worker.shutdown()
        }
    }

    private fun inputImage(call: MethodCall): InputImage {
        val width = call.argument<Int>("width") ?: throw IllegalArgumentException()
        val height = call.argument<Int>("height") ?: throw IllegalArgumentException()
        val rotation = call.argument<Int>("rotation") ?: throw IllegalArgumentException()
        require(width > 0 && height > 0 && width % 2 == 0 && height % 2 == 0)
        require(rotation == 0 || rotation == 90 || rotation == 180 || rotation == 270)
        val lumaSize = width.toLong() * height
        val size = lumaSize + lumaSize / 2
        require(size <= Int.MAX_VALUE)
        val planes = call.argument<List<*>>("planes") ?: throw IllegalArgumentException()
        require(planes.size == 3)
        val (y, u, v) = planes.map(OcrPlane::from)
        val chromaWidth = width / 2
        val chromaHeight = height / 2
        require(y.fits(width, height) && u.fits(chromaWidth, chromaHeight) &&
            v.fits(chromaWidth, chromaHeight))

        val nv21 = ByteArray(size.toInt())
        for (row in 0 until height) {
            y.copyRow(row, width, nv21)
        }
        var offset = lumaSize.toInt()
        for (row in 0 until chromaHeight) {
            for (column in 0 until chromaWidth) {
                nv21[offset++] = v.sample(row, column)
                nv21[offset++] = u.sample(row, column)
            }
        }
        return InputImage.fromByteArray(nv21, width, height, rotation, InputImage.IMAGE_FORMAT_NV21)
    }

    private class OcrPlane(val bytes: ByteArray, val rowStride: Int, val pixelStride: Int) {
        fun fits(width: Int, height: Int): Boolean {
            val lastColumn = (width - 1).toLong() * pixelStride
            val lastRow = (height - 1).toLong() * rowStride
            return lastColumn < rowStride && lastRow + lastColumn < bytes.size
        }

        fun sample(row: Int, column: Int): Byte = bytes[row * rowStride + column * pixelStride]

        fun copyRow(row: Int, width: Int, output: ByteArray) {
            val offset = row * width
            if (pixelStride == 1) {
                bytes.copyInto(output, offset, row * rowStride, row * rowStride + width)
            } else {
                for (column in 0 until width) output[offset + column] = sample(row, column)
            }
        }

        companion object {
            fun from(value: Any?): OcrPlane {
                val plane = value as? Map<*, *> ?: throw IllegalArgumentException()
                val bytes = plane["bytes"] as? ByteArray ?: throw IllegalArgumentException()
                val rowStride = plane["rowStride"] as? Int ?: throw IllegalArgumentException()
                val pixelStride = plane["pixelStride"] as? Int ?: throw IllegalArgumentException()
                require(rowStride > 0 && pixelStride > 0)
                return OcrPlane(bytes, rowStride, pixelStride)
            }
        }
    }
}
