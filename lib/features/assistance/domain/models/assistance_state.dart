import '../../../../shared/assistance_contracts/assistance_contracts.dart';

/// Active operational mode of the SeeMate AI assistant.
enum AssistanceMode { idle, objectRecognition, targetSearch, textReading }

/// Immutable UI state for the assistance feature.
class AssistanceState {
  const AssistanceState({
    this.mode = AssistanceMode.idle,
    this.targetKey,
    this.detectedObjects = const [],
    this.ocrResult,
    this.spokenFeedback,
    this.isProcessing = false,
    this.statusMessage,
    this.errorMessage,
    this.detectionFailure,
    this.hasDetectionResult = false,
    this.ocrCaptureFailed = false,
    this.voiceUnavailable = false,
  });

  final AssistanceMode mode;
  final ObjectKey? targetKey;
  final List<DetectedObject> detectedObjects;
  final OcrResult? ocrResult;
  final String? spokenFeedback;
  final bool isProcessing;
  final String? statusMessage;
  final String? errorMessage;
  final DetectionFailure? detectionFailure;
  final bool hasDetectionResult;
  final bool ocrCaptureFailed;
  final bool voiceUnavailable;

  AssistanceState copyWith({
    AssistanceMode? mode,
    ObjectKey? targetKey,
    bool clearTargetKey = false,
    List<DetectedObject>? detectedObjects,
    OcrResult? ocrResult,
    bool clearOcrResult = false,
    String? spokenFeedback,
    bool clearSpokenFeedback = false,
    bool? isProcessing,
    String? statusMessage,
    bool clearStatusMessage = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    DetectionFailure? detectionFailure,
    bool clearDetectionFailure = false,
    bool? hasDetectionResult,
    bool? ocrCaptureFailed,
    bool? voiceUnavailable,
  }) {
    return AssistanceState(
      mode: mode ?? this.mode,
      targetKey: clearTargetKey ? null : (targetKey ?? this.targetKey),
      detectedObjects: detectedObjects ?? this.detectedObjects,
      ocrResult: clearOcrResult ? null : (ocrResult ?? this.ocrResult),
      spokenFeedback: clearSpokenFeedback
          ? null
          : (spokenFeedback ?? this.spokenFeedback),
      isProcessing: isProcessing ?? this.isProcessing,
      statusMessage: clearStatusMessage
          ? null
          : (statusMessage ?? this.statusMessage),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      detectionFailure: clearDetectionFailure
          ? null
          : (detectionFailure ?? this.detectionFailure),
      hasDetectionResult: hasDetectionResult ?? this.hasDetectionResult,
      ocrCaptureFailed: ocrCaptureFailed ?? this.ocrCaptureFailed,
      voiceUnavailable: voiceUnavailable ?? this.voiceUnavailable,
    );
  }
}
