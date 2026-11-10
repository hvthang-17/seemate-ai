import 'package:hive/hive.dart';

import '../../../shared/assistance_contracts/speech_contract.dart';
import '../domain/settings_repository.dart';

/// Hive-backed persistence for user speech preferences.
class HiveSettingsRepository implements SettingsRepository {
  HiveSettingsRepository({Box? box}) : _box = box;

  static const String boxName = 'seemate_settings_box';
  static const String keySpeechRate = 'speech_rate';
  static const String keyFeedbackEnabled = 'feedback_enabled';
  static const String keySuppressionEnabled = 'suppression_enabled';
  static const String keySuppressionWindow = 'suppression_window_seconds';

  Box? _box;

  Future<Box> _getBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await Hive.openBox(boxName);
    return _box!;
  }

  @override
  Future<SpeechSettings> loadSpeechSettings() async {
    try {
      final box = await _getBox();
      final rate = box.get(keySpeechRate, defaultValue: 1.0) as double;
      final feedback = box.get(keyFeedbackEnabled, defaultValue: true) as bool;
      final suppression = box.get(keySuppressionEnabled, defaultValue: true) as bool;
      final window = box.get(keySuppressionWindow, defaultValue: 5) as int;

      return SpeechSettings(
        speechRate: SpeechRate.clamp(rate),
        feedbackEnabled: feedback,
        suppressionEnabled: suppression,
        suppressionWindowSeconds: window,
      );
    } catch (_) {
      return SpeechSettings.defaults;
    }
  }

  @override
  Future<void> saveSpeechSettings(SpeechSettings settings) async {
    try {
      final box = await _getBox();
      await box.put(keySpeechRate, settings.speechRate.value);
      await box.put(keyFeedbackEnabled, settings.feedbackEnabled);
      await box.put(keySuppressionEnabled, settings.suppressionEnabled);
      await box.put(keySuppressionWindow, settings.suppressionWindowSeconds);
    } catch (_) {}
  }
}
