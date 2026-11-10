import 'dart:ui';

/// Output of a single OCR execution pass.
class OcrPassResult {
  const OcrPassResult({
    required this.passName,
    required this.imagePath,
    required this.rawText,
    required this.lines,
    required this.boundingBoxes,
    required this.lineConfidences,
    required this.latencyMs,
  });

  final String passName;
  final String imagePath;
  final String rawText;
  final List<String> lines;
  final List<Rect> boundingBoxes;
  final List<double?> lineConfidences;
  final int latencyMs;

  bool get isEmpty => rawText.trim().isEmpty;

  double? get averageConfidence {
    final valid = lineConfidences
        .where((c) => c != null && !c.isNaN && c > 0.0)
        .map((c) => c!)
        .toList();
    if (valid.isEmpty) return null;
    return valid.reduce((a, b) => a + b) / valid.length;
  }

  @override
  String toString() =>
      '[$passName] $latencyMs ms, ${lines.length} lines, '
      'avgConf: ${averageConfidence != null ? (averageConfidence! * 100).toStringAsFixed(1) : "N/A"}%';
}

/// Aggregated report holding all candidates from the multi-pass OCR pipeline.
class MultiPassReport {
  const MultiPassReport({
    required this.passes,
    required this.totalLatencyMs,
    this.croppedImagePath,
    this.enhancedImagePath,
  });

  final List<OcrPassResult> passes;
  final int totalLatencyMs;
  final String? croppedImagePath;
  final String? enhancedImagePath;

  OcrPassResult get passA => passes.first;
  OcrPassResult? get passB => passes.length > 1 ? passes[1] : null;
  OcrPassResult? get passC => passes.length > 2 ? passes[2] : null;
}
