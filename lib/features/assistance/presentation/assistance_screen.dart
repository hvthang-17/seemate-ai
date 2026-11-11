import 'package:flutter/material.dart' hide ObjectKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/assistance_contracts/assistance_contracts.dart';
import '../../../shared/i18n/i18n.dart';
import '../../object_detection/domain/v1_detection_catalog.dart';
import '../../settings/presentation/settings_screen.dart';
import '../domain/models/assistance_state.dart';
import 'assistance_camera_panel.dart';
import 'assistance_mode_menu.dart';
import 'assistance_camera_providers.dart';
import 'assistance_providers.dart';
import 'voice_command_button.dart';

class AssistanceScreen extends ConsumerWidget {
  const AssistanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(assistanceNotifierProvider);
    final notifier = ref.read(assistanceNotifierProvider.notifier);
    final readingText = state.mode == AssistanceMode.textReading;
    final showLiveDetection =
        ref.watch(cameraDetectionEnabledProvider) &&
        (state.mode == AssistanceMode.objectRecognition ||
            state.mode == AssistanceMode.targetSearch);

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final idle = state.mode == AssistanceMode.idle;
    final hasVoiceCommands = ref.watch(
      voiceCommandProvider.select((service) => service != null),
    );
    final header = state.statusMessage == null
        ? null
        : _ModeStatus(message: state.statusMessage!);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        title: Text(
          l10n.homeTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: idle
            ? null
            : BackButton(
                onPressed: () {
                  ref.read(cameraSessionProvider)?.cancelCapture();
                  notifier.selectMode(AssistanceMode.idle);
                },
              ),
        actions: [
          if (hasVoiceCommands) ...[
            VoiceCommandButton(
              showLabel:
                  idle &&
                  MediaQuery.sizeOf(context).width >=
                      (Localizations.localeOf(context).languageCode == 'vi'
                          ? 400
                          : 480) &&
                  MediaQuery.textScalerOf(context).scale(14) <= 16,
            ),
            const SizedBox(width: 16),
          ],
          IconButton.outlined(
            constraints: const BoxConstraints.tightFor(width: 64, height: 64),
            iconSize: 32,
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.settingsTitle,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: AssistanceCameraPanel(
              active: !idle,
              header: header,
              detectionResults: showLiveDetection
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (state.voiceUnavailable)
                          Semantics(
                            liveRegion: true,
                            child: Text(l10n.offlineVoiceUnavailable),
                          ),
                        _ResultsView(state: state, embedded: true),
                      ],
                    )
                  : null,
              analyzeFrames:
                  showLiveDetection &&
                  state.detectionFailure is! ModelNotLoadedFailure &&
                  state.detectionFailure is! DetectorInitializationFailure &&
                  state.detectionFailure is! UnsupportedDetectionTargetFailure,
              onCaptureText: readingText ? notifier.captureAndReadText : null,
              textResults: readingText ? _CameraTextResult(state) : null,
              isReadingText: readingText && state.isProcessing,
              onSuspend: notifier.suspendFeedback,
              child: idle
                  ? AssistanceModeMenu(
                      onRecognize: () =>
                          notifier.selectMode(AssistanceMode.objectRecognition),
                      onFind: () => _showTargetPicker(context, ref),
                      onRead: () =>
                          notifier.selectMode(AssistanceMode.textReading),
                    )
                  : _ResultsView(state: state, header: header),
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
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(48, 56),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    backgroundColor: colors.error,
                    foregroundColor: colors.onError,
                    elevation: 0,
                    textStyle: theme.textTheme.titleMedium,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.stop_circle_outlined, size: 26),
                  label: Text(l10n.modeStop, textAlign: TextAlign.center),
                  onPressed: () async {
                    ref.read(cameraSessionProvider)?.cancelCapture();
                    await notifier.stopReading();
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showTargetPicker(BuildContext context, WidgetRef ref) {
    final targets = v1DetectionLabels.values.toList(growable: false);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  context.l10n.selectTargetTitle,
                  style: const TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(height: 1.0),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: targets.length,
                  itemBuilder: (ctx, idx) {
                    final key = targets[idx];
                    return ListTile(
                      minTileHeight: 56,
                      minVerticalPadding: 12,
                      title: Text(
                        Localizations.localeOf(context).languageCode == 'vi'
                            ? key.vietnameseLabel
                            : key.englishLabel,
                        style: Theme.of(ctx).textTheme.titleMedium,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        ref
                            .read(assistanceNotifierProvider.notifier)
                            .setTargetObject(key);
                        Navigator.of(sheetContext).pop();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ModeStatus extends StatelessWidget {
  const _ModeStatus({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      liveRegion: true,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          message,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _CameraTextResult extends StatelessWidget {
  const _CameraTextResult(this.state);

  final AssistanceState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final message = state.ocrCaptureFailed
        ? l10n.ocrCaptureFailed
        : state.errorMessage != null
        ? l10n.ocrReadFailed
        : state.ocrResult?.isEmpty == true
        ? l10n.ocrEmptyFeedback
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message != null) Semantics(liveRegion: true, child: Text(message)),
        if (state.ocrResult case final result? when result.isNotEmpty)
          SelectableText(result.fullText),
        if (state.voiceUnavailable)
          Semantics(
            liveRegion: true,
            child: Text(l10n.offlineVoiceUnavailable),
          ),
      ],
    );
  }
}

class _ResultsView extends StatelessWidget {
  const _ResultsView({required this.state, this.embedded = false, this.header});

  final AssistanceState state;
  final bool embedded;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    if (state.detectedObjects.isNotEmpty) {
      final headerCount = header == null ? 0 : 1;
      return ListView.builder(
        padding: embedded
            ? const EdgeInsets.only(top: 12)
            : const EdgeInsets.all(16.0),
        shrinkWrap: embedded,
        physics: embedded ? const NeverScrollableScrollPhysics() : null,
        itemCount: state.detectedObjects.length + headerCount,
        itemBuilder: (ctx, idx) {
          if (idx < headerCount) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: header,
            );
          }
          final obj = state.detectedObjects[idx - headerCount];
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        obj.key.vietnameseLabel,
                        style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          Text('Vị trí: ${obj.zone.vietnameseLabel}'),
                          Text('${(obj.confidence * 100).toStringAsFixed(0)}%'),
                        ],
                      ),
                    ],
                  ),
                ),
                if (embedded)
                  ExpansionTile(
                    title: Text(context.l10n.detectionDetails),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      Text(
                        context.l10n.detectionBounds(
                          obj.label,
                          [
                            obj.boundingBox.left,
                            obj.boundingBox.top,
                            obj.boundingBox.right,
                            obj.boundingBox.bottom,
                          ].map((value) => value.toStringAsFixed(3)).join(', '),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      );
    }

    if (embedded) {
      final l10n = context.l10n;
      final message = switch (state.detectionFailure) {
        ModelNotLoadedFailure() => l10n.detectionModelUnavailable,
        DetectorInitializationFailure() => l10n.detectionInitializationFailed,
        UnsupportedDetectionTargetFailure() => l10n.unsupportedObject,
        DetectionFailure() => l10n.detectionFailed,
        null =>
          state.hasDetectionResult
              ? l10n.noDetectionFeedback
              : l10n.detectionWaiting,
      };
      return Semantics(
        liveRegion: true,
        child: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(message),
        ),
      );
    }

    if (state.ocrResult != null && state.ocrResult!.isNotEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          ?header,
          const Text(
            'Nội dung văn bản nhận diện được:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
          ),
          const SizedBox(height: 8.0),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SelectableText(
                state.ocrResult!.fullText,
                style: const TextStyle(fontSize: 18.0, height: 1.5),
              ),
            ),
          ),
        ],
      );
    }

    return ListView(padding: const EdgeInsets.all(16), children: [?header]);
  }
}
