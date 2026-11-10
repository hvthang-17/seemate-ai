import 'dart:async';

import 'stt_engine.dart';

/// Production STT adapter backed by Android's native SpeechRecognizer via `speech_to_text`.
///
/// BACKING PLUGIN REQUIREMENT:
/// N1 adds to `pubspec.yaml`:
/// ```yaml
/// speech_to_text: ^7.0.0
/// ```
/// And adds `<uses-permission android:name="android.permission.RECORD_AUDIO"/>` to AndroidManifest.xml.
final class VoiceCommandAdapter implements SttEngine {
  VoiceCommandAdapter({dynamic speechToText}) : _speechToText = speechToText;

  static const String vietnameseLocale = 'vi_VN';

  bool _initialized = false;
  bool _disposed = false;
  bool _isListening = false;
  SttAvailability _availability = SttAvailability.notAvailable;
  String? _selectedLocaleId;
  bool _hasVietnameseVoice = false;

  // Kept dynamic for compilation prior to N1 adding speech_to_text to pubspec.yaml
  dynamic _speechToText;

  @override
  bool get isListening => _isListening;
  bool get isInitialized => _initialized;
  String? get selectedLocaleId => _selectedLocaleId;
  bool get hasVietnameseVoice => _hasVietnameseVoice;

  /// Initializes the STT engine and checks Vietnamese locale support.
  Future<SttAvailability> initialize({dynamic pluginInstance}) async {
    if (_disposed) return SttAvailability.notAvailable;
    if (_initialized && _speechToText != null) return _availability;

    if (pluginInstance != null) {
      _speechToText = pluginInstance;
    }

    if (_speechToText == null) {
      _availability = SttAvailability.notAvailable;
      _initialized = true;
      return _availability;
    }

    try {
      final available = await _speechToText.initialize(
        onError: (dynamic error) => _isListening = false,
        onStatus: (dynamic status) {
          if (status == 'notListening' || status == 'done') {
            _isListening = false;
          }
        },
        debugLogging: false,
      );

      if (!available) {
        final dynamic hasPerm = await _speechToText.hasPermission;
        if (hasPerm == false) {
          _availability = SttAvailability.permissionDenied;
          _initialized = true;
          return _availability;
        }
        _availability = SttAvailability.notAvailable;
        _initialized = true;
        return _availability;
      }

      // Check available locales for Vietnamese
      try {
        final dynamic rawLocales = await _speechToText.locales();
        if (rawLocales is List) {
          for (final loc in rawLocales) {
            final locId = loc.localeId?.toString() ?? loc.toString();
            if (locId.toLowerCase().startsWith('vi')) {
              _selectedLocaleId = locId;
              _hasVietnameseVoice = true;
              break;
            }
          }
        }
      } on NoSuchMethodError {
        // Fallback default
        _selectedLocaleId = vietnameseLocale;
        _hasVietnameseVoice = true;
      }

      if (!_hasVietnameseVoice) {
        _availability = SttAvailability.vietnameseNotSupported;
        _initialized = true;
        return _availability;
      }

      _availability = SttAvailability.available;
      _initialized = true;
      return _availability;
    } on Exception {
      _availability = SttAvailability.notAvailable;
      _initialized = true;
      return _availability;
    }
  }

  @override
  Future<SttAvailability> checkAvailability() async {
    if (_disposed) return SttAvailability.notAvailable;
    return _availability;
  }

  @override
  Future<bool> startListening({
    required void Function(String partial) onPartial,
    required void Function(String finalResult) onFinal,
    required void Function(String error) onError,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (_disposed || _speechToText == null) {
      return false;
    }

    if (_availability != SttAvailability.available) {
      onError('Nhận diện giọng nói chưa sẵn sàng trên thiết bị.');
      return false;
    }

    try {
      _isListening = true;

      await _speechToText.listen(
        onResult: (dynamic result) {
          final words = result.recognizedWords?.toString() ?? '';
          final bool isFinal = result.finalResult == true;
          if (isFinal) {
            _isListening = false;
            onFinal(words);
          } else {
            onPartial(words);
          }
        },
        localeId: _selectedLocaleId ?? vietnameseLocale,
        listenFor: timeout,
        pauseFor: const Duration(seconds: 3),
      );
      return true;
    } on Exception catch (e) {
      _isListening = false;
      onError(e.toString());
      return false;
    }
  }

  @override
  Future<void> stopListening() async {
    if (_disposed || _speechToText == null) return;
    try {
      await _speechToText.stop();
    } finally {
      _isListening = false;
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      if (_speechToText != null) {
        await _speechToText.stop();
      }
    } finally {
      _isListening = false;
    }
  }
}
