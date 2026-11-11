import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/camera/camera_session_controller.dart';
import '../../../core/di/get_it.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../shared/assistance_contracts/object_detection_contract.dart';
import 'assistance_providers.dart';

final cameraDriverProvider = Provider.autoDispose<CameraDriverAdapter?>(
  (ref) => null,
);

final cameraPermissionProvider = Provider<PermissionService>(
  (ref) => getIt<PermissionService>(),
);

final cameraDetectionEnabledProvider = Provider<bool>((ref) => false);

final cameraSessionProvider = Provider.autoDispose<CameraSessionController?>((
  ref,
) {
  final driver = ref.watch(cameraDriverProvider);
  if (driver == null) return null;
  final detectionEnabled = ref.watch(cameraDetectionEnabledProvider);
  late final CameraSessionController session;
  session = CameraSessionController(
    permissionService: ref.watch(cameraPermissionProvider),
    driverAdapter: driver,
    onFrame: detectionEnabled
        ? (frame) async {
            if (session.isDisposed) return;
            final failure = ref
                .read(assistanceNotifierProvider)
                .detectionFailure;
            if (failure is ModelNotLoadedFailure ||
                failure is DetectorInitializationFailure ||
                failure is UnsupportedDetectionTargetFailure) {
              return;
            }
            await ref
                .read(assistanceNotifierProvider.notifier)
                .processFrame(
                  frame,
                  isCurrentFrame: () =>
                      session.currentSessionId == frame.sessionId,
                );
          }
        : null,
  );
  ref.onDispose(() => unawaited(session.dispose()));
  return session;
});
