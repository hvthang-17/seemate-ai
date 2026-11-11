package dev.example.flutteragenticstarter

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Matrix
import android.util.Log
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.objectdetector.ObjectDetector
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import java.io.FileNotFoundException

internal class ObjectDetectionChannel(context: Context, messenger: BinaryMessenger) {
    private val applicationContext = context.applicationContext
    private val channel = MethodChannel(messenger, "seemate/object_detection")
    private val worker = Executors.newSingleThreadExecutor()
    // Model creation, inference, and release all run on the same worker.
    private var detector: ConfiguredDetector? = null

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "detect" -> worker.execute { detect(call, result) }
                "dispose" -> worker.execute {
                    try {
                        disposeDetector()
                        result.success(null)
                    } catch (_: RuntimeException) {
                        result.error("inference_failed", null, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    fun close() {
        channel.setMethodCallHandler(null)
        worker.execute {
            try {
                disposeDetector()
            } catch (_: RuntimeException) {
                // The engine is detaching and there is no caller to notify.
            }
        }
        worker.shutdown()
    }

    private fun detect(call: MethodCall, result: MethodChannel.Result) {
        val frame: YuvFrame
        val confidence: Float
        try {
            frame = YuvFrame.from(call)
            val threshold = call.argument<Double>("confidenceThreshold") ?: 0.50
            require(threshold in 0.0..1.0)
            confidence = threshold.toFloat()
        } catch (_: RuntimeException) {
            result.error("inference_failed", null, null)
            return
        }

        val model = try {
            detectorFor(confidence)
        } catch (_: FileNotFoundException) {
            result.error("model_unavailable", null, null)
            return
        } catch (failure: RuntimeException) {
            Log.e("SeeMateDetector", "Could not initialize the bundled detector", failure)
            result.error("detector_init_failed", null, null)
            return
        } catch (failure: LinkageError) {
            Log.e("SeeMateDetector", "Could not link the bundled detector", failure)
            result.error("detector_init_failed", null, null)
            return
        }

        try {
            val bitmap = frame.toUprightBitmap()
            val image = try {
                BitmapImageBuilder(bitmap).build()
            } catch (failure: RuntimeException) {
                bitmap.recycle()
                throw failure
            }
            val detections = try {
                model.detect(image).detections().flatMap { detection ->
                    val box = detection.boundingBox()
                    val left = (box.left / bitmap.width).coerceIn(0f, 1f)
                    val top = (box.top / bitmap.height).coerceIn(0f, 1f)
                    val right = (box.right / bitmap.width).coerceIn(0f, 1f)
                    val bottom = (box.bottom / bitmap.height).coerceIn(0f, 1f)
                    if (!(left < right && top < bottom)) return@flatMap emptyList()

                    detection.categories().map { category ->
                        mapOf(
                            "label" to category.categoryName(),
                            "score" to category.score(),
                            "left" to left,
                            "top" to top,
                            "right" to right,
                            "bottom" to bottom,
                        )
                    }
                }
            } finally {
                // The MPImage owns the bitmap after a successful build.
                image.close()
            }
            result.success(detections)
        } catch (_: RuntimeException) {
            result.error("inference_failed", null, null)
        } catch (_: LinkageError) {
            result.error("inference_failed", null, null)
        }
    }

    private fun detectorFor(confidence: Float): ObjectDetector {
        val existing = detector
        if (existing != null && existing.confidence == confidence) return existing.model
        disposeDetector()

        val assetName = "efficientdet_lite0.tflite"
        applicationContext.assets.openFd(assetName).close()
        val options = ObjectDetector.ObjectDetectorOptions.builder()
            .setBaseOptions(
                BaseOptions.builder()
                    .setModelAssetPath(assetName)
                    .setDelegate(Delegate.CPU)
                    .build(),
            )
            .setRunningMode(RunningMode.IMAGE)
            .setScoreThreshold(confidence)
            .build()
        return ObjectDetector.createFromOptions(applicationContext, options).also {
            detector = ConfiguredDetector(confidence, it)
        }
    }

    private fun disposeDetector() {
        val model = detector?.model
        detector = null
        model?.close()
    }

    private class ConfiguredDetector(val confidence: Float, val model: ObjectDetector)
}

private class YuvFrame(
    private val width: Int,
    private val height: Int,
    private val rotation: Int,
    private val planes: List<YuvPlane>,
) {
    fun toUprightBitmap(): Bitmap {
        val (luma, chromaU, chromaV) = planes
        val pixels = IntArray(width * height)
        for (row in 0 until height) {
            for (column in 0 until width) {
                // BT.601 limited-range conversion with separate Y, U and V strides.
                val y = 298 * (luma.sample(row, column) - 16).coerceAtLeast(0)
                val u = chromaU.sample(row / 2, column / 2) - 128
                val v = chromaV.sample(row / 2, column / 2) - 128
                pixels[row * width + column] = Color.rgb(
                    channelValue(y + 409 * v),
                    channelValue(y - 100 * u - 208 * v),
                    channelValue(y + 516 * u),
                )
            }
        }

        val bitmap = Bitmap.createBitmap(pixels, width, height, Bitmap.Config.ARGB_8888)
        if (rotation == 0) return bitmap

        return try {
            val transform = Matrix().apply { setRotate(rotation.toFloat()) }
            Bitmap.createBitmap(bitmap, 0, 0, width, height, transform, false)
        } finally {
            bitmap.recycle()
        }
    }

    private fun channelValue(value: Int): Int = ((value + 128) shr 8).coerceIn(0, 255)

    companion object {
        fun from(call: MethodCall): YuvFrame {
            val width = call.argument<Int>("width") ?: throw IllegalArgumentException()
            val height = call.argument<Int>("height") ?: throw IllegalArgumentException()
            val rotation = call.argument<Int>("rotation") ?: throw IllegalArgumentException()
            require(width > 0 && height > 0 && width <= Int.MAX_VALUE / height)
            require(rotation == 0 || rotation == 90 || rotation == 180 || rotation == 270)
            val planes = call.argument<List<Map<String, Any?>>>("planes")
                ?.map(YuvPlane::from) ?: throw IllegalArgumentException()
            require(planes.size == 3)

            val chromaWidth = (width - 1) / 2 + 1
            val chromaHeight = (height - 1) / 2 + 1
            require(planes[0].fits(width, height))
            require(planes[1].fits(chromaWidth, chromaHeight))
            require(planes[2].fits(chromaWidth, chromaHeight))
            return YuvFrame(width, height, rotation, planes)
        }
    }
}

private class YuvPlane(
    private val bytes: ByteArray,
    private val rowStride: Int,
    private val pixelStride: Int,
) {
    fun fits(width: Int, height: Int): Boolean {
        val lastColumn = (width - 1).toLong() * pixelStride
        val lastRow = (height - 1).toLong() * rowStride
        return lastColumn < rowStride && lastRow + lastColumn < bytes.size
    }

    fun sample(row: Int, column: Int): Int =
        bytes[row * rowStride + column * pixelStride].toInt() and 0xff

    companion object {
        fun from(plane: Map<String, Any?>): YuvPlane {
            val bytes = plane["bytes"] as? ByteArray ?: throw IllegalArgumentException()
            val rowStride = plane["rowStride"] as? Int ?: throw IllegalArgumentException()
            val pixelStride = plane["pixelStride"] as? Int ?: throw IllegalArgumentException()
            require(rowStride > 0 && pixelStride > 0)
            return YuvPlane(bytes, rowStride, pixelStride)
        }
    }
}
