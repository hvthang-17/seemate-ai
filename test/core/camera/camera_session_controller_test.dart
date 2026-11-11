import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_agentic_starter/core/camera/camera_session_controller.dart';
import 'package:flutter_agentic_starter/core/permissions/permission_service.dart';
import 'package:flutter_agentic_starter/shared/assistance_contracts/assistance_contracts.dart';

class _FakePermissionService implements PermissionService {
  _FakePermissionService({this.status = AppPermissionStatus.granted});
  AppPermissionStatus status;

  @override
  Future<AppPermissionStatus> check(AppPermission permission) async => status;

  @override
  Future<AppPermissionStatus> request(AppPermission permission) async => status;

  @override
  Future<bool> openSettings() async => true;
}

class _DelayedCameraDriver extends FakeCameraDriverAdapter {
  final enteredInitialize = Completer<void>();
  final allowInitialize = Completer<bool>();

  @override
  Future<bool> initializeCamera() {
    enteredInitialize.complete();
    return allowInitialize.future;
  }
}

void main() {
  group('CameraSessionController lifecycle and permission checks', () {
    test('starts session when camera permission is granted', () async {
      final fakePerms = _FakePermissionService(
        status: AppPermissionStatus.granted,
      );
      final fakeDriver = FakeCameraDriverAdapter();
      final controller = CameraSessionController(
        permissionService: fakePerms,
        driverAdapter: fakeDriver,
        onFrame: (_) async {},
      );

      final result = await controller.startSession();
      expect(result.isRight(), isTrue);
      expect(controller.status, CameraSessionStatus.streaming);
      expect(controller.currentSessionId, isNotNull);
      expect(fakeDriver.isStreaming, isTrue);

      await controller.stopSession();
      expect(controller.status, CameraSessionStatus.closed);
    });

    test('fails and sets status when permission is denied', () async {
      final fakePerms = _FakePermissionService(
        status: AppPermissionStatus.denied,
      );
      final controller = CameraSessionController(permissionService: fakePerms);

      final result = await controller.startSession();
      expect(result.isLeft(), isTrue);
      result.fold((failure) {
        expect(failure, isA<CameraPermissionDeniedFailure>());
        expect(
          (failure as CameraPermissionDeniedFailure).isPermanentlyDenied,
          isFalse,
        );
      }, (_) => fail('Expected permission denied failure'));
      expect(controller.status, CameraSessionStatus.permissionDenied);
    });

    test('fails when permission is permanently denied', () async {
      final fakePerms = _FakePermissionService(
        status: AppPermissionStatus.permanentlyDenied,
      );
      final controller = CameraSessionController(permissionService: fakePerms);

      final result = await controller.startSession();
      expect(result.isLeft(), isTrue);
      result.fold((failure) {
        expect(
          (failure as CameraPermissionDeniedFailure).isPermanentlyDenied,
          isTrue,
        );
      }, (_) => fail('Expected permission denied failure'));
      expect(controller.status, CameraSessionStatus.permissionDenied);
    });

    test('backlog prevention drops frame when consumer is busy', () async {
      final fakePerms = _FakePermissionService();
      final fakeDriver = FakeCameraDriverAdapter();
      final receivedFrames = <CameraFrame>[];
      final pending = Completer<void>();
      final controller = CameraSessionController(
        permissionService: fakePerms,
        driverAdapter: fakeDriver,
        onFrame: (frame) {
          receivedFrames.add(frame);
          return pending.future;
        },
      );
      addTearDown(controller.dispose);

      await controller.startSession();

      // 1. Frame emitted while NOT busy
      bool frame1Released = false;
      fakeDriver.emitSyntheticFrame(
        createFakeCameraFrame(
          id: 'frame-1',
          sessionId: controller.currentSessionId!,
          onRelease: () => frame1Released = true,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(receivedFrames.length, 1);
      expect(frame1Released, isFalse);

      // 2. Set consumer busy -> next frame must be dropped and released
      bool frame2Released = false;
      fakeDriver.emitSyntheticFrame(
        createFakeCameraFrame(
          id: 'frame-2',
          sessionId: controller.currentSessionId!,
          onRelease: () => frame2Released = true,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(receivedFrames.length, 1); // Not added to stream
      expect(frame2Released, isTrue); // Auto-released
      pending.complete();
      await Future<void>.delayed(Duration.zero);
      expect(frame1Released, isTrue);
    });

    test('handles pause and resume correctly', () async {
      final fakePerms = _FakePermissionService();
      final fakeDriver = FakeCameraDriverAdapter();
      final controller = CameraSessionController(
        permissionService: fakePerms,
        driverAdapter: fakeDriver,
        onFrame: (_) async {},
      );

      await controller.startSession();
      expect(controller.status, CameraSessionStatus.streaming);

      await controller.pauseSession();
      expect(controller.status, CameraSessionStatus.paused);
      expect(fakeDriver.isStreaming, isFalse);

      await controller.resumeSession();
      expect(controller.status, CameraSessionStatus.streaming);
      expect(fakeDriver.isStreaming, isTrue);
    });

    test(
      'opens preview without starting analysis when there is no consumer',
      () async {
        final driver = FakeCameraDriverAdapter();
        final controller = CameraSessionController(
          permissionService: _FakePermissionService(),
          driverAdapter: driver,
        );
        addTearDown(controller.dispose);
        await controller.startSession();
        expect(controller.status, CameraSessionStatus.previewing);
        expect(driver.isStreaming, isFalse);
      },
    );

    test('cancels one-shot capture before closing the camera', () async {
      final driver = FakeCameraDriverAdapter();
      final controller = CameraSessionController(
        permissionService: _FakePermissionService(),
        driverAdapter: driver,
      );
      addTearDown(controller.dispose);
      await controller.startSession(analyzeFrames: false);
      final capture = controller.capturePreviewFrame();
      await Future<void>.delayed(Duration.zero);
      expect(driver.isStreaming, isTrue);
      final staleListener = driver.frameListener!;

      await controller.pauseSession();
      expect(await capture, isNull);
      expect(driver.isClosed, isTrue);
      final lateFrame = createFakeCameraFrame();
      staleListener(lateFrame);
      expect(lateFrame.isReleased, isTrue);
    });

    test('releases stale frames before calling the consumer', () async {
      final driver = FakeCameraDriverAdapter();
      final frames = <CameraFrame>[];
      final controller = CameraSessionController(
        permissionService: _FakePermissionService(),
        driverAdapter: driver,
        onFrame: (frame) async => frames.add(frame),
      );
      addTearDown(controller.dispose);
      await controller.startSession();
      final stale = createFakeCameraFrame(sessionId: 'old-session');
      driver.emitSyntheticFrame(stale);
      await Future<void>.delayed(Duration.zero);
      expect(stale.isReleased, isTrue);
      expect(frames, isEmpty);
    });

    test('stopping cancels pending starts and closes the driver', () async {
      final driver = _DelayedCameraDriver();
      final controller = CameraSessionController(
        permissionService: _FakePermissionService(),
        driverAdapter: driver,
      );
      addTearDown(controller.dispose);

      final first = controller.startSession();
      await driver.enteredInitialize.future;
      final second = controller.startSession();
      final stopping = controller.stopSession();
      driver.allowInitialize.complete(true);
      await stopping;

      for (final start in [first, second]) {
        (await start).match(
          (failure) => expect(failure, isA<CameraSessionCancelledFailure>()),
          (_) => fail('Cancelled start was reported as successful'),
        );
      }
      expect(controller.status, CameraSessionStatus.closed);
      expect(controller.currentSessionId, isNull);
      expect(driver.isClosed, isTrue);
      expect(driver.isStreaming, isFalse);
    });
  });
}
