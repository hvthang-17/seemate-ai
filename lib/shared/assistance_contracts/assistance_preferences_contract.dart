import 'package:fpdart/fpdart.dart';

/// User preferences for assistance behavior, stored locally without requiring an account.
class AssistancePreferences {
  const AssistancePreferences({
    this.speechRate = 1.0,
    this.spokenFeedbackEnabled = true,
    this.duplicateSuppressionInterval = const Duration(seconds: 2),
    this.confidenceThreshold = 0.50,
    this.leftZoneBoundary = 0.33,
    this.rightZoneBoundary = 0.66,
  });

  final double speechRate;
  final bool spokenFeedbackEnabled;
  final Duration duplicateSuppressionInterval;
  final double confidenceThreshold;
  final double leftZoneBoundary;
  final double rightZoneBoundary;

  AssistancePreferences copyWith({
    double? speechRate,
    bool? spokenFeedbackEnabled,
    Duration? duplicateSuppressionInterval,
    double? confidenceThreshold,
    double? leftZoneBoundary,
    double? rightZoneBoundary,
  }) {
    return AssistancePreferences(
      speechRate: speechRate ?? this.speechRate,
      spokenFeedbackEnabled: spokenFeedbackEnabled ?? this.spokenFeedbackEnabled,
      duplicateSuppressionInterval:
          duplicateSuppressionInterval ?? this.duplicateSuppressionInterval,
      confidenceThreshold: confidenceThreshold ?? this.confidenceThreshold,
      leftZoneBoundary: leftZoneBoundary ?? this.leftZoneBoundary,
      rightZoneBoundary: rightZoneBoundary ?? this.rightZoneBoundary,
    );
  }
}

/// Failures that can occur when loading or saving local preferences.
sealed class PreferencesFailure {
  const PreferencesFailure();
}

final class PreferencesLoadFailure extends PreferencesFailure {
  const PreferencesLoadFailure(this.message);
  final String message;
}

final class PreferencesSaveFailure extends PreferencesFailure {
  const PreferencesSaveFailure(this.message);
  final String message;
}

/// Contract for persisting user assistance settings locally.
abstract interface class AssistancePreferencesContract {
  /// Loads persisted preferences or returns default settings if none found.
  Future<Either<PreferencesFailure, AssistancePreferences>> loadPreferences();

  /// Persists [preferences] to local storage (e.g. SharedPreferences).
  Future<Either<PreferencesFailure, void>> savePreferences(
    AssistancePreferences preferences,
  );
}
