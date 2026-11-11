import 'package:fpdart/fpdart.dart';

import '../frame_session_contract.dart';
import '../object_detection_contract.dart';

/// In-memory fake implementation of [ObjectDetectorContract] for unit & widget tests.
class FakeObjectDetector implements ObjectDetectorContract {
  FakeObjectDetector({
    this.cannedDetections = const [],
    this.failureToReturn,
    this.simulatedDelay = Duration.zero,
  });

  List<DetectedObject> cannedDetections;
  DetectionFailure? failureToReturn;
  Duration simulatedDelay;

  final List<CameraFrame> receivedFrames = [];
  bool isDisposed = false;

  @override
  Future<Either<DetectionFailure, DetectionResult>> detect(
    CameraFrame frame, {
    ObjectKey? targetKey,
    double confidenceThreshold = defaultDetectionConfidenceThreshold,
    Object? requestSession,
  }) async {
    if (isDisposed) {
      return const Left(SessionDisposedFailure());
    }

    receivedFrames.add(frame);
    if (simulatedDelay > Duration.zero) {
      await Future<void>.delayed(simulatedDelay);
    }

    if (failureToReturn != null) {
      return Left(failureToReturn!);
    }

    final filtered = cannedDetections.where((det) {
      if (det.confidence < confidenceThreshold) return false;
      if (targetKey != null && det.key != targetKey) return false;
      return true;
    }).toList();

    return Right(
      filtered.isEmpty
          ? const DetectionResult.noMatch()
          : DetectionResult.stable(filtered),
    );
  }

  @override
  void dispose() {
    isDisposed = true;
  }
}
