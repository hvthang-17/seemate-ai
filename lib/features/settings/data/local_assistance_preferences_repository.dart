import 'dart:convert';

import 'package:fpdart/fpdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/assistance_contracts/assistance_preferences_contract.dart';

/// Persists only assistance preferences as a single versioned record.
final class LocalAssistancePreferencesRepository
    implements AssistancePreferencesContract {
  LocalAssistancePreferencesRepository({
    SharedPreferencesAsync? preferences,
    SharedPreferencesAsync? legacyPreferences,
  }) : _preferences = preferences,
       _legacyPreferences = legacyPreferences;

  static const _recordKey = 'seemate.assistance_preferences.v1';
  static const _minimumSuppression = Duration(seconds: 1);
  static const _maximumSuppression = Duration(seconds: 5);
  static const _storageTimeout = Duration(seconds: 3);

  SharedPreferencesAsync? _preferences;
  final SharedPreferencesAsync? _legacyPreferences;
  Future<AssistancePreferences?>? _legacyRead;

  SharedPreferencesAsync get _store =>
      _preferences ??= SharedPreferencesAsync();

  @override
  Future<Either<PreferencesFailure, AssistancePreferences>>
  loadPreferences() async {
    try {
      final record = await _store
          .getString(_recordKey)
          .timeout(_storageTimeout);
      if (record == null) {
        final legacy = await (_legacyRead ??= _readLegacy());
        return Right(legacy ?? const AssistancePreferences());
      }
      return Right(_decode(record));
    } on FormatException {
      return const Left(PreferencesLoadFailure('Invalid preferences record'));
    } on TypeError {
      return const Left(PreferencesLoadFailure('Invalid preferences record'));
    } on StateError {
      return const Left(PreferencesLoadFailure('Preferences unavailable'));
    } on Exception {
      return const Left(PreferencesLoadFailure('Could not load preferences'));
    }
  }

  Future<AssistancePreferences?> _readLegacy() async {
    final store = _legacyPreferences;
    if (store == null) return null;
    try {
      final record = await store.getString(_recordKey).timeout(_storageTimeout);
      return record == null ? null : _decode(record);
    } on TypeError {
      return null;
    } on Exception {
      return null;
    } on StateError {
      return null;
    }
  }

  AssistancePreferences _decode(String record) {
    final data = jsonDecode(record);
    if (data is! Map<String, Object?>) {
      throw const FormatException('Invalid preferences record');
    }
    final stored = AssistancePreferences(
      speechRate: (data['speechRate'] as num).toDouble(),
      spokenFeedbackEnabled: data['spokenFeedbackEnabled'] as bool,
      duplicateSuppressionInterval: Duration(
        milliseconds: data['suppressionMilliseconds'] as int,
      ),
      confidenceThreshold: (data['confidenceThreshold'] as num).toDouble(),
      leftZoneBoundary: (data['leftZoneBoundary'] as num).toDouble(),
      rightZoneBoundary: (data['rightZoneBoundary'] as num).toDouble(),
    );
    if (!_isValid(stored)) {
      throw const FormatException('Invalid preferences record');
    }
    return stored;
  }

  @override
  Future<Either<PreferencesFailure, void>> savePreferences(
    AssistancePreferences preferences,
  ) async {
    if (!_isValid(preferences)) {
      return const Left(PreferencesSaveFailure('Invalid preferences values'));
    }
    try {
      await _store
          .setString(
            _recordKey,
            jsonEncode({
              'speechRate': preferences.speechRate,
              'spokenFeedbackEnabled': preferences.spokenFeedbackEnabled,
              'suppressionMilliseconds':
                  preferences.duplicateSuppressionInterval.inMilliseconds,
              'confidenceThreshold': preferences.confidenceThreshold,
              'leftZoneBoundary': preferences.leftZoneBoundary,
              'rightZoneBoundary': preferences.rightZoneBoundary,
            }),
          )
          .timeout(_storageTimeout);
      return const Right(null);
    } on StateError {
      return const Left(PreferencesSaveFailure('Preferences unavailable'));
    } on Exception {
      return const Left(PreferencesSaveFailure('Could not save preferences'));
    }
  }

  bool _isValid(AssistancePreferences preferences) =>
      preferences.speechRate >= 0.5 &&
      preferences.speechRate <= 2 &&
      preferences.duplicateSuppressionInterval >= _minimumSuppression &&
      preferences.duplicateSuppressionInterval <= _maximumSuppression &&
      preferences.confidenceThreshold >= 0 &&
      preferences.confidenceThreshold <= 1 &&
      preferences.leftZoneBoundary > 0 &&
      preferences.leftZoneBoundary < preferences.rightZoneBoundary &&
      preferences.rightZoneBoundary < 1;
}
