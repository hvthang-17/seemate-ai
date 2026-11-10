// ignore_for_file: avoid_dynamic_calls

import 'dart:async';

import 'package:fpdart/fpdart.dart';

import '../../../../shared/assistance_contracts/settings_contract.dart';

/// Key-value storage abstraction for settings persistence.
abstract interface class SettingsKeyValueStore {
  Future<double?> getDouble(String key);
  Future<bool?> getBool(String key);
  Future<int?> getInt(String key);

  Future<Either<SettingsFailure, void>> setDouble(String key, double value);
  Future<Either<SettingsFailure, void>> setBool(String key, bool value);
  Future<Either<SettingsFailure, void>> setInt(String key, int value);
}

/// Storage keys for speech settings.
abstract final class SettingsKeys {
  static const String speechRate = 'seemate_settings_speech_rate';
  static const String feedbackEnabled = 'seemate_settings_feedback_enabled';
  static const String suppressionEnabled = 'seemate_settings_suppression_enabled';
  static const String suppressionWindowSeconds =
      'seemate_settings_suppression_window_seconds';
}

/// Local data source persisting and retrieving [SpeechSettings].
final class SettingsLocalSource {
  const SettingsLocalSource(this._store);

  final SettingsKeyValueStore _store;

  /// Loads stored settings from the key-value store.
  /// Falls back to defaults when keys are not found or values are corrupted.
  Future<Either<SettingsFailure, SpeechSettings>> load() async {
    try {
      final storedRate = await _store.getDouble(SettingsKeys.speechRate);
      final storedFeedback = await _store.getBool(SettingsKeys.feedbackEnabled);
      final storedSuppression =
          await _store.getBool(SettingsKeys.suppressionEnabled);
      final storedWindow =
          await _store.getInt(SettingsKeys.suppressionWindowSeconds);

      final speechRate = storedRate != null
          ? SpeechRate.clamp(storedRate)
          : SpeechSettings.defaults.speechRate;

      final feedbackEnabled =
          storedFeedback ?? SpeechSettings.defaults.feedbackEnabled;
      final suppressionEnabled =
          storedSuppression ?? SpeechSettings.defaults.suppressionEnabled;
      final suppressionWindow =
          storedWindow != null && storedWindow >= 0
              ? storedWindow
              : SpeechSettings.defaults.suppressionWindowSeconds;

      return right(
        SpeechSettings(
          speechRate: speechRate,
          feedbackEnabled: feedbackEnabled,
          suppressionEnabled: suppressionEnabled,
          suppressionWindowSeconds: suppressionWindow,
        ),
      );
    } on Exception catch (e) {
      return left(SettingsLoadFailure(e.toString()));
    }
  }

  /// Persists all fields of [SpeechSettings] to the key-value store.
  Future<Either<SettingsFailure, void>> save(SpeechSettings settings) async {
    try {
      final rateResult = await _store.setDouble(
        SettingsKeys.speechRate,
        settings.speechRate.value,
      );
      if (rateResult.isLeft()) return rateResult;

      final feedbackResult = await _store.setBool(
        SettingsKeys.feedbackEnabled,
        settings.feedbackEnabled,
      );
      if (feedbackResult.isLeft()) return feedbackResult;

      final suppressionResult = await _store.setBool(
        SettingsKeys.suppressionEnabled,
        settings.suppressionEnabled,
      );
      if (suppressionResult.isLeft()) return suppressionResult;

      final windowResult = await _store.setInt(
        SettingsKeys.suppressionWindowSeconds,
        settings.suppressionWindowSeconds,
      );
      if (windowResult.isLeft()) return windowResult;

      return right(null);
    } on Exception catch (e) {
      return left(SettingsSaveFailure(e.toString()));
    }
  }
}

// ---------------------------------------------------------------------------
// Testing Fake Key-Value Store
// ---------------------------------------------------------------------------

/// Pure in-memory key-value store for unit tests.
final class FakeSettingsKeyValueStore implements SettingsKeyValueStore {
  final Map<String, double> _doubles = {};
  final Map<String, bool> _bools = {};
  final Map<String, int> _ints = {};

