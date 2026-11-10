import 'dart:async';
import 'dart:io';

import 'package:fpdart/fpdart.dart';

import 'tts_engine.dart';

/// Production TTS adapter for Android/iOS offline Vietnamese speech.
///
/// BACKING PLUGIN REQUIREMENT:
/// N1 adds to `pubspec.yaml`:
/// ```yaml
/// flutter_tts: ^4.2.1
/// ```
///
/// This adapter implements [TtsEngine] and executes real speech when a plugin instance
/// is injected or initialized. If no plugin is present, it safely reports [TtsReadiness.missingEngine].
final class OfflineTtsAdapter implements TtsEngine {
  OfflineTtsAdapter({dynamic flutterTts}) : _flutterTts = flutterTts;

  static const String vietnameseLocale = 'vi-VN';

  bool _disposed = false;
  bool _initialized = false;
  TtsReadiness _readiness = TtsReadiness.missingEngine;
  SpeechRate _currentRate = SpeechRate.defaultRate;

  final _eventController = StreamController<TtsPlaybackEvent>.broadcast();

  // Reference to FlutterTts (typed dynamic so it compiles before pubspec.yaml includes flutter_tts)
  dynamic _flutterTts;

  String? detectedEngine;
  List<Map<String, dynamic>> detectedVoices = [];
  bool hasOfflineVietnameseVoice = false;

  bool get isInitialized => _initialized;

  /// Initializes the TTS engine and verifies offline Vietnamese voice availability.
  Future<TtsReadiness> initialize({dynamic pluginInstance}) async {
    if (_disposed) return TtsReadiness.disposed;
    if (_initialized && _flutterTts != null) return _readiness;

    if (pluginInstance != null) {
      _flutterTts = pluginInstance;
    }

    if (_flutterTts == null) {
      _readiness = TtsReadiness.missingEngine;
      _initialized = true;
      return _readiness;
    }

    try {
      // 1. Check native engine availability (Android)
      if (Platform.isAndroid) {
        try {
          final dynamic engines = await _flutterTts.getEngines;
          if (engines is List && engines.isNotEmpty) {
            detectedEngine = engines.first.toString();
            final dynamic defaultEngine = await _flutterTts.getDefaultEngine;
            if (defaultEngine != null) {
              detectedEngine = defaultEngine.toString();
            }
          }
        } on NoSuchMethodError {
          // Plugin instance without getEngines
        }
      }

      // 2. Query language availability for Vietnamese (vi-VN)
      final dynamic isLangAvailable =
          await _flutterTts.isLanguageAvailable(vietnameseLocale);
      final bool viAvailable = isLangAvailable == 1 ||
          isLangAvailable == true ||
          isLangAvailable == 'true';

      if (!viAvailable) {
        _readiness = TtsReadiness.missingVietnameseVoice;
        _initialized = true;
        return _readiness;
      }

      // 3. Inspect available voices on the device
      try {
        final dynamic rawVoices = await _flutterTts.getVoices;
        detectedVoices = [];
        hasOfflineVietnameseVoice = false;

        if (rawVoices is List) {
          for (final voice in rawVoices) {
            if (voice is Map) {
              final voiceMap = Map<String, dynamic>.from(voice);
              final locale = voiceMap['locale']?.toString() ?? '';
              if (locale.toLowerCase().startsWith('vi')) {
                detectedVoices.add(voiceMap);
                final requiresNetwork = voiceMap['networkConnectionRequired'];
                if (requiresNetwork == false || requiresNetwork == 'false') {
                  hasOfflineVietnameseVoice = true;
                }
              }
            }
          }
        }
      } on NoSuchMethodError {
        // Voice query not supported by mock/fake
      }

      // 4. Configure engine defaults
      await _flutterTts.setLanguage(vietnameseLocale);
      await _flutterTts.setSpeechRate(0.5); // Normal reading speed
      await _flutterTts.setPitch(1.0);

      // 5. Register native lifecycle handlers
      _flutterTts.setStartHandler(() {
        if (!_disposed && !_eventController.isClosed) {
          _eventController.add(TtsPlaybackEvent.started);
        }
      });
      _flutterTts.setCompletionHandler(() {
        if (!_disposed && !_eventController.isClosed) {
          _eventController.add(TtsPlaybackEvent.completed);
        }
      });
      _flutterTts.setCancelHandler(() {
        if (!_disposed && !_eventController.isClosed) {
          _eventController.add(TtsPlaybackEvent.stopped);
        }
      });
      _flutterTts.setErrorHandler((dynamic msg) {
        if (!_disposed && !_eventController.isClosed) {
          _eventController.add(TtsPlaybackEvent.error);
        }
      });

      _readiness = TtsReadiness.ready;
      _initialized = true;
      return _readiness;
    } on Exception {
      _readiness = TtsReadiness.initializationFailure;
      _initialized = true;
      return _readiness;
    }
  }

  @override
  Future<TtsReadiness> checkReadiness() async {
    if (_disposed) return TtsReadiness.disposed;
    return _readiness;
  }

  @override
  Future<Either<TtsFailure, void>> speak(
    String text, {
    SpeechRate? rate,
  }) async {
    if (_disposed) return left(const TtsAlreadyDisposed());
    if (_readiness != TtsReadiness.ready || _flutterTts == null) {
      return left(TtsNotReady(_readiness));
    }

    try {
      final effectiveRate = rate ?? _currentRate;
      _currentRate = effectiveRate;

      // Note: flutter_tts rate scale is 0.0 to 1.0 (0.5 is normal speed)
      final pluginRate = (effectiveRate.value * 0.5).clamp(0.1, 1.0);
      await _flutterTts.setSpeechRate(pluginRate);
      await _flutterTts.speak(text);

      return right(null);
    } on Exception catch (e) {
      _eventController.add(TtsPlaybackEvent.error);
      return left(TtsSpeakError(e.toString()));
    }
  }

  @override
  Future<void> stop() async {
    if (_disposed) return;
    try {
      if (_flutterTts != null) {
        await _flutterTts.stop();
      }
    } finally {
      _eventController.add(TtsPlaybackEvent.stopped);
    }
  }

  @override
  Stream<TtsPlaybackEvent> get playbackEvents => _eventController.stream;

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _readiness = TtsReadiness.disposed;
    try {
      if (_flutterTts != null) {
        await _flutterTts.stop();
      }
    } finally {
      await _eventController.close();
    }
  }
}
