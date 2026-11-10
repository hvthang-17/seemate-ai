import '../../../shared/assistance_contracts/ocr_contract.dart';
import 'image_quality_assessor.dart';
import 'multi_pass_report.dart';
import 'ocr_candidate_evaluator.dart';
import 'vietnamese_ocr_post_processor.dart';

/// Level of confidence / certainty in the extracted OCR text.
enum OcrCertainty {
  high,
  moderate,
  low,
  unknown,
}

/// Comprehensive, accessibility-safe OCR outcome.
///
/// Principles:
/// - Preserves 100% of the raw extracted text. Never invents missing words or alters sensitive figures.
/// - Calculates an aggregate certainty level factoring in image quality heuristics, ML Kit confidences, and multi-pass consistency.
/// - Identifies sensitive content (dosage, medical names, expiry dates, financial amounts) to enforce safe reading policies.
/// - Provides natural Vietnamese guidance for visually impaired users.
class EnhancedOcrResult {
  const EnhancedOcrResult({
    required this.baseResult,
    required this.rawText,
    required this.qualityResult,
    this.averageConfidence,
    this.lineCount = 0,
    this.blockCount = 0,
    this.certainty = OcrCertainty.unknown,
    this.overallConfidence = 0.85,
    this.requiresRecapture = false,
    this.feedbackPromptVi = '',
    this.totalLatencyMs = 0,
    this.containsSensitiveKeywords = false,
    this.detectedSensitiveCategories = const [],
    this.multiPassReport,
    this.evaluatedResult,
    this.postProcessedResult,
  });

  /// Base contract result (OcrSuccess, OcrEmpty, OcrFailure, OcrCancelled).
  final OcrResult baseResult;

  /// Verbatim extracted text from the selected candidate pass (never fabricated).
  final String rawText;

  /// Quality analysis of the source frame/image.
  final ImageQualityResult qualityResult;

  /// Average line confidence (0.0 - 1.0) if reported by the OCR engine; null if engine did not provide it.
  final double? averageConfidence;

  final int lineCount;
  final int blockCount;

  /// Categorized certainty level.
  final OcrCertainty certainty;

  /// Numerical composite confidence (0.0 - 1.0).
  final double overallConfidence;

  /// Whether recapture is strongly recommended.
  final bool requiresRecapture;

  /// Natural Vietnamese feedback prompt.
  final String feedbackPromptVi;

  /// Pipeline execution latency in milliseconds.
  final int totalLatencyMs;

  /// True if sensitive entities (medicine names, dosages, expiry dates, prices, phone numbers) were detected.
  final bool containsSensitiveKeywords;

  /// List of sensitive categories found (e.g. 'Thuốc/Y tế', 'Liều lượng', 'Hạn sử dụng/Ngày tháng', 'Giá tiền/Tài chính', 'Số điện thoại').
  final List<String> detectedSensitiveCategories;

  /// Multi-pass execution report containing all pass candidates.
  final MultiPassReport? multiPassReport;

  /// Candidate evaluation details including scores and conflicts.
  final EvaluatedOcrResult? evaluatedResult;

  /// Conservative Vietnamese post-processing outcome with normalized labels.
  final PostProcessedOcrResult? postProcessedResult;

  bool get isSuccess => baseResult is OcrSuccess && rawText.isNotEmpty;
  bool get isEmpty => baseResult is OcrEmpty || rawText.isEmpty;
  bool get isFailure => baseResult is OcrFailure;
  bool get isCancelled => baseResult is OcrCancelled;

  bool get hasConflictingCandidates =>
      evaluatedResult?.hasUnresolvedAmbiguity == true ||
      (evaluatedResult != null && evaluatedResult!.conflicts.isNotEmpty);

  /// Best text for display and TTS (normalized boilerplate labels, while preserving numbers and names).
  String get bestDisplayText =>
      postProcessedResult?.suggestedText.isNotEmpty == true
          ? postProcessedResult!.suggestedText
          : rawText;

  /// Legacy / compatibility alias for bestDisplayText.
  String get spokenText => bestDisplayText;

