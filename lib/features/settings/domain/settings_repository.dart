import '../../../shared/assistance_contracts/speech_contract.dart';

/// Contract for persisting user speech and accessibility preferences.
abstract interface class SettingsRepository {
  /// Loads speech settings from persistent storage or returns defaults.
  Future<SpeechSettings> loadSpeechSettings();

  /// Persists speech settings to storage.
  Future<void> saveSpeechSettings(SpeechSettings settings);
}
