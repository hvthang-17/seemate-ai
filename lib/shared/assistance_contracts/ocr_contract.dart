/// Domain contracts and value objects for OCR text reading.
library;

import 'package:flutter/foundation.dart';

/// Supported camera frame pixel formats for OCR preprocessing.
enum PixelFormat {
  nv21,
  yuv420,
  bgra8888,
}

/// Metadata required to correctly interpret a camera frame image buffer.
@immutable
final class ImageMetadata {
  const ImageMetadata({
    required this.width,
    required this.height,
    required this.format,
    required this.rotationDegrees,
  });

  final int width;
  final int height;
  final PixelFormat format;

  /// Clockwise rotation relative to sensor orientation (0, 90, 180, 270).
  final int rotationDegrees;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageMetadata &&
          width == other.width &&
          height == other.height &&
          format == other.format &&
          rotationDegrees == other.rotationDegrees;

  @override
  int get hashCode => Object.hash(width, height, format, rotationDegrees);

  @override
  String toString() =>
      'ImageMetadata(${width}x$height, $format, ${rotationDegrees}deg)';
}

/// Input payload passed to the OCR pipeline.
@immutable
final class OcrInput {
  const OcrInput({
    required this.sessionId,
    required this.bytes,
    required this.metadata,
  });

  /// Session or frame identifier used to support request cancellation.
  final String sessionId;

  /// Raw byte buffer of the image frame.
  final Uint8List bytes;

  /// Dimensions, format, and orientation metadata.
  final ImageMetadata metadata;

  @override
  String toString() => 'OcrInput(sessionId: $sessionId, ${bytes.length} bytes)';
}

// ---------------------------------------------------------------------------
// OcrResult sealed hierarchy
// ---------------------------------------------------------------------------

/// Sealed outcome of an OCR recognition operation.
sealed class OcrResult {
  const OcrResult();
}

/// Text was successfully recognized in the image.
final class OcrSuccess extends OcrResult {
  const OcrSuccess(this.text);

  /// Extracted text in reading order with Vietnamese diacritics preserved.
  final String text;

  @override
  String toString() => 'OcrSuccess(text: $text)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is OcrSuccess && text == other.text;

  @override
  int get hashCode => text.hashCode;
}

/// The image was processed, but no recognizable text was detected.
final class OcrEmpty extends OcrResult {
  const OcrEmpty();

  @override
  String toString() => 'OcrEmpty()';

  @override
  bool operator ==(Object other) => identical(this, other) || other is OcrEmpty;

  @override
  int get hashCode => 0;
}

/// An error occurred during recognition (e.g. invalid format, plugin failure).
final class OcrFailure extends OcrResult {
  const OcrFailure(this.message);

  final String message;

  @override
  String toString() => 'OcrFailure(message: $message)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is OcrFailure && message == other.message;

  @override
  int get hashCode => message.hashCode;
}

/// The OCR request was explicitly cancelled (e.g. user moved away or stopped).
final class OcrCancelled extends OcrResult {
  const OcrCancelled();

  @override
  String toString() => 'OcrCancelled()';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is OcrCancelled;

  @override
  int get hashCode => 1;
}
