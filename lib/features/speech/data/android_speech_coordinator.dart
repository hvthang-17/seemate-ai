import 'dart:async';

import 'package:flutter/services.dart';

import '../../../shared/assistance_contracts/speech_coordinator_contract.dart';

/// Owns the Android TTS request queue and discards events for interrupted work.
final class AndroidSpeechCoordinator implements SpeechCoordinatorContract {
  AndroidSpeechCoordinator({
    MethodChannel channel = const MethodChannel('seemate/speech'),
    Duration Function()? elapsed,
  }) : _channel = channel,
       _elapsed = elapsed ?? _monotonicClock() {
    _channel.setMethodCallHandler(_handleEvent);
  }

  static const _unavailable = VoiceReadiness(
    isAvailable: false,
    isOffline: false,
  );
  static int _nextId = 0;

  final MethodChannel _channel;
  final Duration Function() _elapsed;
  final _states = StreamController<SpeechState>.broadcast();
  final _lastSpoken = <SuppressionKey, Duration>{};

  SpeechState _state = SpeechState.idle;
  Duration _suppressionInterval = const Duration(seconds: 2);
  double _rate = 1;
  _SpeechRequest? _active;
  _SpeechRequest? _pending;
  Future<void>? _interruption;
  bool _feedbackEnabled = true;
  bool _disposed = false;

  @override
  SpeechState get currentState => _state;

  @override
  Stream<SpeechState> get stateChanges => _states.stream;

  @override
  Future<VoiceReadiness> checkVoiceReadiness() async {
    if (_disposed) return _unavailable;
    try {
      final readiness = await _channel.invokeMapMethod<String, Object?>(
        'checkVoiceReadiness',
      );
      if (_disposed || readiness == null) return _unavailable;
      final engine = readiness['engineName'];
      final voice = readiness['voiceName'];
      return VoiceReadiness(
        isAvailable: readiness['available'] == true,
        isOffline: readiness['offline'] == true,
        engineName: engine is String ? engine : null,
        voiceName: voice is String ? voice : null,
      );
    } on PlatformException {
      return _unavailable;
    } on MissingPluginException {
      return _unavailable;
    }
  }

  @override
  Future<bool> speak(
    String text, {
    SpeechPriority priority = SpeechPriority.normal,
    SuppressionKey? suppressionKey,
  }) async {
    if (_disposed) return false;
    if (priority == SpeechPriority.immediateStop) {
      await stop();
      return false;
    }
    if (text.trim().isEmpty || _isSuppressed(suppressionKey)) return false;

    final pending = _pending;
    if (pending != null && pending.priority.index > priority.index) {
      return false;
    }

    final request = _SpeechRequest(
      id: '${DateTime.now().microsecondsSinceEpoch}-${++_nextId}',
      text: text,
      priority: priority,
      suppressionKey: suppressionKey,
    );
    pending?.complete(false);
    _pending = request;

    final active = _active;
    if (active != null && priority.index > active.priority.index) {
      active.complete(false);
      _active = null;
      unawaited(_interrupt());
    } else {
      _advance();
    }
    return request.accepted.future;
  }

  bool _isSuppressed(SuppressionKey? key) {
    if (key == null) return false;
    if (!_feedbackEnabled ||
        _active?.suppressionKey == key ||
        _pending?.suppressionKey == key) {
      return true;
    }
    final last = _lastSpoken[key];
    return last != null && _elapsed() - last < _suppressionInterval;
  }

  void _advance() {
    if (_disposed || _interruption != null || _active != null) return;
    final request = _pending;
    if (request == null) return;
    _pending = null;
    if (_isSuppressed(request.suppressionKey)) {
      request.complete(false);
      return;
    }

    _active = request;
    unawaited(_send(request));
  }

  Future<void> _send(_SpeechRequest request) async {
    var accepted = false;
    try {
      accepted =
          await _channel.invokeMethod<bool>('speak', {
            'id': request.id,
            'text': request.text,
            'rate': _rate,
          }) ==
          true;
    } on PlatformException {
      // Treat the platform failure like a rejected utterance.
    } on MissingPluginException {
      // The coordinator can also be constructed in platform-free tests.
    }
    if (!identical(_active, request)) return;
    request.complete(accepted);
    if (!accepted) _finish(SpeechState.error);
  }

  Future<void> _handleEvent(MethodCall call) async {
    final request = _active;
    final data = call.arguments;
    if (call.method != 'utteranceEvent' ||
        request == null ||
        data is! Map<Object?, Object?> ||
        data['id'] != request.id) {
      return;
    }

    switch (data['state']) {
      case 'speaking':
        final key = request.suppressionKey;
        if (key != null) _lastSpoken[key] = _elapsed();
        request.complete(true);
        _emit(SpeechState.speaking);
      case 'done':
        request.complete(true);
        _finish(SpeechState.idle);
      case 'stopped':
        request.complete(false);
        _finish(SpeechState.stopped);
      case 'error':
        request.complete(false);
        _finish(SpeechState.error);
    }
  }

  void _finish(SpeechState state) {
    _active = null;
    _emit(state);
    _advance();
  }

  void _emit(SpeechState state) {
    if (_disposed || _state == state) return;
    _state = state;
    _states.add(state);
  }

  @override
  Future<void> stop() {
    if (_disposed) return Future<void>.value();
    _cancelRequests();
    _lastSpoken.clear();
    return _interrupt();
  }

  Future<void> _interrupt() {
    final existing = _interruption;
    if (existing != null) return existing;
    _emit(SpeechState.stopped);
    final operation = _stopNative();
    _interruption = operation;
    return operation;
  }

  Future<void> _stopNative() async {
    try {
      await _channel.invokeMethod<void>('stop');
      _emit(SpeechState.idle);
    } on PlatformException {
      _cancelRequests();
      _emit(SpeechState.error);
    } on MissingPluginException {
      _cancelRequests();
      _emit(SpeechState.error);
    } finally {
      _interruption = null;
      _advance();
    }
  }

  void _cancelRequests() {
    _active?.complete(false);
    _pending?.complete(false);
    _active = null;
    _pending = null;
  }

  /// Affects automatic detection feedback while preserving explicit reading.
  @override
  void setSpokenFeedbackEnabled(bool enabled) {
    _feedbackEnabled = enabled;
    if (!enabled && _active?.suppressionKey != null) {
      unawaited(stop());
    }
  }

  @override
  void updateSuppressionInterval(Duration interval) {
    if (!interval.isNegative) _suppressionInterval = interval;
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    if (rate.isFinite) _rate = rate.clamp(0.5, 2.0).toDouble();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cancelRequests();
    _channel.setMethodCallHandler(null);
    unawaited(_states.close());
    unawaited(_disposeNative());
  }

  Future<void> _disposeNative() async {
    try {
      await _channel.invokeMethod<void>('dispose');
    } on PlatformException {
      // Engine detachment also releases the Android TTS instance.
    } on MissingPluginException {
      // There is no native engine to release.
    }
  }

  static Duration Function() _monotonicClock() {
    final stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsed;
  }
}

final class _SpeechRequest {
  _SpeechRequest({
    required this.id,
    required this.text,
    required this.priority,
    required this.suppressionKey,
  });

  final String id;
  final String text;
  final SpeechPriority priority;
  final SuppressionKey? suppressionKey;
  final accepted = Completer<bool>();

  void complete(bool value) {
    if (!accepted.isCompleted) accepted.complete(value);
  }
}
