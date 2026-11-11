import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/assistance_contracts/assistance_contracts.dart';
import '../../../shared/i18n/i18n.dart';
import '../../assistance/presentation/assistance_providers.dart';
import '../../assistance/presentation/first_use_guide.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  AssistancePreferences _prefs = const AssistancePreferences();
  bool _isLoading = true;
  bool _loadFailed = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final repo = ref.read(preferencesRepoProvider);
    final result = await repo.loadPreferences();
    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          _isLoading = false;
          _loadFailed = true;
        });
      },
      (loaded) {
        setState(() {
          _prefs = loaded;
          _isLoading = false;
          _loadFailed = false;
        });
      },
    );
  }

  Future<void> _retryPreferences() async {
    if (_isLoading || _isSaving) return;
    setState(() => _isLoading = true);
    await _loadPreferences();
  }

  Future<void> _savePreferences() async {
    if (_isLoading || _isSaving) return;
    setState(() => _isSaving = true);
    final repo = ref.read(preferencesRepoProvider);
    final preferences = _prefs;
    try {
      final result = await repo.savePreferences(preferences);
      if (!mounted) return;

      await result.fold<Future<void>>(
        (failure) async {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(context.l10n.saveError)));
        },
        (_) async {
          setState(() => _loadFailed = false);
          await applySpeechPreferences(
            ref.read(speechCoordinatorProvider),
            preferences,
          );
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(context.l10n.savedSuccess)));
        },
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.settingsTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final strings = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(strings.settingsTitle)),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: () => showUsageGuide(
                    context,
                    ref.read(speechCoordinatorProvider),
                  ),
                  icon: const Icon(Icons.help_outline),
                  label: Text(strings.usageGuideTitle),
                ),
                const SizedBox(height: 12),
                if (_loadFailed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            strings.settingsLoadError,
                            style: TextStyle(color: colors.error),
                          ),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          onPressed: _isSaving ? null : _retryPreferences,
                          child: Text(strings.retry),
                        ),
                      ],
                    ),
                  ),
                _PreferenceSlider(
                  title: strings.speechRateLabel,
                  value: _prefs.speechRate,
                  min: 0.5,
                  max: 2,
                  divisions: 15,
                  formatValue: (value) => '${value.toStringAsFixed(1)}x',
                  onChanged: (value) {
                    setState(() {
                      _prefs = _prefs.copyWith(speechRate: value);
                    });
                  },
                ),
                const SizedBox(height: 12),
                _PreferenceSlider(
                  title: strings.duplicateSuppressionLabel,
                  value: _prefs.duplicateSuppressionInterval.inSeconds
                      .toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  formatValue: (value) => '${value.round()}s',
                  onChanged: (value) {
                    setState(() {
                      _prefs = _prefs.copyWith(
                        duplicateSuppressionInterval: Duration(
                          seconds: value.round(),
                        ),
                      );
                    });
                  },
                ),
                const SizedBox(height: 12),
                Card.outlined(
                  margin: EdgeInsets.zero,
                  color: colors.surfaceContainer,
                  child: SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    title: Text(
                      'Phản hồi bằng giọng nói',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: const Text(
                      'Tự động đọc kết quả nhận diện ra loa',
                    ),
                    value: _prefs.spokenFeedbackEnabled,
                    onChanged: (value) {
                      setState(() {
                        _prefs = _prefs.copyWith(spokenFeedbackEnabled: value);
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Material(
        color: colors.surfaceContainer,
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 608),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 56),
                    textStyle: theme.textTheme.titleMedium,
                  ),
                  icon: const Icon(Icons.check_rounded),
                  label: Text(strings.save, textAlign: TextAlign.center),
                  onPressed: _isSaving ? null : _savePreferences,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreferenceSlider extends StatelessWidget {
  const _PreferenceSlider({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.formatValue,
    required this.onChanged,
  });

  final String title;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double) formatValue;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueLabel = formatValue(value);
    return Card.outlined(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$title: $valueLabel',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Semantics(
              label: title,
              child: SizedBox(
                height: 48,
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  divisions: divisions,
                  label: valueLabel,
                  semanticFormatterCallback: formatValue,
                  onChanged: onChanged,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
