import 'dart:async';

import 'package:flutter/services.dart';
import 'package:fpdart/fpdart.dart';

import '../../../shared/assistance_contracts/frame_session_contract.dart';
import '../../../shared/assistance_contracts/text_reader_contract.dart';

/// Reads a single live camera frame using Android's bundled Latin recognizer.
final class MlKitTextReader implements TextReaderContract {
  MlKitTextReader({
    MethodChannel channel = const MethodChannel('seemate/text_recognition'),
  }) : _channel = channel;

  final MethodChannel _channel;
  bool _disposed = false;
  bool _reading = false;

  @override
  Future<Either<OcrFailure, OcrResult>> readText(
    CameraFrame frame, {
    CancellationToken? cancelToken,
  }) async {
    final inactive = _inactive(cancelToken);
    if (inactive != null) return Left(inactive);
    if (_reading) return const Left(OcrProcessingFailure('OCR is busy'));
    if (frame.isReleased ||
        frame.planes.isEmpty ||
        frame.planes.any((plane) => plane.bytes.isEmpty)) {
      return const Left(EmptyImageFailure());
    }
    if (frame.format != FrameFormat.yuv420 ||
        frame.planes.length != 3 ||
        frame.width <= 0 ||
        frame.height <= 0 ||
        frame.width.isOdd ||
        frame.height.isOdd ||
        !const {0, 90, 180, 270}.contains(frame.rotationDegrees)) {
      return const Left(OcrProcessingFailure('Unsupported OCR frame metadata'));
    }

    _reading = true;
    try {
      final result = await _channel.invokeMapMethod<String, Object?>('read', {
        'width': frame.width,
        'height': frame.height,
        'rotation': frame.rotationDegrees,
        'planes': [
          for (final plane in frame.planes)
            {
              'bytes': plane.bytes,
              'rowStride': plane.bytesPerRow,
              'pixelStride': plane.bytesPerPixel,
            },
        ],
      });
      final inactive = _inactive(cancelToken);
      if (inactive != null) return Left(inactive);
      final text = result?['text'];
      final lines = result?['lines'];
      if (text is! String || lines is! List<Object?>) {
        return const Left(OcrProcessingFailure('Invalid OCR response'));
      }
      return Right(
        OcrResult(
          fullText: text,
          spans: [
            for (final line in lines.whereType<String>())
              TextSpanInfo(text: line),
          ],
        ),
      );
    } on PlatformException catch (error) {
      return Left(
        _inactive(cancelToken) ??
            switch (error.code) {
              'ocr_disposed' => const OcrDisposedFailure(),
              'invalid_image' => const OcrProcessingFailure(
                'Invalid OCR frame',
              ),
              'ocr_busy' => const OcrProcessingFailure('OCR is busy'),
              _ => const OcrProcessingFailure(
                'Android text recognition failed',
              ),
            },
      );
    } on MissingPluginException {
      return Left(
        _inactive(cancelToken) ??
            const OcrProcessingFailure(
              'Android text recognition is unavailable',
            ),
      );
    } finally {
      _reading = false;
    }
  }

  OcrFailure? _inactive(CancellationToken? token) {
    if (_disposed) return const OcrDisposedFailure();
    if (token?.isCancelled ?? false) return const OcrCancelledFailure();
    return null;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_disposeNative());
  }

  Future<void> _disposeNative() async {
    try {
      await _channel.invokeMethod<void>('dispose');
    } on PlatformException {
      // Native cleanup also runs when the Flutter engine detaches.
    } on MissingPluginException {
      // There is no native recognizer to release.
    }
  }
}
