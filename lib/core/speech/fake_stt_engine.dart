import 'dart:async';

import 'stt_engine.dart';

/// In-memory fake STT engine for unit testing and local command session simulations.
final class FakeSttEngine implements SttEngine {
  FakeSttEngine({
    SttAvailability availability = SttAvailability.available,
  }) : _availability = availability;

  SttAvailability _availability;
  bool _isListening = false;
  bool _disposed = false;

  void Function(String partial)? _onPartial;
  void Function(String finalResult)? _onFinal;
  void Function(String error)? _onError;

  int startCount = 0;
  int stopCount = 0;

  bool get isListening => _isListening;
  bool get isDisposed => _disposed;

  void setAvailability(SttAvailability availability) {
    _availability = availability;
  }

  /// Simulates an intermediate/partial speech recognition result.
  void deliverPartial(String partial) {
    if (_isListening && !_disposed) {
      _onPartial?.call(partial);
    }
  }

  /// Simulates the final recognized transcript.
  void deliverFinal(String finalResult) {
    if (_isListening && !_disposed) {
      _onFinal?.call(finalResult);
      _isListening = false;
    }
  }

  /// Simulates an STT engine or microphone error.
  void deliverError(String error) {
    if (_isListening && !_disposed) {
      _onError?.call(error);
      _isListening = false;
    }
  }

  @override
  Future<SttAvailability> checkAvailability() async => _availability;

  @override
  Future<bool> startListening({
    required void Function(String partial) onPartial,
    required void Function(String finalResult) onFinal,
    required void Function(String error) onError,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (_disposed || _availability != SttAvailability.available) {
      return false;
    }

    startCount++;
    _isListening = true;
    _onPartial = onPartial;
    _onFinal = onFinal;
    _onError = onError;
    return true;
  }

  @override
  Future<void> stopListening() async {
    if (_disposed) return;
    stopCount++;
    _isListening = false;
    _onPartial = null;
    _onFinal = null;
    _onError = null;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stopListening();
  }
}
