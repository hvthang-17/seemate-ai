package dev.example.flutteragenticstarter

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var objectDetectionChannel: ObjectDetectionChannel? = null
    private var speechChannel: SpeechChannel? = null
    private var textRecognitionChannel: TextRecognitionChannel? = null
    private var voiceCommandChannel: VoiceCommandChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        objectDetectionChannel = ObjectDetectionChannel(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
        )
        speechChannel = SpeechChannel(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
        )
        textRecognitionChannel = TextRecognitionChannel(
            flutterEngine.dartExecutor.binaryMessenger,
        )
        voiceCommandChannel = VoiceCommandChannel(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
        )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        objectDetectionChannel?.close()
        objectDetectionChannel = null
        textRecognitionChannel?.close()
        textRecognitionChannel = null
        speechChannel?.close()
        speechChannel = null
        voiceCommandChannel?.close()
        voiceCommandChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
