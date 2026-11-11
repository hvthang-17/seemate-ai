import 'object_detection_contract.dart';

/// Priority of a speech request.
enum SpeechPriority {
  low,
  normal,
  high,
  immediateStop,
}

/// Status of the active speech playback.
enum SpeechState {
  idle,
  speaking,
  stopped,
  error,
}

/// Readiness information for the offline Vietnamese TTS engine.
class VoiceReadiness {
  const VoiceReadiness({
    required this.isAvailable,
    required this.isOffline,
    this.engineName,
    this.voiceName,
    this.locale = 'vi-VN',
  });

  final bool isAvailable;
  final bool isOffline;
  final String? engineName;
  final String? voiceName;
  final String locale;
}

/// Key used to suppress repeated duplicate announcements of the same object in the same zone.
class SuppressionKey {
  const SuppressionKey({
    required this.objectKey,
    required this.zone,
  });

  final ObjectKey objectKey;
  final HorizontalZone zone;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SuppressionKey &&
          runtimeType == other.runtimeType &&
          objectKey == other.objectKey &&
          zone == other.zone;

  @override
  int get hashCode => Object.hash(objectKey, zone);

  @override
  String toString() => 'SuppressionKey(${objectKey.name}, ${zone.name})';
}

/// Contract for the single speech coordinator managing Vietnamese TTS and duplicate suppression.
abstract interface class SpeechCoordinatorContract {
  /// Checks whether an offline Vietnamese voice is ready.
  Future<VoiceReadiness> checkVoiceReadiness();

  /// Requests the coordinator to speak [text].
  ///
  /// If [suppressionKey] is provided and the same key was spoken within the configured
  /// suppression interval, this invocation returns `false` (suppressed) without speaking.
  /// If spoken successfully, returns `true`.
  Future<bool> speak(
    String text, {
    SpeechPriority priority = SpeechPriority.normal,
    SuppressionKey? suppressionKey,
  });

  /// Immediately invalidates queued requests and interrupts active playback.
  /// The future completes when the active playback has stopped.
  Future<void> stop();

  /// Updates the duplicate announcement suppression interval (e.g. 2 seconds).
  void updateSuppressionInterval(Duration interval);

  /// Sets the speech rate (0.5 to 2.0, default 1.0).
  Future<void> setSpeechRate(double rate);

  /// Enables automatic object feedback. Explicit OCR readings remain available.
  void setSpokenFeedbackEnabled(bool enabled);

  /// Stream of speech playback state transitions.
  Stream<SpeechState> get stateChanges;

  /// Current speech playback state.
  SpeechState get currentState;

  /// Releases TTS engine and audio resources.
  void dispose();
}
