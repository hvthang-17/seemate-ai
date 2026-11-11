import 'dart:async';

import 'package:flutter/material.dart' hide ObjectKey;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/camera/camera_session_controller.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../shared/assistance_contracts/assistance_contracts.dart';
import '../../../shared/i18n/i18n.dart';
import '../../object_detection/domain/v1_detection_catalog.dart';
import '../domain/models/assistance_state.dart';
import 'assistance_camera_providers.dart';
import 'assistance_providers.dart';

class VoiceCommandButton extends ConsumerStatefulWidget {
  const VoiceCommandButton({super.key, this.showLabel = false});

  final bool showLabel;

  @override
  ConsumerState<VoiceCommandButton> createState() => _VoiceCommandButtonState();
}

class _VoiceCommandButtonState extends ConsumerState<VoiceCommandButton> {
  late final AppLifecycleListener _lifecycle;
  VoiceCommandContract? _activeService;
  Object? _request;
  bool _listening = false;
  bool _recordingRequested = false;
  bool _stopping = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        if (state == AppLifecycleState.hidden ||
            state == AppLifecycleState.paused ||
            (state == AppLifecycleState.inactive && _recordingRequested)) {
          _cancel();
        }
      },
    );
  }

  void _cancel() {
    final service = _activeService;
    if (service == null) return;
    _request = null;
    _activeService = null;
    _recordingRequested = false;
    setState(() {
      _listening = false;
      _stopping = true;
    });
    unawaited(_stop(service));
  }

  Future<void> _stop(VoiceCommandContract service) async {
    try {
      await service.stopListening();
    } on Exception {
      // The session token has already been invalidated.
    } finally {
      if (mounted) setState(() => _stopping = false);
    }
  }

  @override
  void dispose() {
    _request = null;
    final service = _activeService;
    if (service != null) unawaited(service.stopListening());
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(voiceCommandProvider);
    if (service == null) return const SizedBox.shrink();
    if (ModalRoute.isCurrentOf(context) == false && _request != null) {
      scheduleMicrotask(() {
        if (mounted && ModalRoute.isCurrentOf(context) == false) _cancel();
      });
    }
    ref.listen(
      assistanceNotifierProvider.select(
        (state) => (state.mode, state.targetKey),
      ),
      (_, _) => _cancel(),
    );
    final l10n = context.l10n;
    final label = _listening
        ? l10n.voiceCancel
        : _request != null
        ? l10n.voicePreparing
        : l10n.voiceListen;
    final icon = Icon(_request != null ? Icons.mic_off : Icons.mic, size: 32);
    final VoidCallback? onPressed = _stopping
        ? null
        : () {
            if (_request == null) {
              unawaited(_listen(service));
            } else {
              _cancel();
            }
          };
    if (widget.showLabel && _request == null) {
      return Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: FilledButton.tonalIcon(
          style: FilledButton.styleFrom(
            minimumSize: const Size(64, 64),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          icon: icon,
          label: Text(label),
          onPressed: onPressed,
        ),
      );
    }
    return IconButton.filledTonal(
      tooltip: label,
      constraints: const BoxConstraints.tightFor(width: 64, height: 64),
      icon: icon,
      onPressed: onPressed,
    );
  }

  bool _isCurrent(Object request) =>
      mounted &&
      identical(_request, request) &&
      (ModalRoute.isCurrentOf(context) ?? true);

  Future<void> _listen(VoiceCommandContract service) async {
    final request = Object();
    setState(() => _request = request);
    _activeService = service;
    final notifier = ref.read(assistanceNotifierProvider.notifier);
    var pausedSpeech = false;
    try {
      final available = await service.isOfflineAvailable();
      if (!mounted || !_isCurrent(request)) return;
      if (!available) {
        _show(context.l10n.voiceOfflineUnavailable);
        return;
      }

      final permissions = ref.read(cameraPermissionProvider);
      var status = await permissions.check(AppPermission.microphone);
      if (!_isCurrent(request)) return;
      if (status == AppPermissionStatus.denied) {
        status = await permissions.request(AppPermission.microphone);
      }
      if (!_isCurrent(request)) return;
      if (!mounted) return;
      if (status != AppPermissionStatus.granted) {
        _show(context.l10n.voiceMicrophoneDenied);
        return;
      }

      pausedSpeech = true;
      await notifier.beginVoiceInput(request);
      if (!_isCurrent(request) || !notifier.isVoiceInputCurrent(request)) {
        return;
      }
      _recordingRequested = true;
      final result = await service.listenForCommand(
        onListening: () {
          if (!_isCurrent(request)) return;
          setState(() => _listening = true);
          unawaited(HapticFeedback.selectionClick());
        },
      );
      if (!_isCurrent(request)) return;
      _activeService = null;
      _request = null;
      _recordingRequested = false;
      setState(() => _listening = false);
      notifier.endVoiceInput(request);
      pausedSpeech = false;
      await _dispatch(notifier, result);
    } on Exception {
      if (mounted && _isCurrent(request)) {
        _show(context.l10n.voiceNotUnderstood);
      }
    } finally {
      if (pausedSpeech) notifier.endVoiceInput(request);
      if (identical(_request, request)) {
        _request = null;
        _activeService = null;
        _recordingRequested = false;
        if (mounted) setState(() => _listening = false);
      }
    }
  }

  Future<void> _dispatch(
    AssistanceNotifier notifier,
    CommandResult result,
  ) async {
    final l10n = context.l10n;
    if (result.failure case final failure?) {
      final message = switch (failure) {
        VoiceCommandFailure.unavailable => l10n.voiceOfflineUnavailable,
        VoiceCommandFailure.permissionDenied => l10n.voiceMicrophoneDenied,
        VoiceCommandFailure.cancelled => null,
        VoiceCommandFailure.timeout ||
        VoiceCommandFailure.audioUnavailable ||
        VoiceCommandFailure.recognition => l10n.voiceNotUnderstood,
      };
      if (message != null) _show(message);
      return;
    }
    if (!result.isUnderstood) {
      _show(l10n.voiceNotUnderstood);
      return;
    }
    switch (result.action) {
      case AssistanceAction.recognizeObjects:
        notifier.selectMode(AssistanceMode.objectRecognition);
      case AssistanceAction.findObject:
        final target = result.targetKey;
        if (target == null || !v1DetectionLabels.containsValue(target)) {
          _show(l10n.unsupportedObject);
        } else {
          notifier.setTargetObject(target);
        }
      case AssistanceAction.readText:
        notifier.selectMode(AssistanceMode.textReading);
      case AssistanceAction.stopReading:
        ref.read(cameraSessionProvider)?.cancelCapture();
        await notifier.stopReading();
      case AssistanceAction.returnHome:
        ref.read(cameraSessionProvider)?.cancelCapture();
        notifier.selectMode(AssistanceMode.idle);
      case AssistanceAction.captureText:
        if (ref.read(assistanceNotifierProvider).mode !=
            AssistanceMode.textReading) {
          _show(l10n.voiceCaptureRequiresTextMode);
          return;
        }
        final CameraSessionController? session = ref.read(
          cameraSessionProvider,
        );
        if (session == null ||
            session.status != CameraSessionStatus.previewing) {
          _show(l10n.ocrCaptureFailed);
          return;
        }
        await notifier.captureAndReadText(session.capturePreviewFrame);
      case null:
        _show(l10n.voiceNotUnderstood);
    }
  }

  void _show(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }
}
