import 'package:flutter_agentic_starter/features/settings/data/local_assistance_preferences_repository.dart';
import 'package:flutter_agentic_starter/shared/assistance_contracts/assistance_preferences_contract.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('returns assistance defaults when no record is stored', () async {
    final repository = LocalAssistancePreferencesRepository(
      preferences: _PreferencesStore(),
    );

    final result = await repository.loadPreferences();
    final preferences = result.getRight().toNullable()!;
    expect(preferences.speechRate, 1.0);
    expect(preferences.spokenFeedbackEnabled, isTrue);
    expect(
      preferences.duplicateSuppressionInterval,
      const Duration(seconds: 2),
    );
  });

  test(
    'restores one complete settings record through a new repository',
    () async {
      final store = _PreferencesStore();
      final repository = LocalAssistancePreferencesRepository(
        preferences: store,
      );
      const saved = AssistancePreferences(
        speechRate: 1.5,
        spokenFeedbackEnabled: false,
        duplicateSuppressionInterval: Duration(seconds: 4),
        confidenceThreshold: 0.6,
        leftZoneBoundary: 0.25,
        rightZoneBoundary: 0.75,
      );

      expect((await repository.savePreferences(saved)).isRight(), isTrue);
      expect(store.records, hasLength(1));
      final reopened = LocalAssistancePreferencesRepository(preferences: store);
      final result = await reopened.loadPreferences();
      final restored = result.getRight().toNullable()!;
      expect(restored.speechRate, saved.speechRate);
      expect(restored.spokenFeedbackEnabled, saved.spokenFeedbackEnabled);
      expect(
        restored.duplicateSuppressionInterval,
        saved.duplicateSuppressionInterval,
      );
      expect(restored.confidenceThreshold, saved.confidenceThreshold);
      expect(restored.leftZoneBoundary, saved.leftZoneBoundary);
      expect(restored.rightZoneBoundary, saved.rightZoneBoundary);
    },
  );

  test('rejects invalid values before touching the stored record', () async {
    final store = _PreferencesStore();
    final repository = LocalAssistancePreferencesRepository(preferences: store);
    expect(
      (await repository.savePreferences(
        const AssistancePreferences(),
      )).isRight(),
      isTrue,
    );
    final original = store.records.values.single;
    const invalid = [
      AssistancePreferences(speechRate: 2.1),
      AssistancePreferences(duplicateSuppressionInterval: Duration.zero),
      AssistancePreferences(confidenceThreshold: double.nan),
      AssistancePreferences(leftZoneBoundary: 0.8, rightZoneBoundary: 0.3),
    ];
    for (final preferences in invalid) {
      final result = await repository.savePreferences(preferences);
      expect(result.getLeft().toNullable(), isA<PreferencesSaveFailure>());
    }
    expect(store.records.values.single, original);
  });

  test('reports malformed stored settings as a typed failure', () async {
    final store = _PreferencesStore();
    final repository = LocalAssistancePreferencesRepository(preferences: store);
    await repository.savePreferences(const AssistancePreferences());
    final key = store.records.keys.single;

    for (final invalid in ['{', '[]', '{"speechRate":"fast"}']) {
      store.records[key] = invalid;
      final result = await repository.loadPreferences();
      expect(result.getLeft().toNullable(), isA<PreferencesLoadFailure>());
    }
  });

  test('reports read and write errors as typed failures', () async {
    final store = _PreferencesStore(fails: true);
    final repository = LocalAssistancePreferencesRepository(preferences: store);

    final read = await repository.loadPreferences();
    final write = await repository.savePreferences(
      const AssistancePreferences(),
    );
    expect(read.getLeft().toNullable(), isA<PreferencesLoadFailure>());
    expect(write.getLeft().toNullable(), isA<PreferencesSaveFailure>());
  });

  test('reads old settings and gives a new save precedence', () async {
    final previous = _PreferencesStore();
    final original = LocalAssistancePreferencesRepository(
      preferences: previous,
    );
    await original.savePreferences(
      const AssistancePreferences(speechRate: 1.4),
    );
    final current = _PreferencesStore();
    final repository = LocalAssistancePreferencesRepository(
      preferences: current,
      legacyPreferences: previous,
    );

    final migrated = await repository.loadPreferences();
    expect(migrated.getRight().toNullable()?.speechRate, 1.4);
    expect(
      (await repository.savePreferences(
        const AssistancePreferences(speechRate: 1.6),
      )).isRight(),
      isTrue,
    );
    final reopened = LocalAssistancePreferencesRepository(
      preferences: current,
      legacyPreferences: previous,
    );
    final saved = await reopened.loadPreferences();
    expect(saved.getRight().toNullable()?.speechRate, 1.6);
    expect(
      (await original.loadPreferences()).getRight().toNullable()?.speechRate,
      1.4,
    );
  });

  test('an unreadable legacy store does not prevent saving settings', () async {
    final repository = LocalAssistancePreferencesRepository(
      preferences: _PreferencesStore(),
      legacyPreferences: _PreferencesStore(fails: true),
    );
    final initial = await repository.loadPreferences();
    expect(initial.getRight().toNullable()?.speechRate, 1);
    expect(
      (await repository.savePreferences(
        const AssistancePreferences(speechRate: 1.5),
      )).isRight(),
      isTrue,
    );
    final saved = await repository.loadPreferences();
    expect(saved.getRight().toNullable()?.speechRate, 1.5);
  });
}

class _PreferencesStore implements SharedPreferencesAsync {
  _PreferencesStore({this.fails = false});

  final records = <String, String>{};
  final bool fails;

  @override
  Future<String?> getString(String key) async {
    if (fails) throw Exception('read unavailable');
    return records[key];
  }

  @override
  Future<void> setString(String key, String value) async {
    if (fails) throw Exception('write unavailable');
    records[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
