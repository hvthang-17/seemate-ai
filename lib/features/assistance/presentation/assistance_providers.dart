import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/assistance_contracts/assistance_contracts.dart';
import '../domain/models/assistance_state.dart';

final speechCoordinatorProvider = Provider<SpeechCoordinatorContract>((ref) {
  final coordinator = FakeSpeechCoordinator();
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

final objectDetectorProvider = Provider<ObjectDetectorContract>((ref) {
  final detector = FakeObjectDetector();
  ref.onDispose(detector.dispose);
  return detector;
});

final textReaderProvider = Provider<TextReaderContract>((ref) {
  final reader = FakeTextReader();
  ref.onDispose(reader.dispose);
  return reader;
});

final preferencesRepoProvider = Provider<AssistancePreferencesContract>((ref) {
  return FakeAssistancePreferencesRepository();
});

final voiceCommandProvider = Provider<VoiceCommandContract?>((ref) => null);

Future<void> applySpeechPreferences(
  SpeechCoordinatorContract coordinator,
  AssistancePreferences preferences,
) {
  coordinator.setSpokenFeedbackEnabled(preferences.spokenFeedbackEnabled);
  coordinator.updateSuppressionInterval(
    preferences.duplicateSuppressionInterval,
  );
  return coordinator.setSpeechRate(preferences.speechRate);
}

final assistanceNotifierProvider =
    NotifierProvider<AssistanceNotifier, AssistanceState>(
      AssistanceNotifier.new,
    );

class AssistanceNotifier extends Notifier<AssistanceState> {
  var _session = Object();
  CancellationToken? _ocrCancellation;
  bool _hasFrameInFlight = false;
  bool _feedbackPaused = false;
  Object? _voiceInputRequest;
  String? _detectionCameraSession;

  @override
  AssistanceState build() {
    ref.onDispose(_invalidateSession);
    return const AssistanceState();
  }

  void _invalidateSession() {
    _session = Object();
    _ocrCancellation?.cancel();
  }

  void selectMode(AssistanceMode mode) {
    if (state.mode == mode && !_feedbackPaused) return;
    _feedbackPaused = false;

    _invalidateSession();
    unawaited(ref.read(speechCoordinatorProvider).stop());

    state = state.copyWith(
      mode: mode,
      clearTargetKey: mode != AssistanceMode.targetSearch,
      detectedObjects: const [],
      isProcessing: false,
      clearOcrResult: true,
      clearSpokenFeedback: true,
      clearErrorMessage: true,
      clearDetectionFailure: true,
      hasDetectionResult: false,
      ocrCaptureFailed: false,
      voiceUnavailable: false,
      statusMessage: switch (mode) {
        AssistanceMode.objectRecognition => 'Đang nhận diện đồ vật xung quanh',
        AssistanceMode.targetSearch => 'Đang tìm kiếm đồ vật được chọn',
        AssistanceMode.textReading => 'Sẵn sàng đọc văn bản',
        AssistanceMode.idle => 'Đã dừng tất cả các chế độ',
      },
    );
  }

  void setTargetObject(ObjectKey key) {
    if (state.mode == AssistanceMode.targetSearch &&
        state.targetKey == key &&
        !_feedbackPaused) {
      return;
    }
    _feedbackPaused = false;

    _invalidateSession();
    unawaited(ref.read(speechCoordinatorProvider).stop());
    state = state.copyWith(
      mode: AssistanceMode.targetSearch,
      targetKey: key,
      detectedObjects: const [],
      isProcessing: false,
      clearOcrResult: true,
      clearSpokenFeedback: true,
      statusMessage: 'Đang tìm ${key.vietnameseLabel}...',
      clearErrorMessage: true,
      clearDetectionFailure: true,
      hasDetectionResult: false,
      ocrCaptureFailed: false,
      voiceUnavailable: false,
    );
  }

  Future<void> processFrame(
    CameraFrame frame, {
    bool Function()? isCurrentFrame,
    bool announce = true,
  }) async {
    if (state.mode != AssistanceMode.objectRecognition &&
        state.mode != AssistanceMode.targetSearch) {
      frame.release();
      return;
    }

    if (_hasFrameInFlight) {
      frame.release();
      return;
    }

    final session = _session;
    _hasFrameInFlight = true;
    final changedCamera = _detectionCameraSession != frame.sessionId;
    _detectionCameraSession = frame.sessionId;
    state = state.copyWith(
      isProcessing: true,
      detectedObjects: changedCamera ? const [] : null,
      hasDetectionResult: changedCamera ? false : null,
    );
    try {
      final detector = ref.read(objectDetectorProvider);
      final result = await detector.detect(
        frame,
        targetKey: state.targetKey,
        requestSession: session,
      );
      frame.release();
      if (!identical(session, _session)) return;
      if (isCurrentFrame != null && !isCurrentFrame()) {
        state = state.copyWith(isProcessing: false);
        return;
      }

      result.fold<void>(
        (failure) {
          state = state.copyWith(
            isProcessing: false,
            detectedObjects: const [],
            detectionFailure: failure,
          );
        },
        (result) {
          final detections = result.objects;
          state = state.copyWith(
            isProcessing: false,
            detectedObjects: detections,
            clearDetectionFailure: true,
            hasDetectionResult:
                result.readiness != DetectionReadiness.stabilizing,
          );

          if (!announce ||
              _feedbackPaused ||
              _voiceInputRequest != null ||
              state.voiceUnavailable ||
              detections.isEmpty) {
            return;
          }

          // In target search mode, only speak when matching target qualifies
          final bestMatch = detections.first;
          unawaited(_announceDetection(bestMatch, session));
        },
      );
    } finally {
      _hasFrameInFlight = false;
      frame.release();
    }
  }

  Future<void> _announceDetection(DetectedObject object, Object session) async {
    final phrase = object.toSpokenPhrase();
    final coordinator = ref.read(speechCoordinatorProvider);
    final spoken = await coordinator.speak(
      phrase,
      priority: SpeechPriority.low,
      suppressionKey: SuppressionKey(objectKey: object.key, zone: object.zone),
    );
    if (!identical(session, _session)) return;
    if (spoken) {
      state = state.copyWith(spokenFeedback: phrase);
    } else if (coordinator.currentState == SpeechState.error) {
      await _checkVoice(coordinator, session);
    }
  }

  Future<void> _checkVoice(
    SpeechCoordinatorContract coordinator,
    Object session,
  ) async {
    if (!identical(session, _session)) return;
    final readiness = await coordinator.checkVoiceReadiness();
    if (identical(session, _session) &&
        (!readiness.isAvailable || !readiness.isOffline)) {
      state = state.copyWith(voiceUnavailable: true);
    }
  }

  Future<void> captureAndReadText(
    Future<CameraFrame?> Function() captureFrame,
  ) async {
    if (state.mode != AssistanceMode.textReading || _hasFrameInFlight) {
      return;
    }

    final session = _session;
    final cancellation = CancellationToken();
    unawaited(ref.read(speechCoordinatorProvider).stop());
    _ocrCancellation = cancellation;
    _hasFrameInFlight = true;
    state = state.copyWith(
      isProcessing: true,
      clearErrorMessage: true,
      clearOcrResult: true,
      ocrCaptureFailed: false,
      voiceUnavailable: false,
      statusMessage: 'Đang trích xuất văn bản từ hình ảnh...',
    );

    CameraFrame? frame;
    try {
      frame = await captureFrame();
      if (!identical(session, _session)) return;
      if (frame == null) {
        state = state.copyWith(isProcessing: false, ocrCaptureFailed: true);
        return;
      }
      final reader = ref.read(textReaderProvider);
      final result = await reader.readText(frame, cancelToken: cancellation);
      frame.release();
      if (!identical(session, _session)) return;

      await result.fold(
        (failure) async {
          state = state.copyWith(
            isProcessing: false,
            errorMessage: 'Không thể đọc được văn bản trong ảnh',
          );
        },
        (ocrResult) async {
          state = state.copyWith(
            isProcessing: false,
            ocrResult: ocrResult,
            statusMessage: ocrResult.isEmpty
                ? 'Không tìm thấy văn bản'
                : 'Đã trích xuất văn bản',
          );

          if (ocrResult.isNotEmpty && _voiceInputRequest == null) {
            final coordinator = ref.read(speechCoordinatorProvider);
            final spoken = await coordinator.speak(
              ocrResult.fullText,
              priority: SpeechPriority.high,
            );
            if (!spoken) await _checkVoice(coordinator, session);
          }
        },
      );
    } finally {
      _ocrCancellation = null;
      _hasFrameInFlight = false;
      frame?.release();
    }
  }

  Future<void> stopReading() async {
    _invalidateSession();
    _feedbackPaused = true;
    _voiceInputRequest = null;
    final voice = ref.read(voiceCommandProvider);
    if (voice != null) unawaited(voice.stopListening());
    state = state.copyWith(
      isProcessing: false,
      clearSpokenFeedback: true,
      statusMessage: 'Đã dừng đọc',
    );
    await ref.read(speechCoordinatorProvider).stop();
  }

  Future<void> beginVoiceInput(Object request) {
    _voiceInputRequest = request;
    return ref.read(speechCoordinatorProvider).stop();
  }

  void endVoiceInput(Object request) {
    if (identical(_voiceInputRequest, request)) _voiceInputRequest = null;
  }

  bool isVoiceInputCurrent(Object request) =>
      identical(_voiceInputRequest, request);

  void suspendFeedback() {
    _invalidateSession();
    state = state.copyWith(isProcessing: false, clearSpokenFeedback: true);
    unawaited(ref.read(speechCoordinatorProvider).stop());
  }
}
