import 'dart:async';

import 'package:fpdart/fpdart.dart';

import 'tts_engine.dart';

/// Tracks recent detection announcements for duplicate suppression.
final class _SuppressionEntry {
  const _SuppressionEntry({
    required this.objectKey,
    required this.zone,
    required this.timestamp,
  });

  final String objectKey;
  final String zone;
  final DateTime timestamp;
}

// ---------------------------------------------------------------------------
// Speech Coordinator Events
// ---------------------------------------------------------------------------

sealed class SpeechCoordinatorEvent {
  const SpeechCoordinatorEvent();
}

final class SpeechCoordinatorStarted extends SpeechCoordinatorEvent {
  const SpeechCoordinatorStarted(this.text);
  final String text;

  @override
  String toString() => 'SpeechCoordinatorStarted(text: $text)';
}

final class SpeechCoordinatorCompleted extends SpeechCoordinatorEvent {
  const SpeechCoordinatorCompleted();

  @override
  String toString() => 'SpeechCoordinatorCompleted()';
}

final class SpeechCoordinatorStopped extends SpeechCoordinatorEvent {
  const SpeechCoordinatorStopped();

  @override
  String toString() => 'SpeechCoordinatorStopped()';
}

final class SpeechCoordinatorError extends SpeechCoordinatorEvent {
  const SpeechCoordinatorError(this.failure);
  final TtsFailure failure;

  @override
  String toString() => 'SpeechCoordinatorError(failure: $failure)';
}

// ---------------------------------------------------------------------------
// Request internal hierarchy
// ---------------------------------------------------------------------------

sealed class _CoordinatorRequest {
  const _CoordinatorRequest({required this.text, this.rate});
  final String text;
  final SpeechRate? rate;
}

final class _DirectRequest extends _CoordinatorRequest {
  const _DirectRequest({required super.text, super.rate});
}

final class _DetectionRequest extends _CoordinatorRequest {
  const _DetectionRequest({
    required super.text,
    required this.objectKey,
    required this.zone,
    super.rate,
  });

  final String objectKey;
  final String zone;
}

// ---------------------------------------------------------------------------
// SpeechCoordinator
// ---------------------------------------------------------------------------

/// Coordinates speech playback across OCR, voice commands, and object detection.
///
/// Ensures:
/// - Single queue: avoids overlapping voices.
/// - Interruptible playback: [stop] immediately clears pending items and cancels playback.
/// - Detection duplicate suppression: filters out repeat (objectKey, zone) announcements
///   within the configured suppression window.
/// - Direct requests (OCR, commands) always bypass suppression.
final class SpeechCoordinator {
  SpeechCoordinator({
    required TtsEngine engine,
    SpeechSettings settings = SpeechSettings.defaults,
    DateTime Function()? clock,
  })  : _engine = engine,
        _settings = settings,
        _clock = clock ?? DateTime.now;

  final TtsEngine _engine;
  SpeechSettings _settings;
  final DateTime Function() _clock;

  bool _disposed = false;
  bool _isSpeaking = false;

  final List<_CoordinatorRequest> _queue = [];
  final List<_SuppressionEntry> _suppressionLog = [];
  StreamSubscription<TtsPlaybackEvent>? _engineSub;

  final _eventsController =
      StreamController<SpeechCoordinatorEvent>.broadcast();

  Stream<SpeechCoordinatorEvent> get events => _eventsController.stream;
  SpeechSettings get settings => _settings;
  bool get isSpeaking => _isSpeaking;

  /// Subscribes to engine playback events. Call once upon creation.
  void initialize() {
    if (_disposed) return;
    _engineSub = _engine.playbackEvents.listen(
      _onEnginePlaybackEvent,
      onError: (Object error) {
        if (!_disposed && !_eventsController.isClosed) {
          _eventsController.add(
            SpeechCoordinatorError(TtsSpeakError(error.toString())),
          );
        }
      },
    );
  }

  /// Updates speech settings (speech rate, feedback, suppression window).
  void updateSettings(SpeechSettings newSettings) {
    _settings = newSettings;
  }

  /// Speaks text directly (e.g. OCR result, system message). Bypasses suppression.
  Future<Either<TtsFailure, void>> speakDirect(
    String text, {
    SpeechRate? rate,
  }) async {
    if (_disposed) return left(const TtsAlreadyDisposed());
    final trimmed = text.trim();
    if (trimmed.isEmpty) return right(null);

    return _enqueue(
      _DirectRequest(
        text: trimmed,
        rate: rate ?? _settings.speechRate,
      ),
    );
  }

