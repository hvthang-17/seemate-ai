package dev.example.flutteragenticstarter

import android.content.Context
import java.io.File
import java.io.IOException
import java.util.UUID
import java.util.concurrent.atomic.AtomicBoolean
import java.util.zip.ZipInputStream

internal class ZipformerModelFiles(private val context: Context) {
    fun isAvailable(): Boolean = try {
        context.assets.open(ARCHIVE).use { true }
    } catch (_: IOException) {
        false
    }

    fun prepare(cancelled: AtomicBoolean): File? {
        val installed = File(context.noBackupFilesDir, MODEL_NAME)
        if (isComplete(installed)) return installed
        val staging = File(context.noBackupFilesDir, "zipformer-${UUID.randomUUID()}")
        if (!staging.mkdir()) throw IOException("Could not stage local voice model")
        try {
            ZipInputStream(context.assets.open(ARCHIVE).buffered()).use { archive ->
                val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                while (!cancelled.get()) {
                    val entry = archive.nextEntry ?: break
                    // Only the four flat model entries are accepted from the packaged archive.
                    if (entry.isDirectory || entry.name !in REQUIRED_FILES) continue
                    File(staging, entry.name).outputStream().use { output ->
                        while (!cancelled.get()) {
                            val count = archive.read(buffer)
                            if (count < 0) break
                            output.write(buffer, 0, count)
                        }
                    }
                }
            }
            if (cancelled.get()) return null
            if (!isComplete(staging)) throw IOException("Missing model data")
            if (!staging.renameTo(installed) && !isComplete(installed)) {
                throw IOException("Could not install local voice model")
            }
            return installed
        } finally {
            staging.deleteRecursively()
        }
    }

    private fun isComplete(directory: File): Boolean =
        REQUIRED_FILES.all { File(directory, it).let { file -> file.isFile && file.length() > 0 } }

    private companion object {
        const val ARCHIVE = "zipformer-vi-30m-int8.zip"
        const val MODEL_NAME = "sherpa-onnx-zipformer-vi-30M-int8-2026-02-09"
        val REQUIRED_FILES = setOf("encoder.int8.onnx", "decoder.onnx", "joiner.int8.onnx", "tokens.txt")
    }
}
