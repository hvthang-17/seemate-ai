import 'dart:async';

import 'package:fpdart/fpdart.dart';

import 'tts_engine.dart';

/// In-memory fake TTS engine for unit testing and local simulation.
final class FakeTtsEngine implements TtsEngine {
  FakeTtsEngine({TtsReadiness readiness = TtsReadiness.ready})
      : _readiness = readiness;

  TtsReadiness _readiness;
  bool _disposed = false;

  final List<String> spokenTexts = [];
  int stopCount = 0;
  SpeechRate? lastSpeechRate;

  final _eventController = StreamController<TtsPlaybackEvent>.broadcast();

  bool get isDisposed => _disposed;

  void setReadiness(TtsReadiness readiness) {
    _readiness = readiness;
  }

  void emitEvent(TtsPlaybackEvent event) {
    if (!_disposed && !_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  @override
  Future<TtsReadiness> checkReadiness() async => _readiness;

  @override
  Future<Either<TtsFailure, void>> speak(
    String text, {
    SpeechRate? rate,
  }) async {
    if (_disposed) {
      return left(const TtsAlreadyDisposed());
    }
    if (_readiness != TtsReadiness.ready) {
      return left(TtsNotReady(_readiness));
    }

    spokenTexts.add(text);
    lastSpeechRate = rate;

    emitEvent(TtsPlaybackEvent.started);
    // Simulate speech playback finishing
    emitEvent(TtsPlaybackEvent.completed);

    return right(null);
  }

  @override
  Future<void> stop() async {
    if (_disposed) return;
    stopCount++;
    emitEvent(TtsPlaybackEvent.stopped);
  }

  @override
  Stream<TtsPlaybackEvent> get playbackEvents => _eventController.stream;

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _readiness = TtsReadiness.disposed;
    await _eventController.close();
  }
}
