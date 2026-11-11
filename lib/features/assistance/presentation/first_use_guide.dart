import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/assistance_contracts/speech_coordinator_contract.dart';
import '../../../shared/i18n/generated/app_localizations.dart';
import '../../../shared/i18n/i18n.dart';
import 'assistance_providers.dart';

final firstUseGuideStoreProvider = Provider<SharedPreferencesAsync?>(
  (_) => null,
);
final legacyGuideStoreProvider = Provider<SharedPreferencesAsync?>((_) => null);

class FirstUseGuide extends ConsumerStatefulWidget {
  const FirstUseGuide({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<FirstUseGuide> createState() => _FirstUseGuideState();
}

class _FirstUseGuideState extends ConsumerState<FirstUseGuide> {
  static const _seenKey = 'seemate.usage_guide_seen.v1';
  static const _storageTimeout = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_openOnce());
    });
  }

  Future<void> _openOnce() async {
    final store = ref.read(firstUseGuideStoreProvider);
    if (store == null) return;
    final legacy = ref.read(legacyGuideStoreProvider);
    try {
      final seen = await store.getBool(_seenKey).timeout(_storageTimeout);
      if (seen == null && await _readLegacySeen(legacy)) {
        await store.setBool(_seenKey, true).timeout(_storageTimeout);
        return;
      }
      if (!mounted ||
          seen == true ||
          ModalRoute.isCurrentOf(context) == false) {
        return;
      }
      await showUsageGuide(
        context,
        ref.read(speechCoordinatorProvider),
        autoPlay: !MediaQuery.accessibleNavigationOf(context),
      );
      await store.setBool(_seenKey, true).timeout(_storageTimeout);
    } on Exception {
      // The home screen and manual guide remain available without storage.
    }
  }

  Future<bool> _readLegacySeen(SharedPreferencesAsync? legacy) async {
    if (legacy == null) return false;
    try {
      return await legacy.getBool(_seenKey).timeout(_storageTimeout) == true;
    } on TypeError {
      return false;
    } on Exception {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

Future<void> showUsageGuide(
  BuildContext context,
  SpeechCoordinatorContract speech, {
  bool autoPlay = false,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _UsageGuideDialog(speech: speech, autoPlay: autoPlay),
);

class _UsageGuideDialog extends StatefulWidget {
  const _UsageGuideDialog({required this.speech, required this.autoPlay});

  final SpeechCoordinatorContract speech;
  final bool autoPlay;

  @override
  State<_UsageGuideDialog> createState() => _UsageGuideDialogState();
}

class _UsageGuideDialogState extends State<_UsageGuideDialog> {
  late final AppLifecycleListener _lifecycle;
  int _playback = 0;
  bool _requestedSpeech = false;
  bool _unavailable = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onPause: _stop, onHide: _stop);
    if (widget.autoPlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ModalRoute.isCurrentOf(context) == true) {
          unawaited(_play());
        }
      });
    }
  }

  Future<void> _play() async {
    _stop();
    final playback = _playback;
    setState(() => _unavailable = false);
    final voice = await widget.speech.checkVoiceReadiness();
    if (!mounted ||
        playback != _playback ||
        ModalRoute.isCurrentOf(context) != true) {
      return;
    }
    if (!voice.isAvailable || !voice.isOffline) {
      setState(() => _unavailable = true);
      return;
    }
    _requestedSpeech = true;
    final spoken = await widget.speech.speak(
      lookupAppLocalizations(const Locale('vi')).usageGuideText,
      priority: SpeechPriority.high,
    );
    if (mounted && playback == _playback && !spoken) {
      setState(() => _unavailable = true);
    }
  }

  void _stop() {
    _playback++;
    if (_requestedSpeech) {
      _requestedSpeech = false;
      unawaited(widget.speech.stop());
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope<void>(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _stop();
      },
      child: AlertDialog(
        scrollable: true,
        title: Text(l10n.usageGuideTitle),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.usageGuideText),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: _play,
              icon: const Icon(Icons.volume_up_outlined),
              label: Text(l10n.usageGuideListen),
            ),
            if (_unavailable)
              Semantics(
                liveRegion: true,
                child: Text(l10n.offlineVoiceUnavailable),
              ),
          ],
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: _stop,
            child: Text(l10n.modeStop),
          ),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () {
              _stop();
              Navigator.of(context).pop();
            },
            child: Text(l10n.usageGuideClose),
          ),
        ],
      ),
    );
  }
}
