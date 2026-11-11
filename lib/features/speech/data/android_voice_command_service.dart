import 'dart:async';

import 'package:flutter/services.dart';

import '../../../shared/assistance_contracts/voice_command_contract.dart';

final class AndroidVoiceCommandService implements VoiceCommandContract {
  AndroidVoiceCommandService({
    MethodChannel channel = const MethodChannel('seemate/voice_commands'),
  }) : _channel = channel {
    _channel.setMethodCallHandler(_onEvent);
  }

  final MethodChannel _channel;
  bool _disposed = false;
  int _requestId = 0;
  void Function()? _onListening;

  Future<void> _onEvent(MethodCall call) async {
    if (call.method == 'listeningStarted' && call.arguments == _requestId) {
      final callback = _onListening;
      _onListening = null;
      callback?.call();
    }
  }

  @override
  Future<bool> isOfflineAvailable() async =>
      !_disposed && await _invoke<bool>('isOfflineAvailable') == true;

  @override
  Future<CommandResult> listenForCommand({
    Duration timeout = const Duration(seconds: 5),
    void Function()? onListening,
  }) async {
    if (_disposed) return _failed(VoiceCommandFailure.cancelled);
    final requestId = ++_requestId;
    _onListening = onListening;
    final result = await _invoke<Map<Object?, Object?>>('listen', {
      'timeoutMs': timeout.inMilliseconds,
      'requestId': requestId,
    });
    if (_disposed || requestId != _requestId) {
      return _failed(VoiceCommandFailure.cancelled);
    }
    _onListening = null;
    final text = result?['text'];
    return switch (result?['status']) {
      'recognized' when text is String => CommandResult.parse(text),
      'no_match' => _failed(VoiceCommandFailure.timeout),
      'audio_unavailable' => _failed(VoiceCommandFailure.audioUnavailable),
      'permission_denied' => _failed(VoiceCommandFailure.permissionDenied),
      'unavailable' => _failed(VoiceCommandFailure.unavailable),
      'cancelled' => _failed(VoiceCommandFailure.cancelled),
      _ => _failed(VoiceCommandFailure.recognition),
    };
  }

  static CommandResult _failed(VoiceCommandFailure failure) =>
      CommandResult(isUnderstood: false, isSupported: false, failure: failure);

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<void> stopListening() {
    _requestId++;
    _onListening = null;
    return _invoke<void>('stop');
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _onListening = null;
    _channel.setMethodCallHandler(null);
    unawaited(_invoke<void>('dispose'));
  }
}
