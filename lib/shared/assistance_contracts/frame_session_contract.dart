import 'dart:typed_data';

/// Format of the camera frame buffer.
enum FrameFormat {
  yuv420,
  bgra8888,
  jpeg,
  nv21,
}

/// A single image plane within a camera frame.
class FramePlane {
  const FramePlane({
    required this.bytes,
    required this.bytesPerRow,
    this.bytesPerPixel,
  });

  final Uint8List bytes;
  final int bytesPerRow;
  final int? bytesPerPixel;
}

/// An uncropped sensor frame. [rotationDegrees] rotates it clockwise into
/// upright view coordinates. Model resizing and cropping belong to the
/// inference adapter, which maps its output back to the upright full frame.
///
/// The driver keeps [planes] valid until [release], including during camera
/// shutdown. It copies buffers whose native lifetime cannot meet that rule.
/// Adapters borrow the planes only until their future completes. A delivered
/// frame goes to one consumer, which releases it when its adapter finishes.
/// The camera session releases dropped frames and any unreleased frame when
/// the consumer completes.
class CameraFrame {
  CameraFrame({
    required this.id,
    required this.sessionId,
    required this.timestamp,
    required this.width,
    required this.height,
    required this.rotationDegrees,
    required this.format,
    required this.planes,
    void Function()? onRelease,
  }) : _onRelease = onRelease;

  final String id;
  final String sessionId;
  final DateTime timestamp;
  final int width;
  final int height;
  final int rotationDegrees;
  final FrameFormat format;
  final List<FramePlane> planes;

  final void Function()? _onRelease;
  bool _isReleased = false;

  bool get isReleased => _isReleased;

  /// Releases the native buffer or memory associated with this frame.
  void release() {
    if (_isReleased) return;
    _isReleased = true;
    _onRelease?.call();
  }
}

/// Status of the camera session.
enum CameraSessionStatus {
  idle,
  initializing,
  previewing,
  streaming,
  paused,
  closed,
  permissionDenied,
  error,
}

/// Failure states for camera operations.
sealed class CameraSessionFailure {
  const CameraSessionFailure();
}

final class CameraPermissionDeniedFailure extends CameraSessionFailure {
  const CameraPermissionDeniedFailure({this.isPermanentlyDenied = false});
  final bool isPermanentlyDenied;
}

final class CameraNotFoundFailure extends CameraSessionFailure {
  const CameraNotFoundFailure();
}

final class CameraStreamingFailure extends CameraSessionFailure {
  const CameraStreamingFailure(this.message);
  final String message;
}

final class CameraDisposedFailure extends CameraSessionFailure {
  const CameraDisposedFailure();
}

final class CameraSessionCancelledFailure extends CameraSessionFailure {
  const CameraSessionCancelledFailure();
}
