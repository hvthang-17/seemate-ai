import '../../../shared/assistance_contracts/ocr_contract.dart';
import 'enhanced_ocr_result.dart';

/// Abstract OCR Engine interface for SeeMate AI.
abstract interface class OcrEngine {
  /// Recognizes printed text from a local image file path.
  Future<OcrResult> recognizeFromFile(String filePath);

  /// Performs full multi-pass assessment including quality, candidate evaluation, and post-processing.
  Future<EnhancedOcrResult> processEnhancedFromFile(String filePath);

  /// Recognizes printed text from raw camera frame bytes.
  Future<OcrResult> recognizeFromInput(OcrInput input);

  /// Releases native ML Kit recognizer resources.
  Future<void> dispose();
}
