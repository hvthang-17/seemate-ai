import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/camera/camera_session_controller.dart';
import '../../../core/camera/flutter_camera_driver.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../shared/assistance_contracts/frame_session_contract.dart';
import '../../../shared/i18n/i18n.dart';
import 'assistance_camera_providers.dart';

class AssistanceCameraPanel extends ConsumerWidget {
  const AssistanceCameraPanel({
    super.key,
    required this.active,
    required this.child,
    this.header,
    this.detectionResults,
    this.analyzeFrames = false,
    this.onCaptureText,
    this.textResults,
    this.isReadingText = false,
    this.onSuspend,
  });

  final bool active;
  final Widget child;
  final Widget? header;
  final Widget? detectionResults;
  final bool analyzeFrames;
  final Future<void> Function(Future<CameraFrame?> Function())? onCaptureText;
  final Widget? textResults;
  final bool isReadingText;
  final VoidCallback? onSuspend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(cameraSessionProvider);
    if (session == null) return child;
    final driver = ref.watch(cameraDriverProvider);
    return _CameraView(
      key: ObjectKey(session),
      active: active,
      session: session,
      driver: driver is FlutterCameraDriver ? driver : null,
      permission: ref.watch(cameraPermissionProvider),
      header: header,
      detectionResults: detectionResults,
      analyzeFrames: analyzeFrames,
      onCaptureText: onCaptureText,
      textResults: textResults,
      isReadingText: isReadingText,
      onSuspend: onSuspend,
      child: child,
    );
  }
}

class _CameraView extends StatefulWidget {
  const _CameraView({
    super.key,
    required this.active,
    required this.session,
    required this.driver,
    required this.permission,
    required this.header,
    required this.child,
    required this.detectionResults,
    required this.analyzeFrames,
    required this.onCaptureText,
    required this.textResults,
    required this.isReadingText,
    required this.onSuspend,
  });

  final bool active;
  final CameraSessionController session;
  final FlutterCameraDriver? driver;
  final PermissionService permission;
  final Widget? header;
  final Widget child;
  final Widget? detectionResults;
  final bool analyzeFrames;
  final Future<void> Function(Future<CameraFrame?> Function())? onCaptureText;
  final Widget? textResults;
  final bool isReadingText;
  final VoidCallback? onSuspend;

  @override
  State<_CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<_CameraView> {
  static const _maxPreviewWidth = 480.0;
  static const _maxPreviewHeight = 390.0;
  static const _previewViewportFraction = 0.50;

  late final AppLifecycleListener _lifecycle;
  bool _foreground = true;
  bool _visible = false;
  bool _requested = false;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground =
        state == null ||
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycleChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = ModalRoute.isCurrentOf(context) ?? true;
    _syncCamera();
  }

  @override
  void didUpdateWidget(_CameraView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_running && oldWidget.analyzeFrames != widget.analyzeFrames) {
      unawaited(widget.session.stopSession());
      _running = false;
    }
    _syncCamera();
  }

  void _onLifecycleChange(AppLifecycleState state) {
    // Android's permission dialog can make the activity temporarily inactive.
    if (state == AppLifecycleState.inactive &&
        widget.session.status == CameraSessionStatus.initializing) {
      return;
    }
    _foreground = state == AppLifecycleState.resumed;
    _syncCamera();
  }

  void _syncCamera() {
    final shouldRun = widget.active && _foreground && _visible;
    if (shouldRun == _running) return;
    _running = shouldRun;
    if (shouldRun) {
      unawaited(
        widget.session.startSession(
          requestPermission: !_requested,
          analyzeFrames: widget.analyzeFrames,
        ),
      );
      _requested = true;
    } else {
      unawaited(widget.session.pauseSession());
      // Route visibility can change during a widget build.
      scheduleMicrotask(() {
        if (mounted && !_running) widget.onSuspend?.call();
      });
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _retryCamera() async {
    await widget.session.stopSession();
    if (mounted && _running) {
      await widget.session.startSession(analyzeFrames: widget.analyzeFrames);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    return StreamBuilder<CameraSessionStatus>(
      stream: widget.session.statusStream,
      builder: (context, _) {
        final status = widget.session.status;
        final preview = widget.driver?.previewController;
        if (preview == null ||
            (status != CameraSessionStatus.previewing &&
                status != CameraSessionStatus.streaming)) {
          return _content(context, status);
        }
        return ValueListenableBuilder<CameraValue>(
          valueListenable: preview,
          builder: (context, value, child) => value.hasError
              ? _content(context, CameraSessionStatus.error)
              : _content(context, status, preview: child),
          child: CameraPreview(preview),
        );
      },
    );
  }

  Widget _content(
    BuildContext context,
    CameraSessionStatus status, {
    Widget? preview,
  }) {
    final l10n = context.l10n;
    final failure = widget.session.failure;
    final permanentlyDenied =
        failure is CameraPermissionDeniedFailure && failure.isPermanentlyDenied;
    final captureText = status == CameraSessionStatus.previewing
        ? widget.onCaptureText
        : null;
    final message = switch (status) {
      CameraSessionStatus.initializing => l10n.cameraOpening,
      CameraSessionStatus.previewing =>
        widget.detectionResults == null
            ? l10n.cameraPreviewReady
            : l10n.cameraDetectionReady,
      CameraSessionStatus.streaming => l10n.cameraDetectionReady,
      CameraSessionStatus.permissionDenied =>
        permanentlyDenied
            ? l10n.cameraPermissionDeniedPermanent
            : l10n.cameraPermissionPrompt,
      CameraSessionStatus.error => l10n.cameraUnavailable,
      _ => l10n.cameraPaused,
    };
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.header case final header?)
          Padding(padding: const EdgeInsets.only(bottom: 12), child: header),
        Semantics(liveRegion: true, child: Text(message)),
        if (captureText != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: widget.isReadingText
                  ? null
                  : () => unawaited(
                      captureText(widget.session.capturePreviewFrame),
                    ),
              icon: const Icon(Icons.document_scanner),
              label: Text(l10n.captureText),
            ),
          ),
        if (preview != null)
          ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: _maxPreviewWidth,
                    maxHeight: math.min(
                      _maxPreviewHeight,
                      MediaQuery.sizeOf(context).height *
                          _previewViewportFraction,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: preview,
                  ),
                ),
              ),
            ),
          ),
        if ((status == CameraSessionStatus.streaming ||
                status == CameraSessionStatus.previewing) &&
            widget.detectionResults != null)
          widget.detectionResults!,
        if (captureText != null) ?widget.textResults,
        if (status == CameraSessionStatus.permissionDenied ||
            status == CameraSessionStatus.error)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: permanentlyDenied
                  ? () => unawaited(widget.permission.openSettings())
                  : _retryCamera,
              child: Text(permanentlyDenied ? l10n.openSettings : l10n.retry),
            ),
          ),
      ],
    );
  }
}
