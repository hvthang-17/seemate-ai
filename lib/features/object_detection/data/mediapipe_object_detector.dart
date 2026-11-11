import 'dart:async';

import 'package:flutter/services.dart';
import 'package:fpdart/fpdart.dart';

import '../../../shared/assistance_contracts/frame_session_contract.dart';
import '../../../shared/assistance_contracts/object_detection_contract.dart';
import '../domain/detection_stability.dart';
import '../domain/v1_detection_catalog.dart';

/// Android adapter for the bundled, offline EfficientDet-Lite0 baseline.
final class MediaPipeObjectDetector implements ObjectDetectorContract {
  MediaPipeObjectDetector({
    MethodChannel channel = const MethodChannel('seemate/object_detection'),
  }) : _channel = channel;

  final MethodChannel _channel;
  final _stability = DetectionStability();
  Object? _requestSession;
  ({
    String cameraSession,
    int rotation,
    int width,
    int height,
    ObjectKey? target,
    double threshold,
  })?
  _trackingContext;
  String? _lastFrameId;
  bool _disposed = false;
  DetectionFailure? _initializationFailure;
  bool _busy = false;

  @override
  Future<Either<DetectionFailure, DetectionResult>> detect(
    CameraFrame frame, {
    ObjectKey? targetKey,
    double confidenceThreshold = defaultDetectionConfidenceThreshold,
    Object? requestSession,
  }) async {
    if (_disposed) return const Left(SessionDisposedFailure());
    if (_busy) return const Left(FrameProcessingBusyFailure());
    final context = (
      cameraSession: frame.sessionId,
      rotation: frame.rotationDegrees,
      width: frame.width,
      height: frame.height,
      target: targetKey,
      threshold: confidenceThreshold,
    );
    if (_trackingContext != context ||
        !identical(_requestSession, requestSession)) {
      _trackingContext = context;
      _requestSession = requestSession;
      _lastFrameId = null;
      _stability.reset();
    }
    if (targetKey != null && !v1DetectionLabels.containsValue(targetKey)) {
      return Left(UnsupportedDetectionTargetFailure(targetKey));
    }
    final initializationFailure = _initializationFailure;
    if (initializationFailure != null) return Left(initializationFailure);
    if (frame.isReleased ||
        frame.format != FrameFormat.yuv420 ||
        frame.planes.length != 3) {
      _stability.reset();
      return const Left(InferenceFailure('Expected a live YUV420 frame'));
    }
    if (_lastFrameId == frame.id) {
      return const Right(DetectionResult.stabilizing());
    }
    _lastFrameId = frame.id;

    _busy = true;
    try {
      final output = await _channel.invokeListMethod<Object?>('detect', {
        'width': frame.width,
        'height': frame.height,
        'rotation': frame.rotationDegrees,
        'confidenceThreshold': confidenceThreshold,
        'planes': [
          for (final plane in frame.planes)
            {
              'bytes': plane.bytes,
              'rowStride': plane.bytesPerRow,
              'pixelStride': plane.bytesPerPixel,
            },
        ],
      });
      if (_disposed) return const Left(SessionDisposedFailure());
      final detections = [
        for (final item in output ?? const <Object?>[])
          ?_parse(item, targetKey, confidenceThreshold),
      ]..sort((a, b) => b.confidence.compareTo(a.confidence));
      final stable = _stability.update(
        detections,
        isTargetSearch: targetKey != null,
      );
      if (detections.isEmpty) return const Right(DetectionResult.noMatch());
      if (stable.isEmpty) return const Right(DetectionResult.stabilizing());
      return Right(DetectionResult.stable(stable));
    } on PlatformException catch (error) {
      _stability.reset();
      if (error.code == 'model_unavailable') {
        _initializationFailure = const ModelNotLoadedFailure();
        return const Left(ModelNotLoadedFailure());
      }
      if (error.code == 'detector_init_failed') {
        _initializationFailure = const DetectorInitializationFailure();
        return const Left(DetectorInitializationFailure());
      }
      return const Left(InferenceFailure('Android object detection failed'));
    } on MissingPluginException {
      _stability.reset();
      return const Left(InferenceFailure('Android detector is unavailable'));
    } finally {
      _busy = false;
    }
  }

  DetectedObject? _parse(Object? item, ObjectKey? target, double threshold) {
    if (item is! Map<Object?, Object?>) return null;
    final label = item['label'];
    final score = item['score'];
    final left = _coordinate(item['left']);
    final top = _coordinate(item['top']);
    final right = _coordinate(item['right']);
    final bottom = _coordinate(item['bottom']);
    if (label is! String ||
        score is! num ||
        !score.isFinite ||
        score < threshold ||
        score < 0 ||
        score > 1 ||
        left == null ||
        top == null ||
        right == null ||
        bottom == null ||
        right <= left ||
        bottom <= top) {
      return null;
    }
    final key = v1DetectionLabels[label];
    if (key == null || (target != null && key != target)) return null;

    final box = BoundingBox(
      left: left,
      top: top,
      width: right - left,
      height: bottom - top,
    );
    return DetectedObject(
      key: key,
      label: label,
      confidence: score.toDouble(),
      boundingBox: box,
      zone: box.deriveZone(),
    );
  }

  double? _coordinate(Object? value) =>
      value is num && value.isFinite ? value.clamp(0, 1).toDouble() : null;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _stability.reset();
    unawaited(_closeNativeDetector());
  }

  Future<void> _closeNativeDetector() async {
    try {
      await _channel.invokeMethod<void>('dispose');
    } on PlatformException {
      // The activity also closes its native detector when the engine detaches.
    } on MissingPluginException {
      // No native resources were created.
    }
  }
}