  /// Speaks an object detection announcement with duplicate suppression.
  Future<Either<TtsFailure, void>> announceDetection({
    required String text,
    required String objectKey,
    required String zone,
    SpeechRate? rate,
  }) async {
    if (_disposed) return left(const TtsAlreadyDisposed());
    if (!_settings.feedbackEnabled) return right(null);

    final trimmed = text.trim();
    if (trimmed.isEmpty) return right(null);

    final request = _DetectionRequest(
      text: trimmed,
      objectKey: objectKey,
      zone: zone,
      rate: rate ?? _settings.speechRate,
    );

    if (_isSuppressed(request)) {
      return right(null);
    }

    return _enqueue(request);
  }

  /// Stops current speech, empties the queue, and prevents pending speech.
  Future<void> stop() async {
    if (_disposed) return;
    _queue.clear();
    _isSpeaking = false;
    await _engine.stop();
    if (!_eventsController.isClosed) {
      _eventsController.add(const SpeechCoordinatorStopped());
    }
  }

  /// Resets the duplicate suppression history (e.g. upon mode/session change).
  void resetSession() {
    _suppressionLog.clear();
  }

  /// Disposes coordinator resources.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _queue.clear();
    _isSpeaking = false;
    await _engineSub?.cancel();
    _engineSub = null;
    await _engine.stop();
    await _eventsController.close();
  }

  // -------------------------------------------------------------------------
  // Private Helpers
  // -------------------------------------------------------------------------

  Future<Either<TtsFailure, void>> _enqueue(_CoordinatorRequest request) async {
    // If incoming request is a direct request (OCR / high priority),
    // clear the queue to avoid stale items queuing up.
    if (request is _DirectRequest) {
      _queue.clear();
    }

    _queue.add(request);

    if (!_isSpeaking) {
      await _playNext();
    }
    return right(null);
  }

  Future<void> _playNext() async {
    if (_disposed || _queue.isEmpty) {
      _isSpeaking = false;
      return;
    }

    final request = _queue.removeAt(0);
    _isSpeaking = true;

    if (request is _DetectionRequest) {
      _recordSuppression(request);
    }

    if (!_eventsController.isClosed) {
      _eventsController.add(SpeechCoordinatorStarted(request.text));
    }

    final result = await _engine.speak(
      request.text,
      rate: request.rate ?? _settings.speechRate,
    );

    result.fold(
      (failure) {
        _isSpeaking = false;
        if (!_eventsController.isClosed) {
          _eventsController.add(SpeechCoordinatorError(failure));
        }
        // Try next in queue if any
        if (_queue.isNotEmpty) {
          unawaited(_playNext());
        }
      },
      (_) {
        // Speech successfully dispatched to engine;
        // completion/next is handled via playbackEvents stream.
      },
    );
  }

  void _onEnginePlaybackEvent(TtsPlaybackEvent event) {
    if (_disposed) return;

    switch (event) {
      case TtsPlaybackEvent.completed:
        _isSpeaking = false;
        if (!_eventsController.isClosed) {
          _eventsController.add(const SpeechCoordinatorCompleted());
        }
        if (_queue.isNotEmpty) {
          unawaited(_playNext());
        }
      case TtsPlaybackEvent.stopped:
        _isSpeaking = false;
      case TtsPlaybackEvent.error:
        _isSpeaking = false;
        if (!_eventsController.isClosed) {
          _eventsController.add(
            const SpeechCoordinatorError(TtsSpeakError('Engine playback error')),
          );
        }
      case TtsPlaybackEvent.started:
        _isSpeaking = true;
    }
  }

  bool _isSuppressed(_DetectionRequest request) {
    if (!_settings.suppressionEnabled) return false;

    final now = _clock();
    final windowDuration =
        Duration(seconds: _settings.suppressionWindowSeconds);

    // Evict old entries outside window
    _suppressionLog.removeWhere(
      (entry) => now.difference(entry.timestamp) > windowDuration,
    );

    return _suppressionLog.any(
      (entry) =>
          entry.objectKey == request.objectKey && entry.zone == request.zone,
    );
  }

  void _recordSuppression(_DetectionRequest request) {
    _suppressionLog.add(
      _SuppressionEntry(
        objectKey: request.objectKey,
        zone: request.zone,
        timestamp: _clock(),
      ),
    );
  }
}
