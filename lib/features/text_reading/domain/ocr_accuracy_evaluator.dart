import 'dart:math';

/// Accuracy metrics for an OCR recognition output compared to ground truth.
class OcrMetricReport {
  const OcrMetricReport({
    required this.candidateName,
    required this.groundTruth,
    required this.recognizedText,
    required this.characterErrorRate,
    required this.wordErrorRate,
    required this.charLevenshteinDistance,
    required this.wordLevenshteinDistance,
    required this.latencyMs,
  });

  final String candidateName;
  final String groundTruth;
  final String recognizedText;

  /// Character Error Rate (CER) = EditDistance(chars) / GroundTruthLength
  final double characterErrorRate;

  /// Word Error Rate (WER) = EditDistance(words) / GroundTruthWordCount
  final double wordErrorRate;

  final int charLevenshteinDistance;
  final int wordLevenshteinDistance;
  final int latencyMs;

  double get characterAccuracyPercent =>
      ((1.0 - characterErrorRate).clamp(0.0, 1.0)) * 100.0;

  double get wordAccuracyPercent =>
      ((1.0 - wordErrorRate).clamp(0.0, 1.0)) * 100.0;

  @override
  String toString() =>
      '[$candidateName] CER: ${(characterErrorRate * 100).toStringAsFixed(1)}% '
      '(Acc: ${characterAccuracyPercent.toStringAsFixed(1)}%), '
      'WER: ${(wordErrorRate * 100).toStringAsFixed(1)}%, Latency: ${latencyMs}ms';
}

/// Comparative evaluation report between Baseline (Pass A) and Multi-Pass Pipeline.
class PipelineComparisonReport {
  const PipelineComparisonReport({
    required this.baseline,
    required this.optimized,
    required this.cerImprovementPercent,
    required this.werImprovementPercent,
  });

  final OcrMetricReport baseline;
  final OcrMetricReport optimized;

  /// Reduction in Character Error Rate (positive means improvement).
  final double cerImprovementPercent;

  /// Reduction in Word Error Rate (positive means improvement).
  final double werImprovementPercent;

  @override
  String toString() =>
      'So sánh Pipeline:\n'
      '- Baseline: CER ${(baseline.characterErrorRate * 100).toStringAsFixed(1)}%\n'
      '- Cải tiến: CER ${(optimized.characterErrorRate * 100).toStringAsFixed(1)}%\n'
      '- Mức cải thiện CER: ${cerImprovementPercent.toStringAsFixed(1)}%\n'
      '- Mức cải thiện WER: ${werImprovementPercent.toStringAsFixed(1)}%';
}

/// Evaluator computing standard Character Error Rate (CER) and Word Error Rate (WER)
/// using Levenshtein edit distance algorithms.
final class OcrAccuracyEvaluator {
  const OcrAccuracyEvaluator();

  /// Evaluates recognized text against human-verified ground-truth text.
  OcrMetricReport evaluateCandidate({
    required String candidateName,
    required String groundTruth,
    required String recognizedText,
    int latencyMs = 0,
  }) =>
      evaluate(
        candidateName: candidateName,
        groundTruth: groundTruth,
        recognizedText: recognizedText,
        latencyMs: latencyMs,
      );

  OcrMetricReport evaluate({
    required String candidateName,
    required String groundTruth,
    required String recognizedText,
    int latencyMs = 0,
  }) {
    final cleanGt = groundTruth.trim();
    final cleanRec = recognizedText.trim();

    if (cleanGt.isEmpty) {
      return OcrMetricReport(
        candidateName: candidateName,
        groundTruth: groundTruth,
        recognizedText: recognizedText,
        characterErrorRate: cleanRec.isEmpty ? 0.0 : 1.0,
        wordErrorRate: cleanRec.isEmpty ? 0.0 : 1.0,
        charLevenshteinDistance: cleanRec.length,
        wordLevenshteinDistance: cleanRec.split(RegExp(r'\s+')).length,
        latencyMs: latencyMs,
      );
    }

    // 1. Character Error Rate (CER)
    final charDist = computeLevenshteinDistance(cleanGt, cleanRec);
    final cer = charDist / cleanGt.length;

    // 2. Word Error Rate (WER)
    final gtWords = cleanGt.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final recWords = cleanRec.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final wordDist = computeWordLevenshteinDistance(gtWords, recWords);
    final wer = gtWords.isNotEmpty ? wordDist / gtWords.length : (recWords.isEmpty ? 0.0 : 1.0);

    return OcrMetricReport(
      candidateName: candidateName,
      groundTruth: groundTruth,
      recognizedText: recognizedText,
      characterErrorRate: cer,
      wordErrorRate: wer,
      charLevenshteinDistance: charDist,
      wordLevenshteinDistance: wordDist,
      latencyMs: latencyMs,
    );
  }

  /// Compares baseline Pass A against the multi-pass post-processed result.
  PipelineComparisonReport compare({
    required String groundTruth,
    required String baselineText,
    required int baselineLatencyMs,
    required String optimizedText,
    required int optimizedLatencyMs,
  }) {
    final baselineReport = evaluate(
      candidateName: 'Baseline (Pass A)',
      groundTruth: groundTruth,
      recognizedText: baselineText,
      latencyMs: baselineLatencyMs,
    );

    final optimizedReport = evaluate(
      candidateName: 'Optimized Multi-Pass',
      groundTruth: groundTruth,
      recognizedText: optimizedText,
      latencyMs: optimizedLatencyMs,
    );

    final cerDiff = (baselineReport.characterErrorRate - optimizedReport.characterErrorRate) * 100.0;
    final werDiff = (baselineReport.wordErrorRate - optimizedReport.wordErrorRate) * 100.0;

    return PipelineComparisonReport(
      baseline: baselineReport,
      optimized: optimizedReport,
      cerImprovementPercent: cerDiff,
      werImprovementPercent: werDiff,
    );
  }

  /// Computes Levenshtein edit distance between two character strings.
  static int computeLevenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final len1 = s1.length;
    final len2 = s2.length;

    List<int> prev = List<int>.generate(len2 + 1, (i) => i);
    List<int> curr = List<int>.filled(len2 + 1, 0);

    for (int i = 0; i < len1; i++) {
      curr[0] = i + 1;
      for (int j = 0; j < len2; j++) {
        final cost = s1[i] == s2[j] ? 0 : 1;
        curr[j + 1] = min(
          curr[j] + 1,
          min(
            prev[j + 1] + 1,
            prev[j] + cost,
          ),
        );
      }
      final temp = prev;
      prev = curr;
      curr = temp;
    }

    return prev[len2];
  }

  /// Computes Levenshtein edit distance between two word sequences.
  static int computeWordLevenshteinDistance(List<String> w1, List<String> w2) {
    if (w1.isEmpty) return w2.length;
    if (w2.isEmpty) return w1.length;

    final len1 = w1.length;
    final len2 = w2.length;

    List<int> prev = List<int>.generate(len2 + 1, (i) => i);
    List<int> curr = List<int>.filled(len2 + 1, 0);

    for (int i = 0; i < len1; i++) {
      curr[0] = i + 1;
      for (int j = 0; j < len2; j++) {
        final cost = w1[i] == w2[j] ? 0 : 1;
        curr[j + 1] = min(
          curr[j] + 1,
          min(
            prev[j + 1] + 1,
            prev[j] + cost,
          ),
        );
      }
      final temp = prev;
      prev = curr;
      curr = temp;
    }

    return prev[len2];
  }
}
