import 'dart:async';
import 'dart:ui';

import 'package:flutter_agentic_starter/core/speech/fake_tts_engine.dart';
import 'package:flutter_agentic_starter/core/speech/speech_coordinator.dart';
import 'package:flutter_agentic_starter/features/text_reading/domain/accessible_ocr_announcer.dart';
import 'package:flutter_agentic_starter/features/text_reading/domain/enhanced_ocr_result.dart';
import 'package:flutter_agentic_starter/features/text_reading/domain/image_quality_assessor.dart';
import 'package:flutter_agentic_starter/features/text_reading/domain/image_region_optimizer.dart';
import 'package:flutter_agentic_starter/features/text_reading/domain/multi_pass_report.dart';
import 'package:flutter_agentic_starter/features/text_reading/domain/ocr_accuracy_evaluator.dart';
import 'package:flutter_agentic_starter/features/text_reading/domain/ocr_candidate_evaluator.dart';
import 'package:flutter_agentic_starter/features/text_reading/domain/vietnamese_ocr_post_processor.dart';
import 'package:flutter_agentic_starter/shared/assistance_contracts/ocr_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 1: ImageRegionOptimizer', () {
    const optimizer = ImageRegionOptimizer();

    test('computeTextRegionUnion combines multiple boxes with padding', () {
      final boxes = [
        const Rect.fromLTWH(100, 100, 200, 50),
        const Rect.fromLTWH(120, 200, 250, 60),
      ];

      final union = optimizer.computeTextRegionUnion(boxes, 1000, 1000, paddingPercent: 0.1);
      expect(union, isNotNull);

      // Union without padding: L=100, T=100, R=370, B=260. Width=270, Height=160
      // PadX = 270 * 0.1 = 27, PadY = 160 * 0.1 = 16
      expect(union!.left, equals(73.0));
      expect(union.top, equals(84.0));
      expect(union.right, equals(397.0));
      expect(union.bottom, equals(276.0));
    });

    test('computeTextRegionUnion clamps safely to image bounds', () {
      final boxes = [
        const Rect.fromLTWH(5, 5, 490, 490),
      ];

      final union = optimizer.computeTextRegionUnion(boxes, 500, 500, paddingPercent: 0.2);
      expect(union, isNotNull);
      expect(union!.left, greaterThanOrEqualTo(0.0));
      expect(union.top, greaterThanOrEqualTo(0.0));
      expect(union.right, lessThanOrEqualTo(500.0));
      expect(union.bottom, lessThanOrEqualTo(500.0));
    });

    test('computeTextRegionUnion returns null on empty input', () {
      expect(optimizer.computeTextRegionUnion([], 1000, 1000), isNull);
      expect(optimizer.computeTextRegionUnion([const Rect.fromLTWH(0, 0, 10, 10)], 0, 0), isNull);
    });

    test('sortBoxesReadingOrder sorts top-to-bottom and left-to-right', () {
      final boxes = [
        const Rect.fromLTWH(200, 300, 50, 20), // Bottom line
        const Rect.fromLTWH(200, 50, 50, 20),  // Top line right
        const Rect.fromLTWH(50, 50, 50, 20),   // Top line left
      ];

      final sorted = optimizer.sortBoxesReadingOrder(boxes);
      expect(sorted[0].left, equals(50.0));
      expect(sorted[0].top, equals(50.0));
      expect(sorted[1].left, equals(200.0));
      expect(sorted[1].top, equals(50.0));
      expect(sorted[2].top, equals(300.0));
    });

    test('createEnhancedCrop creates cropped image with valid dimensions', () {
      final source = (width: 400, height: 400);
      final cropped = optimizer.createEnhancedCrop(
        source,
        const Rect.fromLTWH(50, 50, 100, 100),
        invert: false,
      );

      expect(cropped.width, equals(100));
      expect(cropped.height, equals(100));
    });
  });

  group('Phase 2 & 3: MultiPass and Candidate Evaluator', () {
    const evaluator = OcrCandidateEvaluator();

    test('computes composite score favoring Vietnamese diacritics and confidence', () {
      const passWithoutDau = OcrPassResult(
        passName: 'Pass A (Gốc)',
        imagePath: '/path/a.jpg',
        rawText: 'San pham cua Cong ty co phan',
        lines: ['San pham cua', 'Cong ty co phan'],
        boundingBoxes: [],
        lineConfidences: [0.7, 0.7],
        latencyMs: 150,
      );

      const passWithDau = OcrPassResult(
        passName: 'Pass B (Cắt vùng)',
        imagePath: '/path/b.jpg',
        rawText: 'Sản phẩm của Công ty cổ phần',
        lines: ['Sản phẩm của', 'Công ty cổ phần'],
        boundingBoxes: [],
        lineConfidences: [0.85, 0.9],
        latencyMs: 180,
      );

      final scoreWithoutDau = evaluator.computeCompositeScore(passWithoutDau);
      final scoreWithDau = evaluator.computeCompositeScore(passWithDau);

      expect(scoreWithDau, greaterThan(scoreWithoutDau));
    });

    test('detects conflicts between pass lines', () {
      const passA = OcrPassResult(
        passName: 'Pass A',
        imagePath: '/path/a.jpg',
        rawText: 'Sàn phêm cùa',
        lines: ['Sàn phêm cùa'],
        boundingBoxes: [],
        lineConfidences: [0.6],
        latencyMs: 100,
      );

      const passB = OcrPassResult(
        passName: 'Pass B',
        imagePath: '/path/b.jpg',
        rawText: 'Sản phẩm của',
        lines: ['Sản phẩm của'],
        boundingBoxes: [],
        lineConfidences: [0.9],
        latencyMs: 120,
      );

      final report = MultiPassReport(
        passes: [passA, passB],
        totalLatencyMs: 220,
      );

      final evaluated = evaluator.evaluate(report);
      expect(evaluated.conflicts.isNotEmpty, isTrue);
      expect(evaluated.selectedPass.passName, equals('Pass B'));
      expect(evaluated.selectedText, equals('Sản phẩm của'));
    });

    test('flags unresolved ambiguity when scores are close and conflicting', () {
      const passA = OcrPassResult(
        passName: 'Pass A',
        imagePath: '/path/a.jpg',
        rawText: 'Ba số 5',
        lines: ['Ba số 5'],
        boundingBoxes: [],
        lineConfidences: [0.75],
        latencyMs: 100,
      );

      const passB = OcrPassResult(
        passName: 'Pass B',
        imagePath: '/path/b.jpg',
        rawText: 'Ba số 6',
        lines: ['Ba số 6'],
        boundingBoxes: [],
        lineConfidences: [0.76],
        latencyMs: 100,
      );

      final report = MultiPassReport(
        passes: [passA, passB],
        totalLatencyMs: 200,
      );

      final evaluated = evaluator.evaluate(report);
      expect(evaluated.hasUnresolvedAmbiguity, isTrue);
    });
  });

  group('Phase 4: Conservative Vietnamese Post-Processor', () {
    const postProcessor = VietnameseOcrPostProcessor();

    test('normalizes Unicode combining characters into precomposed NFC', () {
      const decomposed = 'Viê\u0323t Nam'; // e + combining underdot
      final result = postProcessor.process(decomposed);
      expect(result.suggestedText.contains('Việt Nam'), isTrue);
    });

    test('corrects packaging boilerplate label "Sàn phêm cùa" -> "Sản phẩm của"', () {
      const raw = 'Sàn phêm cùa Công ty Dược';
      final result = postProcessor.process(raw);

      expect(result.suggestedText, contains('Sản phẩm của'));
      expect(result.hasModifications, isTrue);
      expect(result.corrections.any((c) => c.correctedSnippet == 'Sản phẩm của'), isTrue);
      expect(result.rawText, equals(raw));
    });

    test('corrects packaging label "cÒNG TY CỔ PHẨN" -> "CÔNG TY CỔ PHẦN"', () {
      const raw = 'cÒNG TY CỔ PHẨN ACECOOK VIỆT NAM';
      final result = postProcessor.process(raw);

      expect(result.suggestedText, contains('CÔNG TY CỔ PHẦN'));
      expect(result.corrections.any((c) => c.correctedSnippet == 'CÔNG TY CỔ PHẦN'), isTrue);
    });

    test('corrects address label "Dịa chi:" -> "Địa chỉ:"', () {
      const raw = 'Dịa chi: Lô II-3 Đường số 11';
      final result = postProcessor.process(raw);

      expect(result.suggestedText, contains('Địa chỉ:'));
    });

    test('CRITICAL SAFETY: strictly preserves medicine names, dosages, prices and dates', () {
      const sensitiveText =
          'Paracetamol 500mg - Uống 2 viên sau ăn. HSD: 25/12/2026. Giá: 45.000đ. ĐT: 0903123456';
      final result = postProcessor.process(sensitiveText);

      expect(result.suggestedText, contains('Paracetamol 500mg'));
      expect(result.suggestedText, contains('2 viên'));
      expect(result.suggestedText, contains('25/12/2026'));
      expect(result.suggestedText, contains('45.000đ'));
      expect(result.suggestedText, contains('0903123456'));

      expect(result.warnings.isNotEmpty, isTrue);
      expect(result.warnings.any((w) => w.contains('Thuốc/Liều lượng')), isTrue);
      expect(result.warnings.any((w) => w.contains('Hạn sử dụng/Ngày tháng')), isTrue);
      expect(result.warnings.any((w) => w.contains('Số tiền/Giá cả')), isTrue);
      expect(result.warnings.any((w) => w.contains('Số điện thoại')), isTrue);
    });

    test('never invents or hallucinates missing words on noisy text', () {
      const noisyText = 'XYZ 123 !@# abc';
      final result = postProcessor.process(noisyText);

      expect(result.suggestedText, equals(noisyText));
      expect(result.corrections, isEmpty);
    });
  });

  group('Phase 5: Accessible OCR Announcer', () {
    late FakeTtsEngine fakeTts;
    late SpeechCoordinator coordinator;
    late AccessibleOcrAnnouncer announcer;

    setUp(() {
      fakeTts = FakeTtsEngine();
      coordinator = SpeechCoordinator(engine: fakeTts);
      coordinator.initialize();
      announcer = AccessibleOcrAnnouncer(speechCoordinator: coordinator);
    });

    tearDown(() async {
      await coordinator.dispose();
      await fakeTts.dispose();
    });

    test('announces clear readable text outcome', () async {
      final result = EnhancedOcrResult.evaluate(
        baseResult: const OcrSuccess('Sản phẩm của Công ty'),
        rawText: 'Sản phẩm của Công ty',
        qualityResult: const ImageQualityResult(
          sharpnessScore: 100,
          meanLuminance: 120,
          width: 1920,
          height: 1080,
          issues: [],
        ),
      );

      await announcer.announceOcrOutcome(result);
      expect(fakeTts.spokenTexts.last, equals('Đã nhận diện văn bản. Bắt đầu đọc.'));
    });

    test('announces warning prompt for potentially blurry image', () async {
      final result = EnhancedOcrResult.evaluate(
        baseResult: const OcrSuccess('Chữ bị mờ'),
        rawText: 'Chữ bị mờ',
        qualityResult: const ImageQualityResult(
          sharpnessScore: 10,
          meanLuminance: 120,
          width: 1920,
          height: 1080,
          issues: [ImageQualityIssue.blurry],
        ),
      );

      await announcer.announceOcrOutcome(result);
      expect(
        fakeTts.spokenTexts.last,
        equals('Ảnh chưa đủ rõ. Hãy giữ điện thoại ổn định và thử lại.'),
      );
    });

    test('announces warning prompt for conflicting OCR passes', () async {
      const passA = OcrPassResult(
        passName: 'Pass A',
        imagePath: '/path/a.jpg',
        rawText: 'Dòng 1 sai',
        lines: ['Dòng 1 sai'],
        boundingBoxes: [],
        lineConfidences: [0.5],
        latencyMs: 100,
      );
      const passB = OcrPassResult(
        passName: 'Pass B',
        imagePath: '/path/b.jpg',
        rawText: 'Dòng 1 đúng',
        lines: ['Dòng 1 đúng'],
        boundingBoxes: [],
        lineConfidences: [0.55],
        latencyMs: 100,
      );

      const evaluated = EvaluatedOcrResult(
        selectedPass: passB,
        allPasses: [passA, passB],
        candidateScores: {'Pass A': 0.5, 'Pass B': 0.55},
        conflicts: [
          OcrConflict(
            lineIndex: 0,
            passAText: 'Dòng 1 sai',
            candidateText: 'Dòng 1 đúng',
            explanation: 'Khác biệt văn bản',
          ),
        ],
        hasUnresolvedAmbiguity: true,
        selectedText: 'Dòng 1 đúng',
        rawPassAText: 'Dòng 1 sai',
      );

      final result = EnhancedOcrResult.evaluate(
        baseResult: const OcrSuccess('Dòng 1 đúng'),
        rawText: 'Dòng 1 đúng',
        qualityResult: const ImageQualityResult(
          sharpnessScore: 100,
          meanLuminance: 120,
          width: 1920,
          height: 1080,
          issues: [],
        ),
        evaluatedResult: evaluated,
      );

      await announcer.announceOcrOutcome(result);
      expect(
        fakeTts.spokenTexts.last,
        equals('Một số chữ chưa được nhận diện chắc chắn. Bạn có thể nghe kết quả tạm thời hoặc quét lại.'),
      );
    });

    test('announces guidance for empty image', () async {
      final result = EnhancedOcrResult.evaluate(
        baseResult: const OcrEmpty(),
        rawText: '',
        qualityResult: const ImageQualityResult(
          sharpnessScore: 100,
          meanLuminance: 120,
          width: 1920,
          height: 1080,
          issues: [],
        ),
      );

      await announcer.announceOcrOutcome(result);
      expect(
        fakeTts.spokenTexts.last,
        equals('Không phát hiện chữ in nào trong ảnh. Bạn có thể chụp lại gần hơn.'),
      );
    });

    test('suppresses rapid duplicate announcements within cooldown period', () async {
      await announcer.announceMessage('Thông báo thử nghiệm');
      expect(fakeTts.spokenTexts.length, equals(1));

      // Attempt duplicate immediately
      await announcer.announceMessage('Thông báo thử nghiệm');
      expect(fakeTts.spokenTexts.length, equals(1)); // Suppressed
    });
  });

  group('Phase 6: OcrAccuracyEvaluator (CER and WER)', () {
    const evaluator = OcrAccuracyEvaluator();

    test('calculates exact CER and WER with Levenshtein distance', () {
      const groundTruth = 'Sản phẩm của Công ty Cổ phần Acecook';
      const recognized = 'Sàn phêm cùa CÒNG TY CỔ PHẨN Acecook';

      final report = evaluator.evaluateCandidate(
        candidateName: 'Test Pass',
        groundTruth: groundTruth,
        recognizedText: recognized,
        latencyMs: 120,
      );

      expect(report.charLevenshteinDistance, greaterThan(0));
      expect(report.wordLevenshteinDistance, greaterThan(0));
      expect(report.characterErrorRate, greaterThan(0.0));
      expect(report.wordErrorRate, greaterThan(0.0));
      expect(report.characterAccuracyPercent, lessThan(100.0));
    });

    test('reports 0% CER and 100% accuracy for identical strings', () {
      const text = 'Thuốc nhỏ mắt kháng khuẩn';
      final report = evaluator.evaluateCandidate(
        candidateName: 'Perfect Pass',
        groundTruth: text,
        recognizedText: text,
        latencyMs: 90,
      );

      expect(report.charLevenshteinDistance, equals(0));
      expect(report.wordLevenshteinDistance, equals(0));
      expect(report.characterErrorRate, equals(0.0));
      expect(report.wordErrorRate, equals(0.0));
      expect(report.characterAccuracyPercent, equals(100.0));
      expect(report.wordAccuracyPercent, equals(100.0));
    });

    test('compares baseline and optimized pipeline showing quantifiable reduction in CER', () {
      const groundTruth = 'Sản phẩm của Công ty Cổ phần';
      const baseline = 'Sàn phêm cùa cÒNG TY CỔ PHẨN';
      const optimized = 'Sản phẩm của CÔNG TY CỔ PHẦN';

      final comparison = evaluator.compare(
        groundTruth: groundTruth,
        baselineText: baseline,
        optimizedText: optimized,
        baselineLatencyMs: 150,
        optimizedLatencyMs: 320,
      );

      expect(comparison.cerImprovementPercent, greaterThan(0.0));
      expect(comparison.werImprovementPercent, greaterThan(0.0));
      expect(comparison.optimized.characterAccuracyPercent, greaterThan(comparison.baseline.characterAccuracyPercent));
    });
  });
}
