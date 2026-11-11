import 'package:fpdart/fpdart.dart';

import '../assistance_preferences_contract.dart';

/// In-memory fake implementation of [AssistancePreferencesContract] for tests.
class FakeAssistancePreferencesRepository
    implements AssistancePreferencesContract {
  FakeAssistancePreferencesRepository({
    AssistancePreferences? initialPreferences,
    this.failOnLoad = false,
    this.failOnSave = false,
  }) : _preferences = initialPreferences ?? const AssistancePreferences();

  AssistancePreferences _preferences;
  bool failOnLoad;
  bool failOnSave;

  AssistancePreferences get current => _preferences;

  @override
  Future<Either<PreferencesFailure, AssistancePreferences>> loadPreferences() async {
    if (failOnLoad) {
      return const Left(PreferencesLoadFailure('Simulated load error'));
    }
    return Right(_preferences);
  }

  @override
  Future<Either<PreferencesFailure, void>> savePreferences(
    AssistancePreferences preferences,
  ) async {
    if (failOnSave) {
      return const Left(PreferencesSaveFailure('Simulated save error'));
    }
    _preferences = preferences;
    return const Right(null);
  }
}
