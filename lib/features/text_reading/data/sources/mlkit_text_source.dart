import 'dart:async';
import 'dart:typed_data';

import '../../../../shared/assistance_contracts/ocr_contract.dart';

/// Abstract boundary decoupling the OCR data source from Google ML Kit plugin APIs.
/// Allows pure Dart testing without requiring Android native channels.
abstract interface class MlkitPluginBoundary {
  /// Processes [bytes] with the provided [metadata] and returns recognized text.
  Future<String?> recognizeFromBytes(
    Uint8List bytes,
    ImageMetadata metadata,
  );

  /// Releases native recognizer resources.
  Future<void> close();
}

/// Data source executing on-demand text recognition.
///
/// BACKING PLUGIN REQUIREMENT:
/// N1 adds to `pubspec.yaml`:
/// ```yaml
/// google_mlkit_text_recognition: ^0.13.1
/// ```
/// And ensures Latin script bundled model is configured in Android build.
final class MlkitTextSource {
  MlkitTextSource(this._plugin);

  final MlkitPluginBoundary _plugin;
  final Set<String> _cancelledSessions = <String>{};
  bool _disposed = false;

  bool get isDisposed => _disposed;

  /// Runs text recognition on the input frame.
  /// Safely handles cancellation, empty text, and plugin failures.
  Future<OcrResult> recognizeText(OcrInput input) async {
    if (_disposed) {
      return const OcrFailure('MlkitTextSource has already been disposed');
    }

    // Check cancellation prior to dispatch
    if (_cancelledSessions.remove(input.sessionId)) {
      return const OcrCancelled();
    }

    try {
      final rawText = await _plugin.recognizeFromBytes(
        input.bytes,
        input.metadata,
      );

      // Check cancellation after async plugin execution
      if (_cancelledSessions.remove(input.sessionId)) {
        return const OcrCancelled();
      }

      if (rawText == null || rawText.trim().isEmpty) {
        return const OcrEmpty();
      }

      return OcrSuccess(rawText.trim());
    } on Exception catch (e) {
      if (_cancelledSessions.remove(input.sessionId)) {
        return const OcrCancelled();
      }
      return OcrFailure(e.toString());
    }
  }

  /// Cancels any active or pending recognition request for [sessionId].
  void cancelSession(String sessionId) {
    _cancelledSessions.add(sessionId);
  }

  /// Releases resources.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _cancelledSessions.clear();
    await _plugin.close();
  }
}

// ---------------------------------------------------------------------------
// Testing Fake
// ---------------------------------------------------------------------------

/// Pure Dart fake for unit tests simulating ML Kit behavior.
final class FakeMlkitPlugin implements MlkitPluginBoundary {
  FakeMlkitPlugin({
    this.response,
    this.shouldThrow = false,
  });

  String? response;
  bool shouldThrow;
  bool isClosed = false;

  Uint8List? lastBytes;
  ImageMetadata? lastMetadata;

  @override
  Future<String?> recognizeFromBytes(
    Uint8List bytes,
    ImageMetadata metadata,
  ) async {
    if (shouldThrow) {
      throw Exception('ML Kit native recognition error');
    }
    lastBytes = bytes;
    lastMetadata = metadata;
    return response;
  }

  @override
  Future<void> close() async {
    isClosed = true;
  }
}

// ---------------------------------------------------------------------------
// Production Plugin Boundary (Drop-in when N1 merges dependency)
// ---------------------------------------------------------------------------

/// Production implementation of [MlkitPluginBoundary] using Google ML Kit Latin.
///
/// Note: Keeps plugin dynamic until `google_mlkit_text_recognition` is in pubspec.yaml.
final class ProductionMlkitPlugin implements MlkitPluginBoundary {
  ProductionMlkitPlugin({dynamic textRecognizer})
      : _recognizer = textRecognizer;

  dynamic _recognizer;

  @override
  Future<String?> recognizeFromBytes(
    Uint8List bytes,
    ImageMetadata metadata,
  ) async {
    if (_recognizer == null) {
      throw Exception(
        'ML Kit TextRecognizer is not initialized. N1 must wire google_mlkit_text_recognition.',
      );
    }

    // When wired:
    // final inputImage = InputImage.fromBytes(
    //   bytes: bytes,
    //   metadata: InputImageMetadata(
    //     size: Size(metadata.width.toDouble(), metadata.height.toDouble()),
    //     rotation: InputImageRotationValue.fromRawValue(metadata.rotationDegrees) ?? InputImageRotation.rotation0deg,
    //     format: InputImageFormatValue.fromRawValue(metadata.format.index) ?? InputImageFormat.nv21,
    //     bytesPerRow: metadata.width,
    //   ),
    // );
    // final recognizedText = await _recognizer.processImage(inputImage);
    // return recognizedText.text;

    return null;
  }

  @override
  Future<void> close() async {
    if (_recognizer != null) {
      // await _recognizer.close();
      _recognizer = null;
    }
  }
}
