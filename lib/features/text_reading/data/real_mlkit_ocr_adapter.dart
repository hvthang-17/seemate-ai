import 'dart:async';
import 'dart:io';
import 'dart:ui';

import '../../../shared/assistance_contracts/ocr_contract.dart';
import '../domain/enhanced_ocr_result.dart';
import '../domain/image_quality_assessor.dart';
import '../domain/image_region_optimizer.dart';
import '../domain/multi_pass_ocr_pipeline.dart';
import '../domain/ocr_candidate_evaluator.dart';
import '../domain/ocr_engine.dart';
import '../domain/vietnamese_ocr_post_processor.dart';

/// Production implementation of [OcrEngine] using on-device Google ML Kit (Latin model)
/// enhanced with:
/// - Region optimization (EXIF orientation, bounding box cropping)
/// - Multi-pass OCR pipeline (Pass A: Original, Pass B: Cropped, Pass C: Enhanced)
/// - Candidate evaluator (Vietnamese syllable validity, line confidences, conflict detection)
/// - Conservative Vietnamese post-processor (Unicode NFC, label corrections, zero guessing)
///
/// BACKING PLUGIN REQUIREMENT:
/// N1 adds to `pubspec.yaml`:
/// ```yaml
/// google_mlkit_text_recognition: ^0.13.1
/// ```
/// And adds meta-data to `AndroidManifest.xml`:
/// ```xml
/// <meta-data android:name="com.google.mlkit.vision.DEPENDENCIES" android:value="ocr" />
/// ```
final class RealMlkitOcrAdapter implements OcrEngine {
  RealMlkitOcrAdapter({
    dynamic recognizer,
    ImageQualityAssessor? qualityAssessor,
    ImageRegionOptimizer? optimizer,
    MultiPassOcrPipeline? pipeline,
    OcrCandidateEvaluator? candidateEvaluator,
    VietnameseOcrPostProcessor? postProcessor,
  })  : _recognizer = recognizer,
        _qualityAssessor = qualityAssessor ?? const ImageQualityAssessor(),
        _pipeline = pipeline ??
            MultiPassOcrPipeline(
              recognizer: recognizer,
              optimizer: optimizer ?? const ImageRegionOptimizer(),
            ),
        _candidateEvaluator = candidateEvaluator ?? const OcrCandidateEvaluator(),
        _postProcessor = postProcessor ?? const VietnameseOcrPostProcessor();

  dynamic _recognizer;
  final ImageQualityAssessor _qualityAssessor;
  final MultiPassOcrPipeline _pipeline;
  final OcrCandidateEvaluator _candidateEvaluator;
  final VietnameseOcrPostProcessor _postProcessor;
  bool _disposed = false;

  bool get isDisposed => _disposed;

  /// Initializes or replaces the native text recognizer instance.
  void setRecognizer(dynamic recognizer) {
    _recognizer = recognizer;
  }

  @override
  Future<OcrResult> recognizeFromFile(String filePath) async {
    final enhanced = await processEnhancedFromFile(filePath);
    return enhanced.baseResult;
  }

  @override
  Future<EnhancedOcrResult> processEnhancedFromFile(String filePath) async {
    if (_disposed) {
      const failure = OcrFailure('OCR Engine đã được giải phóng (disposed).');
      return const EnhancedOcrResult(
        baseResult: failure,
        rawText: '',
        qualityResult: ImageQualityResult(
          sharpnessScore: 0,
          meanLuminance: 0,
          width: 0,
          height: 0,
          issues: [],
        ),
      );
    }

    final file = File(filePath);
    if (!file.existsSync()) {
      const failure = OcrFailure('Tệp ảnh không tồn tại hoặc không thể đọc.');
      return const EnhancedOcrResult(
        baseResult: failure,
        rawText: '',
        qualityResult: ImageQualityResult(
          sharpnessScore: 0,
          meanLuminance: 0,
          width: 0,
          height: 0,
          issues: [ImageQualityIssue.lowResolution],
        ),
      );
    }

    // 1. Image Quality Assessment
    final qualityResult = await _qualityAssessor.assessFile(filePath);

    try {
      // 2. Multi-Pass OCR Execution (Pass A, Pass B, Pass C)
      final multiPassReport = await _pipeline.executePipeline(filePath);

      // 3. Candidate Evaluation & Conflict Detection
      final evaluated = _candidateEvaluator.evaluate(multiPassReport);

      // 4. Conservative Vietnamese Post-Processing (Unicode NFC & common labels)
      final postProcessed = _postProcessor.process(evaluated.selectedText);

      // Cleanup temp cropped/enhanced files safely
      _pipeline.cleanTemporaryFiles(multiPassReport);

      final OcrResult baseResult = evaluated.selectedText.trim().isEmpty
          ? const OcrEmpty()
          : OcrSuccess(evaluated.selectedText.trim());

      return EnhancedOcrResult.evaluate(
        baseResult: baseResult,
        rawText: evaluated.selectedText.trim(),
        qualityResult: qualityResult,
        averageConfidence: evaluated.selectedPass.averageConfidence,
        lineCount: evaluated.selectedPass.lines.length,
        blockCount: evaluated.selectedPass.lines.length,
        multiPassReport: multiPassReport,
        evaluatedResult: evaluated,
        postProcessedResult: postProcessed,
      );
    } on Exception catch (e) {
      final failure = OcrFailure('Lỗi nhận diện Google ML Kit: $e');
      return EnhancedOcrResult(
        baseResult: failure,
        rawText: '',
        qualityResult: qualityResult,
      );
    }
  }

  @override
  Future<OcrResult> recognizeFromInput(OcrInput input) async {
    if (_disposed) {
      return const OcrFailure('OCR Engine đã được giải phóng (disposed).');
    }

    if (_recognizer == null) {
      return const OcrFailure(
        'Google ML Kit recognizer chưa được nạp. N1 cần thêm google_mlkit_text_recognition vào pubspec.yaml.',
      );
    }

    try {
      // Dynamic invocation for InputImage.fromBytes with ML Kit
      final dynamic recognizedText = await _recognizer.processImage(input);
      final rawText = (recognizedText?.text as String?)?.trim() ?? '';
      if (rawText.isEmpty) {
        return const OcrEmpty();
      }
      return OcrSuccess(rawText);
    } on Exception catch (e) {
      return OcrFailure('Lỗi nhận diện buffer frame: $e');
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await _recognizer?.close();
    } catch (_) {}
  }
}
