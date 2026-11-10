import '../models/ocr_result.dart';

/// Repository interface for on-demand printed text recognition.
abstract interface class TextReadingRepository {
  /// Recognizes printed text from the provided [input] frame.
  /// Always returns a typed [OcrResult]; does not throw unchecked exceptions.
  Future<OcrResult> recognizeText(OcrInput input);

  /// Cancels any active or pending recognition request for [sessionId].
  void cancelSession(String sessionId);

  /// Releases underlying recognizer resources.
  Future<void> dispose();
}
