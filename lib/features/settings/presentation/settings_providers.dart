import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/assistance_contracts/speech_contract.dart';
import '../data/hive_settings_repository.dart';
import '../domain/settings_repository.dart';

/// Provides the active [SettingsRepository] implementation.
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return HiveSettingsRepository();
});

/// Riverpod state notifier for user speech and audio feedback preferences.
final speechSettingsProvider =
    NotifierProvider<SpeechSettingsNotifier, SpeechSettings>(
  SpeechSettingsNotifier.new,
);

class SpeechSettingsNotifier extends Notifier<SpeechSettings> {
  @override
  SpeechSettings build() {
    _loadPersisted();
    return SpeechSettings.defaults;
  }

  Future<void> _loadPersisted() async {
    final repo = ref.read(settingsRepositoryProvider);
    final loaded = await repo.loadSpeechSettings();
    state = loaded;
  }

  Future<void> updateSpeechRate(SpeechRate newRate) async {
    state = state.copyWith(speechRate: newRate);
    await ref.read(settingsRepositoryProvider).saveSpeechSettings(state);
  }

  Future<void> setFeedbackEnabled(bool enabled) async {
    state = state.copyWith(feedbackEnabled: enabled);
    await ref.read(settingsRepositoryProvider).saveSpeechSettings(state);
  }

  Future<void> setSuppressionEnabled(bool enabled) async {
    state = state.copyWith(suppressionEnabled: enabled);
    await ref.read(settingsRepositoryProvider).saveSpeechSettings(state);
  }

  Future<void> setSuppressionWindow(int seconds) async {
    state = state.copyWith(suppressionWindowSeconds: seconds);
    await ref.read(settingsRepositoryProvider).saveSpeechSettings(state);
  }
}
