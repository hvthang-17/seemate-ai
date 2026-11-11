import 'package:fpdart/fpdart.dart';

import 'frame_session_contract.dart';
import 'object_detection_contract.dart';

/// Cancellation token to abort in-flight OCR requests.
class CancellationToken {
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }
}

/// A line or block of recognized text with its position.
class TextSpanInfo {
  const TextSpanInfo({
    required this.text,
    this.boundingBox,
  });

  final String text;
  final BoundingBox? boundingBox;
}

/// Result of an on-demand OCR reading operation.
class OcrResult {
  const OcrResult({
    required this.fullText,
    this.spans = const [],
  });

  final String fullText;
  final List<TextSpanInfo> spans;

  bool get isEmpty => fullText.trim().isEmpty;
  bool get isNotEmpty => !isEmpty;
}

/// Failures that can occur during OCR text reading.
sealed class OcrFailure {
  const OcrFailure();
}

final class OcrProcessingFailure extends OcrFailure {
  const OcrProcessingFailure(this.message);
  final String message;
}

final class EmptyImageFailure extends OcrFailure {
  const EmptyImageFailure();
}

final class LowQualityImageFailure extends OcrFailure {
  const LowQualityImageFailure([this.suggestion = 'Không nhận diện rõ chữ. Hãy tăng ánh sáng hoặc giữ máy ổn định.']);
  final String suggestion;
}

final class OcrCancelledFailure extends OcrFailure {
  const OcrCancelledFailure();
}

final class OcrDisposedFailure extends OcrFailure {
  const OcrDisposedFailure();
}

/// Contract for on-demand on-device OCR reading.
abstract interface class TextReaderContract {
  /// Extracts printed Vietnamese text from a single [frame].
  Future<Either<OcrFailure, OcrResult>> readText(
    CameraFrame frame, {
    CancellationToken? cancelToken,
  });

  /// Releases OCR model resources.
  void dispose();
}