  bool get hasContent => bestDisplayText.trim().isNotEmpty;
  bool get hasSafetyWarnings =>
      postProcessedResult?.warnings.isNotEmpty == true || containsSensitiveKeywords;

  /// Determines whether the result should be read automatically or require explicit user confirmation.
  bool get requiresExplicitConfirmation {
    if (!isSuccess) return false;

    // Uncertain result or blurry image or conflicting candidate characters or sensitive medical content
    if (certainty == OcrCertainty.low) return true;
    if (qualityResult.isPotentiallyBlurry) return true;
    if (hasConflictingCandidates) return true;
    if (containsSensitiveKeywords) return true;

    return false;
  }

  /// Safety disclaimer in Vietnamese to warn visually impaired users about critical text.
  String? get safetyWarningVi {
    if (!isSuccess) return null;

    final warnings = <String>[];
    if (containsSensitiveKeywords) {
      warnings.add(
        'LƯU Ý AN TOÀN: Văn bản chứa thông tin về ${detectedSensitiveCategories.join(", ")}. '
        'Công nghệ nhận diện chỉ có tính chất tham khảo, vui lòng xác minh lại trước khi sử dụng.',
      );
    }

    if (hasConflictingCandidates) {
      warnings.add(
        'Phát hiện sự không đồng nhất giữa các lần quét ảnh. Một số chữ cái hoặc dấu có thể chưa chuẩn.',
      );
    } else if (certainty == OcrCertainty.low || qualityResult.isPotentiallyBlurry) {
      warnings.add(
        'Độ sắc nét hoặc độ tin cậy chưa cao, một số từ ngữ hoặc con số có thể bị nhận diện sai.',
      );
    }

    return warnings.isNotEmpty ? warnings.join('\n') : null;
  }