  bool failOnWrite = false;
  bool failOnRead = false;

  @override
  Future<double?> getDouble(String key) async {
    if (failOnRead) throw Exception('Simulated read failure');
    return _doubles[key];
  }

  @override
  Future<bool?> getBool(String key) async {
    if (failOnRead) throw Exception('Simulated read failure');
    return _bools[key];
  }

  @override
  Future<int?> getInt(String key) async {
    if (failOnRead) throw Exception('Simulated read failure');
    return _ints[key];
  }

  @override
  Future<Either<SettingsFailure, void>> setDouble(
      String key, double value) async {
    if (failOnWrite) {
      return left(const SettingsSaveFailure('Failed to write double'));
    }
    _doubles[key] = value;
    return right(null);
  }

  @override
  Future<Either<SettingsFailure, void>> setBool(String key, bool value) async {
    if (failOnWrite) {
      return left(const SettingsSaveFailure('Failed to write bool'));
    }
    _bools[key] = value;
    return right(null);
  }

  @override
  Future<Either<SettingsFailure, void>> setInt(String key, int value) async {
    if (failOnWrite) {
      return left(const SettingsSaveFailure('Failed to write int'));
    }
    _ints[key] = value;
    return right(null);
  }
}

// ---------------------------------------------------------------------------
// Production Key-Value Store (shared_preferences wrapper)
// ---------------------------------------------------------------------------

/// Production implementation backed by `shared_preferences`.
///
/// BACKING PLUGIN REQUIREMENT:
/// N1 adds to `pubspec.yaml`:
/// ```yaml
/// shared_preferences: ^2.3.3
/// ```
final class SharedPreferencesStore implements SettingsKeyValueStore {
  SharedPreferencesStore({dynamic prefs}) : _prefs = prefs;

  dynamic _prefs;

  Future<void> initialize({dynamic prefsInstance}) async {
    _prefs = prefsInstance;
  }

  @override
  Future<double?> getDouble(String key) async {
    if (_prefs == null) return null;
    return (_prefs.getDouble(key) as num?)?.toDouble();
  }

  @override
  Future<bool?> getBool(String key) async {
    if (_prefs == null) return null;
    return _prefs.getBool(key) as bool?;
  }

  @override
  Future<int?> getInt(String key) async {
    if (_prefs == null) return null;
    return _prefs.getInt(key) as int?;
  }

  @override
  Future<Either<SettingsFailure, void>> setDouble(
      String key, double value) async {
    if (_prefs == null) {
      return left(
        const SettingsSaveFailure('SharedPreferences is not initialized'),
      );
    }
    try {
      final success = await _prefs.setDouble(key, value) as bool;
      if (!success) {
        return left(const SettingsSaveFailure('setDouble returned false'));
      }
      return right(null);
    } on Exception catch (e) {
      return left(SettingsSaveFailure(e.toString()));
    }
  }

  @override
  Future<Either<SettingsFailure, void>> setBool(String key, bool value) async {
    if (_prefs == null) {
      return left(
        const SettingsSaveFailure('SharedPreferences is not initialized'),
      );
    }
    try {
      final success = await _prefs.setBool(key, value) as bool;
      if (!success) {
        return left(const SettingsSaveFailure('setBool returned false'));
      }
      return right(null);
    } on Exception catch (e) {
      return left(SettingsSaveFailure(e.toString()));
    }
  }

  @override
  Future<Either<SettingsFailure, void>> setInt(String key, int value) async {
    if (_prefs == null) {
      return left(
        const SettingsSaveFailure('SharedPreferences is not initialized'),
      );
    }
    try {
      final success = await _prefs.setInt(key, value) as bool;
      if (!success) {
        return left(const SettingsSaveFailure('setInt returned false'));
      }
      return right(null);
    } on Exception catch (e) {
      return left(SettingsSaveFailure(e.toString()));
    }
  }
}
