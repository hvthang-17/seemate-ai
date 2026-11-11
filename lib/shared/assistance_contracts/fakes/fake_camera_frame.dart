import 'dart:typed_data';

import '../frame_session_contract.dart';

/// Helper to create synthetic [CameraFrame] instances for tests and fakes.
CameraFrame createFakeCameraFrame({
  String id = 'test-frame-1',
  String sessionId = 'test-session-1',
  DateTime? timestamp,
  int width = 640,
  int height = 480,
  int rotationDegrees = 0,
  FrameFormat format = FrameFormat.yuv420,
  List<FramePlane>? planes,
  void Function()? onRelease,
}) {
  return CameraFrame(
    id: id,
    sessionId: sessionId,
    timestamp: timestamp ?? DateTime.now(),
    width: width,
    height: height,
    rotationDegrees: rotationDegrees,
    format: format,
    planes: planes ??
        [
          FramePlane(
            bytes: Uint8List(width * height),
            bytesPerRow: width,
            bytesPerPixel: 1,
          ),
        ],
    onRelease: onRelease,
  );
}
