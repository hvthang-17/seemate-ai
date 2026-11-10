/// Domain contracts and typed failures for settings persistence.
library;

import 'package:fpdart/fpdart.dart';

import 'speech_contract.dart';

export 'speech_contract.dart' show SpeechRate, SpeechSettings;

// ---------------------------------------------------------------------------
// Settings Failures
// ---------------------------------------------------------------------------

sealed class SettingsFailure {
  const SettingsFailure();
}

final class SettingsLoadFailure extends SettingsFailure {
  const SettingsLoadFailure(this.message);
  final String message;

  @override
  String toString() => 'SettingsLoadFailure(message: $message)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingsLoadFailure && message == other.message;

  @override
  int get hashCode => message.hashCode;
}

final class SettingsSaveFailure extends SettingsFailure {
  const SettingsSaveFailure(this.message);
  final String message;

  @override
  String toString() => 'SettingsSaveFailure(message: $message)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingsSaveFailure && message == other.message;

  @override
  int get hashCode => message.hashCode;
}

final class SettingsInvalidValue extends SettingsFailure {
  const SettingsInvalidValue(this.field, this.value);
  final String field;
  final Object? value;

  @override
  String toString() => 'SettingsInvalidValue(field: $field, value: $value)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingsInvalidValue &&
          field == other.field &&
          value == other.value;

  @override
  int get hashCode => Object.hash(field, value);
}

// ---------------------------------------------------------------------------
// SettingsRepository Contract
// ---------------------------------------------------------------------------

abstract interface class SettingsRepository {
  /// Loads persisted user preferences.
  /// Returns [SpeechSettings.defaults] if no settings are currently stored.
  Future<Either<SettingsFailure, SpeechSettings>> load();

  /// Persists the provided user settings.
  /// Does NOT report success until the underlying store completes.
  Future<Either<SettingsFailure, void>> save(SpeechSettings settings);
}
