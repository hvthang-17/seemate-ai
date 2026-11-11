import 'package:fpdart/fpdart.dart';

import 'frame_session_contract.dart';

/// Product object keys, including classes reserved for later models.
enum AssistanceObjectKey {
  // Personal items
  phone('Phone', 'điện thoại'),
  wallet('Wallet', 'ví tiền'),
  keys('Keys', 'chìa khóa'),
  backpack('Backpack', 'ba lô'),

  // Drinks
  bottle('Bottle', 'chai nước'),
  cup('Cup', 'cốc'),

  // Food
  apple('Apple', 'quả táo'),
  banana('Banana', 'quả chuối'),
  bread('Bread', 'bánh mì'),

  // Household items
  chair('Chair', 'cái ghế'),
  table('Table', 'cái bàn'),
  book('Book', 'quyển sách'),
  remote('Remote', 'điều khiển'),

  // Electronics
  laptop('Laptop', 'máy tính xách tay'),
  keyboard('Keyboard', 'bàn phím'),
  mouse('Mouse', 'chuột máy tính'),

  // Other items
  clock('Clock', 'đồng hồ'),
  scissors('Scissors', 'cái kéo'),
  umbrella('Umbrella', 'cây dù');

  const AssistanceObjectKey(this.englishLabel, this.vietnameseLabel);

  final String englishLabel;
  final String vietnameseLabel;

  /// Attempt to match a spoken Vietnamese phrase to an [AssistanceObjectKey].
  static AssistanceObjectKey? tryParseVietnamese(String text) {
    final normalized = text.toLowerCase().trim();
    for (final key in AssistanceObjectKey.values) {
      if (normalized.contains(key.vietnameseLabel) ||
          normalized.contains(key.englishLabel.toLowerCase())) {
        return key;
      }
    }
    // Specific alias checks
    if (normalized.contains('chai') || normalized.contains('nước')) {
      return AssistanceObjectKey.bottle;
    }
    if (normalized.contains('sách') || normalized.contains('vở')) {
      return AssistanceObjectKey.book;
    }
    if (normalized.contains('khóa')) {
      return AssistanceObjectKey.keys;
    }
    if (normalized.contains('ghế')) {
      return AssistanceObjectKey.chair;
    }
    if (normalized.contains('bàn') && !normalized.contains('bàn phím')) {
      return AssistanceObjectKey.table;
    }
    if (normalized.contains('ví') || normalized.contains('bóp')) {
      return AssistanceObjectKey.wallet;
    }
    if (normalized.contains('điện thoại') || normalized.contains('phone')) {
      return AssistanceObjectKey.phone;
    }
    return null;
  }
}

/// Alias for [AssistanceObjectKey] for backward and contract compatibility.
typedef ObjectKey = AssistanceObjectKey;

const defaultDetectionConfidenceThreshold = 0.50;

/// Relative horizontal zone in the camera frame.
enum HorizontalZone {
  left('bên trái'),
  center('ở giữa'),
  right('bên phải');

  const HorizontalZone(this.vietnameseLabel);
  final String vietnameseLabel;
}

/// Normalized bounding box coordinates within [0.0, 1.0].
class BoundingBox {
  const BoundingBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;
  double get centerX => left + (width / 2.0);
  double get centerY => top + (height / 2.0);

  /// Partitions the horizontal axis into exactly three zones based on [centerX].
  HorizontalZone deriveZone({
    double leftBoundary = 0.33,
    double rightBoundary = 0.66,
  }) {
    if (centerX < leftBoundary) {
      return HorizontalZone.left;
    } else if (centerX > rightBoundary) {
      return HorizontalZone.right;
    }
    return HorizontalZone.center;
  }
}

/// A single detected object in a camera frame.
class DetectedObject {
  const DetectedObject({
    required this.key,
    required this.label,
    required this.confidence,
    required this.boundingBox,
    required this.zone,
  });

  final ObjectKey key;
  final String label;
  final double confidence;
  final BoundingBox boundingBox;
  final HorizontalZone zone;

  String toSpokenPhrase() => '${key.vietnameseLabel} ${zone.vietnameseLabel}';
}

enum DetectionReadiness { noMatch, stabilizing, stable }

class DetectionResult {
  const DetectionResult.noMatch()
    : readiness = DetectionReadiness.noMatch,
      objects = const [];
  const DetectionResult.stabilizing()
    : readiness = DetectionReadiness.stabilizing,
      objects = const [];
  const DetectionResult.stable(this.objects)
    : readiness = DetectionReadiness.stable;

  final DetectionReadiness readiness;
  final List<DetectedObject> objects;
}

/// Failures that can occur during object detection.
sealed class DetectionFailure {
  const DetectionFailure();
}

final class ModelNotLoadedFailure extends DetectionFailure {
  const ModelNotLoadedFailure([this.message = 'Model is not loaded']);
  final String message;
}

final class DetectorInitializationFailure extends DetectionFailure {
  const DetectorInitializationFailure();
}

final class InferenceFailure extends DetectionFailure {
  const InferenceFailure(this.message);
  final String message;
}

final class FrameProcessingBusyFailure extends DetectionFailure {
  const FrameProcessingBusyFailure();
}

final class UnsupportedDetectionTargetFailure extends DetectionFailure {
  const UnsupportedDetectionTargetFailure(this.target);
  final ObjectKey target;
}

final class SessionDisposedFailure extends DetectionFailure {
  const SessionDisposedFailure();
}

/// Contract for on-device object detection.
abstract interface class ObjectDetectorContract {
  /// Processes [frame] and returns qualifying detections for that frame only.
  ///
  /// The caller correlates this future with [CameraFrame.id] and
  /// [CameraFrame.sessionId] and drops results from obsolete requests.
  /// Boxes are normalized to the upright full frame.
  ///
  /// If [targetKey] is provided, only matches for that key should be returned.
  /// Production detectors return only stable matches. Readiness distinguishes
  /// a qualifying candidate being tracked from a frame without a match.
  /// Keep [requestSession] constant within a mode/target request and replace it
  /// on cancellation or mode changes, even when the camera session is reused.
  Future<Either<DetectionFailure, DetectionResult>> detect(
    CameraFrame frame, {
    ObjectKey? targetKey,
    double confidenceThreshold = defaultDetectionConfidenceThreshold,
    Object? requestSession,
  });

  /// Releases inference models and native resources.
  void dispose();
}
