import 'package:fpdart/fpdart.dart';

import '../repositories/settings_repository.dart';

/// Clean Architecture use case to load persisted user speech settings.
final class LoadSettings {
  const LoadSettings(this._repository);

  final SettingsRepository _repository;

  Future<Either<SettingsFailure, SpeechSettings>> call() =>
      _repository.load();
}
