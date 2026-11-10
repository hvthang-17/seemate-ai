import 'dart:async';

import 'speech_coordinator.dart';
import 'stt_engine.dart';
import 'vietnamese_command_parser.dart';

/// Status of the active voice session.
enum VoiceSessionStatus {
  idle,
  listening,
  processing,
  completed,
  error,
}

/// Orchestrates Speech-to-Text command listening with Text-to-Speech mutual exclusion.
///
/// Safety guarantees:
/// 1. Stops ongoing TTS before opening microphone to eliminate acoustic feedback.
/// 2. Never executes command actions on partial transcripts.
/// 3. Communicates status and outcomes clearly to TalkBack users.
/// 4. Handles microphone permission denial without crashing.
final class VoiceCommandCoordinator {
  VoiceCommandCoordinator({
    required SttEngine sttEngine,
    required SpeechCoordinator speechCoordinator,
    VietnameseCommandParser parser = const VietnameseCommandParser(),
    void Function()? onNavigateToOcr,
    void Function()? onNavigateToDetection,
    void Function()? onNavigateToTts,
  })  : _stt = sttEngine,
        _speechCoordinator = speechCoordinator,
        _parser = parser,
        _onNavigateToOcr = onNavigateToOcr,
        _onNavigateToDetection = onNavigateToDetection,
        _onNavigateToTts = onNavigateToTts;

  final SttEngine _stt;
  final SpeechCoordinator _speechCoordinator;
  final VietnameseCommandParser _parser;
  final void Function()? _onNavigateToOcr;
  final void Function()? _onNavigateToDetection;
  final void Function()? _onNavigateToTts;

  VoiceSessionStatus _status = VoiceSessionStatus.idle;
  String _currentPartialText = '';
  String _lastFinalTranscript = '';
  ParsedCommand? _lastParsedCommand;
  String? _statusMessage;
  String? _lastOcrText;

  VoiceSessionStatus get status => _status;
  bool get isListening => _status == VoiceSessionStatus.listening;
  String get currentPartialText => _currentPartialText;
  String get lastFinalTranscript => _lastFinalTranscript;
  ParsedCommand? get lastParsedCommand => _lastParsedCommand;
  String? get statusMessage => _statusMessage;
  String? get lastOcrText => _lastOcrText;

  final _statusController =
      StreamController<VoiceSessionStatus>.broadcast();
  Stream<VoiceSessionStatus> get statusStream => _statusController.stream;

  void updateLastOcrText(String text) {
    _lastOcrText = text;
  }

  /// Starts a voice command listening session.
  ///
  /// CRITICAL SAFETY: Immediately stops active TTS to prevent mic pickup loop.
  Future<bool> startListeningSession({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    // 1. Mutual exclusion: stop ongoing TTS immediately
    await _speechCoordinator.stop();

    _currentPartialText = '';
    _lastFinalTranscript = '';
    _lastParsedCommand = null;
    _statusMessage = null;

    final availability = await _stt.checkAvailability();
    if (availability != SttAvailability.available) {
      _status = VoiceSessionStatus.error;
      _statusMessage = availability == SttAvailability.permissionDenied
          ? 'Quyền truy cập Microphone bị từ chối. Vui lòng cấp quyền trong Cài đặt.'
          : 'Nhận diện giọng nói chưa sẵn sàng trên thiết bị.';
      _statusController.add(_status);
      await _speechCoordinator.speakDirect(_statusMessage!);
      return false;
    }

    _status = VoiceSessionStatus.listening;
    _statusController.add(_status);

    final started = await _stt.startListening(
      onPartial: _handlePartial,
      onFinal: _handleFinal,
      onError: _handleError,
      timeout: timeout,
    );

    if (!started) {
      _status = VoiceSessionStatus.error;
      _statusMessage = 'Không thể khởi động ghi âm.';
      _statusController.add(_status);
      return false;
    }

    return true;
  }

  /// Cancels the current session without executing actions.
  Future<void> cancelListeningSession() async {
    if (_status == VoiceSessionStatus.listening) {
      await _stt.stopListening();
    }
    _status = VoiceSessionStatus.idle;
    _currentPartialText = '';
    _statusController.add(_status);
  }

  void _handlePartial(String partial) {
    _currentPartialText = partial;
  }

  Future<void> _handleFinal(String finalResult) async {
    _lastFinalTranscript = finalResult.trim();
    _currentPartialText = _lastFinalTranscript;
    _status = VoiceSessionStatus.processing;
    _statusController.add(_status);

    if (_lastFinalTranscript.isEmpty) {
      _status = VoiceSessionStatus.idle;
      _statusController.add(_status);
      return;
    }

    // Parse natural language command
    final command = _parser.parse(_lastFinalTranscript);
    _lastParsedCommand = command;

    await _executeCommand(command);
  }

  void _handleError(String error) {
    _status = VoiceSessionStatus.error;
    _statusMessage = error;
    _statusController.add(_status);
  }

  Future<void> _executeCommand(ParsedCommand command) async {
    switch (command) {
      case RecognizedCommand(:final action, :final targetObject):
        await _executeRecognizedAction(action, targetObject);

      case UnsupportedObjectCommand(:final requestedObjectName):
        _status = VoiceSessionStatus.completed;
        _statusController.add(_status);
        await _speechCoordinator.speakDirect(
          'Hiện tại ứng dụng chưa hỗ trợ tìm đồ vật $requestedObjectName.',
        );

      case UnknownCommand():
        _status = VoiceSessionStatus.completed;
        _statusController.add(_status);
        await _speechCoordinator.speakDirect(
          'Xin lỗi, tôi chưa hiểu khẩu lệnh này. Bạn hãy thử lại.',
        );

      case EmptyCommand():
        _status = VoiceSessionStatus.idle;
        _statusController.add(_status);
    }
  }

  Future<void> _executeRecognizedAction(
    VoiceAction action,
    SupportedObject? targetObject,
  ) async {
    _status = VoiceSessionStatus.completed;
    _statusController.add(_status);

    switch (action) {
      case VoiceAction.stopReading:
        await _speechCoordinator.stop();
        await _speechCoordinator.speakDirect('Đã dừng đọc.');

      case VoiceAction.readText:
        await _speechCoordinator.speakDirect('Đang mở chức năng đọc văn bản.');
        _onNavigateToOcr?.call();

      case VoiceAction.detectObjects:
        await _speechCoordinator.speakDirect('Bắt đầu nhận diện đồ vật phía trước.');
        _onNavigateToDetection?.call();

      case VoiceAction.findObject:
        if (targetObject != null) {
          final nameVi = _supportedObjectNameVi(targetObject);
          await _speechCoordinator.speakDirect('Bắt đầu tìm $nameVi.');
        } else {
          await _speechCoordinator.speakDirect('Bạn muốn tìm đồ vật gì?');
        }
    }
  }

  String _supportedObjectNameVi(SupportedObject obj) {
    switch (obj) {
      case SupportedObject.wallet:
        return 'cái ví';
      case SupportedObject.keys:
        return 'chìa khóa';
      case SupportedObject.phone:
        return 'điện thoại';
      case SupportedObject.bottle:
        return 'chai nước';
      case SupportedObject.cup:
        return 'cái cốc';
      case SupportedObject.book:
        return 'cuốn sách';
      case SupportedObject.bag:
        return 'túi xách';
      case SupportedObject.chair:
        return 'cái ghế';
      case SupportedObject.person:
        return 'người';
    }
  }

  Future<void> dispose() async {
    if (_status == VoiceSessionStatus.listening) {
      await _stt.stopListening();
    }
    await _statusController.close();
  }
}
