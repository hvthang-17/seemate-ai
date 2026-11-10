import 'package:fpdart/fpdart.dart';

import '../repositories/settings_repository.dart';

/// Clean Architecture use case to validate and persist user speech settings.
final class SaveSettings {
  const SaveSettings(this._repository);

  final SettingsRepository _repository;

  Future<Either<SettingsFailure, void>> call(SpeechSettings settings) async {
    // 1. Validate speech rate range [0.1, 2.0]
    final rateValue = settings.speechRate.value;
    if (rateValue < SpeechRate.min || rateValue > SpeechRate.max) {
      return left(
        SettingsInvalidValue('speechRate', rateValue),
      );
    }

    // 2. Validate suppression window >= 0
    if (settings.suppressionWindowSeconds < 0) {
      return left(
        SettingsInvalidValue(
          'suppressionWindowSeconds',
          settings.suppressionWindowSeconds,
        ),
      );
    }

    // 3. Delegate to repository
    return _repository.save(settings);
  }
}