  /// Factory evaluator that computes certainty, sensitive content tags, and feedback prompts.
  static EnhancedOcrResult evaluate({
    required OcrResult baseResult,
    required String rawText,
    required ImageQualityResult qualityResult,
    double? averageConfidence,
    int lineCount = 0,
    int blockCount = 0,
    MultiPassReport? multiPassReport,
    EvaluatedOcrResult? evaluatedResult,
    PostProcessedOcrResult? postProcessedResult,
    VietnameseOcrPostProcessor postProcessor = const VietnameseOcrPostProcessor(),
    int totalLatencyMs = 0,
  }) {
    // 1. Determine effective text and post-process if not already supplied
    final effectiveRaw = evaluatedResult?.selectedText ?? rawText;
    final processed = postProcessedResult ?? postProcessor.process(effectiveRaw);

    final categories = <String>[];
    final lower = effectiveRaw.toLowerCase();

    // 1. Medicine and medical keywords
    final hasMedicine = RegExp(
      r'\b(thuốc|kháng sinh|viên nang|viên nén|siro|dung dịch|paracetamol|panadol|aspirin|amoxicillin|v-rohto|berberin|kháng khuẩn|uống|nhỏ mắt)\b',
      caseSensitive: false,
    ).hasMatch(lower);
    if (hasMedicine) categories.add('Thuốc/Y tế');

    // 2. Dosage indicators
    final hasDosage = RegExp(
      r'\d+\s*(mg|ml|gam|mcg|g|viên|ống|gói|giọt|lần|ngày)',
      caseSensitive: false,
    ).hasMatch(lower);
    if (hasDosage) categories.add('Liều lượng');

    // 3. Expiry and manufacturing dates
    final hasExpiry = RegExp(
      r'\b(hsd|nsx|exp|mfg|hạn dùng|ngày sx|lot|lô)\b|\d{1,2}[/-]\d{2,4}',
      caseSensitive: false,
    ).hasMatch(lower);
    if (hasExpiry) categories.add('Hạn sử dụng/Ngày tháng');

    // 4. Financial amounts
    final hasMoney = RegExp(
      r'\d{1,3}([.,]\d{3})+\s*(đ|vnd|vnđ|đồng)|\b(giá|tổng tiền)\b',
      caseSensitive: false,
    ).hasMatch(lower);
    if (hasMoney) categories.add('Giá tiền/Tài chính');

    // 5. Phone numbers
    final hasPhone = RegExp(r'\b(0|\+84)[3|5|7|8|9]\d{8}\b').hasMatch(effectiveRaw);
    if (hasPhone) categories.add('Số điện thoại');

    // 6. Compute certainty and composite confidence
    OcrCertainty certainty = OcrCertainty.moderate;
    double compConfidence = 0.85;

    if (baseResult is OcrEmpty || effectiveRaw.trim().isEmpty) {
      compConfidence = 0.0;
      certainty = OcrCertainty.unknown;
    } else if (baseResult is OcrFailure) {
      compConfidence = 0.0;
      certainty = OcrCertainty.low;
    } else {
      if (qualityResult.isPotentiallyBlurry || qualityResult.isTooDark) {
        certainty = OcrCertainty.low;
        compConfidence -= 0.30;
      } else if (evaluatedResult != null && evaluatedResult.hasUnresolvedAmbiguity) {
        certainty = OcrCertainty.low;
        compConfidence -= 0.20;
      } else if (averageConfidence != null) {
        if (averageConfidence >= 0.75) {
          certainty = OcrCertainty.high;
        } else if (averageConfidence < 0.50) {
          certainty = OcrCertainty.low;
          compConfidence -= 0.20;
        } else {
          certainty = OcrCertainty.moderate;
        }
      } else if (qualityResult.sharpnessScore >= 110.0 &&
          qualityResult.meanLuminance >= 50.0 &&
          qualityResult.meanLuminance <= 210.0) {
        certainty = OcrCertainty.high;
      }
    }
    compConfidence = compConfidence.clamp(0.0, 1.0);

    final requiresRecapture = baseResult is OcrFailure ||
        baseResult is OcrEmpty ||
        (qualityResult.hasBlur && effectiveRaw.trim().isEmpty);

    final prompt = _generateFeedbackPrompt(
      baseResult: baseResult,
      qualityResult: qualityResult,
      evaluatedResult: evaluatedResult,
      postProcessed: processed,
      confidence: compConfidence,
    );

    return EnhancedOcrResult(
      baseResult: baseResult,
      rawText: effectiveRaw,
      qualityResult: qualityResult,
      averageConfidence: averageConfidence,
      lineCount: lineCount > 0 ? lineCount : effectiveRaw.split('\n').where((l) => l.trim().isNotEmpty).length,
      blockCount: blockCount,
      certainty: certainty,
      overallConfidence: compConfidence,
      requiresRecapture: requiresRecapture,
      feedbackPromptVi: prompt,
      totalLatencyMs: totalLatencyMs,
      containsSensitiveKeywords: categories.isNotEmpty,
      detectedSensitiveCategories: categories,
      multiPassReport: multiPassReport,
      evaluatedResult: evaluatedResult,
      postProcessedResult: processed,
    );
  }

  static String _generateFeedbackPrompt({
    required OcrResult baseResult,
    required ImageQualityResult qualityResult,
    required EvaluatedOcrResult? evaluatedResult,
    required PostProcessedOcrResult postProcessed,
    required double confidence,
  }) {
    if (baseResult is OcrEmpty || postProcessed.suggestedText.trim().isEmpty) {
      if (qualityResult.hasBlur) {
        return 'Ảnh bị mờ. Hãy giữ chắc tay và chụp lại gần hơn.';
      }
      if (qualityResult.isTooDark) {
        return 'Ảnh quá tối. Hãy bật thêm đèn hoặc hướng camera về nơi sáng hơn.';
      }
      return 'Không phát hiện chữ in nào trong ảnh. Bạn có thể chụp lại gần hơn.';
    }

    if (qualityResult.hasBlur) {
      return 'Ảnh chưa đủ rõ. Hãy giữ điện thoại ổn định và thử lại.';
    }

    if (evaluatedResult?.hasUnresolvedAmbiguity == true) {
      return 'Một số chữ chưa được nhận diện chắc chắn. Bạn có thể nghe kết quả tạm thời hoặc quét lại.';
    }

    if (confidence < 0.60) {
      return 'Chữ đọc được có thể chưa hoàn toàn chính xác. Hãy chụp lại để kiểm tra nếu cần.';
    }

    return 'Đã nhận diện văn bản. Bắt đầu đọc.';
  }
}
