import 'package:fpdart/fpdart.dart';

import '../../../../shared/assistance_contracts/settings_contract.dart';
import '../../domain/repositories/settings_repository.dart';
import '../sources/settings_local_source.dart';

/// Concrete implementation of [SettingsRepository] delegating to [SettingsLocalSource].
final class SettingsRepositoryImpl implements SettingsRepository {
  const SettingsRepositoryImpl(this._source);

  final SettingsLocalSource _source;

  @override
  Future<Either<SettingsFailure, SpeechSettings>> load() => _source.load();

  @override
  Future<Either<SettingsFailure, void>> save(SpeechSettings settings) =>
      _source.save(settings);
}
