import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

import '../../shared/assistance_contracts/frame_session_contract.dart';
import 'camera_session_controller.dart';

/// Owns the rear Android camera and exposes uncropped YUV planes in memory.
final class FlutterCameraDriver implements CameraDriverAdapter {
  CameraController? _controller;

  CameraController? get previewController => _controller;

  @override
  Future<bool> initializeCamera() async {
    final cameras = await availableCameras();
    final rear = cameras.where(
      (camera) => camera.lensDirection == CameraLensDirection.back,
    );
    if (rear.isEmpty) return false;

    final controller = CameraController(
      rear.first,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    _controller = controller;
    await controller.initialize();
    return true;
  }

  @override
  Future<void> startFrameStream(
    String sessionId,
    void Function(CameraFrame frame) onFrame,
  ) async {
    final controller = _controller;
    if (controller == null) {
      throw CameraException(
        'Uninitialized',
        'Camera initialization is required',
      );
    }
    var sequence = 0;
    await controller.startImageStream((image) {
      if (image.format.group != ImageFormatGroup.yuv420 ||
          image.planes.length != 3) {
        return;
      }
      onFrame(
        CameraFrame(
          id: '$sessionId-${++sequence}',
          sessionId: sessionId,
          timestamp: DateTime.now(),
          width: image.width,
          height: image.height,
          rotationDegrees: rearCameraRotation(
            controller.description.sensorOrientation,
            controller.value.deviceOrientation,
          ),
          format: FrameFormat.yuv420,
          // The plugin delivers Dart-owned Uint8Lists over the platform channel.
          planes: [
            for (final plane in image.planes)
              FramePlane(
                bytes: plane.bytes,
                bytesPerRow: plane.bytesPerRow,
                bytesPerPixel: plane.bytesPerPixel,
              ),
          ],
        ),
      );
    });
  }

  @override
  Future<void> stopFrameStream() async {
    final controller = _controller;
    if (controller != null && controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }
  }

  @override
  Future<void> closeCamera() async {
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
  }
}

int rearCameraRotation(int sensorDegrees, DeviceOrientation orientation) {
  final deviceDegrees = switch (orientation) {
    DeviceOrientation.portraitUp => 0,
    DeviceOrientation.landscapeLeft => 90,
    DeviceOrientation.portraitDown => 180,
    DeviceOrientation.landscapeRight => 270,
  };
  return (sensorDegrees - deviceDegrees) % 360;
}
