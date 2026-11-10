/// Value objects and settings for speech / TTS configuration.
library;

import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';

// ---------------------------------------------------------------------------
// SpeechRate
// ---------------------------------------------------------------------------

/// Strongly-typed speech rate value. Valid range: [0.1, 2.0].
@immutable
final class SpeechRate {
  const SpeechRate(this.value);

  static const double min = 0.1;
  static const double max = 2.0;
  static const SpeechRate defaultRate = SpeechRate(1.0);

  final double value;

  /// Returns a [SpeechRate] clamped to [min, max].
  static SpeechRate clamp(double raw) =>
      SpeechRate(raw.clamp(min, max).toDouble());

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SpeechRate && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'SpeechRate($value)';
}

// ---------------------------------------------------------------------------
// SpeechSettings
// ---------------------------------------------------------------------------

/// Immutable speech preferences persisted on-device.
@immutable
final class SpeechSettings {
  const SpeechSettings({
    this.speechRate = SpeechRate.defaultRate,
    this.feedbackEnabled = true,
    this.suppressionEnabled = true,
    this.suppressionWindowSeconds = 5,
  });

  /// Canonical defaults used when no persisted value exists.
  static const defaults = SpeechSettings();

  final SpeechRate speechRate;
  final bool feedbackEnabled;
  final bool suppressionEnabled;
  final int suppressionWindowSeconds;

  SpeechSettings copyWith({
    SpeechRate? speechRate,
    bool? feedbackEnabled,
    bool? suppressionEnabled,
    int? suppressionWindowSeconds,
  }) =>
      SpeechSettings(
        speechRate: speechRate ?? this.speechRate,
        feedbackEnabled: feedbackEnabled ?? this.feedbackEnabled,
        suppressionEnabled: suppressionEnabled ?? this.suppressionEnabled,
        suppressionWindowSeconds:
            suppressionWindowSeconds ?? this.suppressionWindowSeconds,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpeechSettings &&
          speechRate == other.speechRate &&
          feedbackEnabled == other.feedbackEnabled &&
          suppressionEnabled == other.suppressionEnabled &&
          suppressionWindowSeconds == other.suppressionWindowSeconds;

  @override
  int get hashCode => Object.hash(
        speechRate,
        feedbackEnabled,
        suppressionEnabled,
        suppressionWindowSeconds,
      );

  @override
  String toString() => 'SpeechSettings('
      'speechRate: $speechRate, '
      'feedbackEnabled: $feedbackEnabled, '
      'suppressionEnabled: $suppressionEnabled, '
      'suppressionWindowSeconds: $suppressionWindowSeconds)';
}

// ---------------------------------------------------------------------------
// TTS Types & Engine Contract
// ---------------------------------------------------------------------------

/// Readiness state of the TTS engine.
enum TtsReadiness {
  ready,
  missingEngine,
  missingVietnameseVoice,
  voiceRequiresNetwork,
  initializationFailure,
  disposed,
}

/// Playback lifecycle events emitted by the TTS engine.
enum TtsPlaybackEvent {
  started,
  completed,
  stopped,
  error,
}

/// Typed failure for TTS operations.
sealed class TtsFailure {
  const TtsFailure();
}

final class TtsNotReady extends TtsFailure {
  const TtsNotReady(this.readiness);
  final TtsReadiness readiness;

  @override
  String toString() => 'TtsNotReady(readiness: $readiness)';
}

final class TtsSpeakError extends TtsFailure {
  const TtsSpeakError(this.message);
  final String message;

  @override
  String toString() => 'TtsSpeakError(message: $message)';
}

final class TtsAlreadyDisposed extends TtsFailure {
  const TtsAlreadyDisposed();

  @override
  String toString() => 'TtsAlreadyDisposed()';
}

/// Abstract TTS engine interface.
abstract interface class TtsEngine {
  /// Check whether the engine is ready for playback.
  Future<TtsReadiness> checkReadiness();

  /// Speak [text]. Returns Left on failure, Right on enqueue/start success.
  Future<Either<TtsFailure, void>> speak(String text, {SpeechRate? rate});

  /// Stop current playback immediately and cancel pending queue.
  Future<void> stop();

  /// Stream of playback lifecycle events.
  Stream<TtsPlaybackEvent> get playbackEvents;

  /// Release all resources. Must not be called more than once.
  Future<void> dispose();
}
