import '../../../shared/assistance_contracts/ocr_contract.dart';
import '../domain/enhanced_ocr_result.dart';
import '../domain/image_quality_assessor.dart';
import '../domain/ocr_engine.dart';

/// In-memory fake OCR engine for unit testing without depending on Google Play Services or camera hardware.
final class FakeOcrEngine implements OcrEngine {
  FakeOcrEngine({this.cannedResult});

  OcrResult? cannedResult;
  bool isDisposed = false;
  String? lastRecognizedFile;
  OcrInput? lastRecognizedInput;

  @override
  Future<OcrResult> recognizeFromFile(String filePath) async {
    if (isDisposed) {
      return const OcrFailure('Engine disposed');
    }
    lastRecognizedFile = filePath;
    return cannedResult ?? const OcrEmpty();
  }

  @override
  Future<EnhancedOcrResult> processEnhancedFromFile(String filePath) async {
    final base = await recognizeFromFile(filePath);
    final text = base is OcrSuccess ? base.text : '';
    return EnhancedOcrResult.evaluate(
      baseResult: base,
      rawText: text,
      qualityResult: const ImageQualityResult(
        sharpnessScore: 100,
        meanLuminance: 120,
        width: 1920,
        height: 1080,
        issues: [],
      ),
    );
  }

  @override
  Future<OcrResult> recognizeFromInput(OcrInput input) async {
    if (isDisposed) {
      return const OcrFailure('Engine disposed');
    }
    lastRecognizedInput = input;
    return cannedResult ?? const OcrEmpty();
  }

  @override
  Future<void> dispose() async {
    isDisposed = true;
  }
}
