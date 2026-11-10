import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'image_region_optimizer.dart';
import 'multi_pass_report.dart';

/// Adapter function to execute a recognition pass on an image path.
typedef SinglePassRecognizer = Future<OcrPassResult> Function(
  String passName,
  String imagePath,
);

/// Executes up to 3 OCR passes to optimize text extraction on difficult packaging:
/// - Pass A: Original full-resolution image.
/// - Pass B: Cropped text region (isolates text from cluttered backgrounds).
/// - Pass C: Carefully enhanced region (contrast normalized + mild denoising).
final class MultiPassOcrPipeline {
  MultiPassOcrPipeline({
    dynamic recognizer,
    ImageRegionOptimizer? optimizer,
    SinglePassRecognizer? customRecognizer,
  })  : _recognizer = recognizer,
        _optimizer = optimizer ?? const ImageRegionOptimizer(),
        _customRecognizer = customRecognizer;

  final dynamic _recognizer;
  final ImageRegionOptimizer _optimizer;
  final SinglePassRecognizer? _customRecognizer;

  /// Runs the multi-pass pipeline.
  Future<MultiPassReport> executePipeline(String sourcePath) async {
    final totalStopwatch = Stopwatch()..start();
    final passes = <OcrPassResult>[];

    // 1. Prepare oriented full-resolution image
    final orientedPath = await _optimizer.prepareOrientedImage(sourcePath);

    // ---- PASS A: Original Full-Resolution Image ----
    final passA = await _runSinglePass(
      passName: 'Pass A: Ảnh gốc',
      imagePath: orientedPath,
    );
    passes.add(passA);

    String? croppedPath;
    String? enhancedPath;

    // If Pass A found no text at all, we try enhancing the full image
    if (passA.isEmpty) {
      enhancedPath = await _optimizer.createEnhancedImage(orientedPath);
      if (enhancedPath != null) {
        final passC = await _runSinglePass(
          passName: 'Pass C: Nâng cao độ tương phản',
          imagePath: enhancedPath,
        );
        passes.add(passC);
      }
      totalStopwatch.stop();
      return MultiPassReport(
        passes: passes,
        totalLatencyMs: totalStopwatch.elapsedMilliseconds,
        enhancedImagePath: enhancedPath,
      );
    }

    // ---- PASS B: Cropped Text Region ----
    // Calculate bounding box union of detected text blocks
    final unionRect = _optimizer.computeTextRegionUnion(
      passA.boundingBoxes,
      4000, // Safe bounds checked inside cropTextRegion
      4000,
      paddingPercent: 0.10, // 10% safety margin
    );

    if (unionRect != null) {
      croppedPath = await _optimizer.cropTextRegion(
        orientedPath,
        unionRect,
        filePrefix: 'pass_b_crop',
      );

      if (croppedPath != null) {
        final passB = await _runSinglePass(
          passName: 'Pass B: Vùng chữ biệt lập',
          imagePath: croppedPath,
        );
        passes.add(passB);
      }
    }

    // ---- PASS C: Enhanced Text Region ----
    final targetForEnhancement = croppedPath ?? orientedPath;
    enhancedPath = await _optimizer.createEnhancedImage(
      targetForEnhancement,
      enableInversionCheck: true,
    );

    if (enhancedPath != null) {
      final passC = await _runSinglePass(
        passName: 'Pass C: Nâng cao độ nét & tương phản',
        imagePath: enhancedPath,
      );
      passes.add(passC);
    }

    totalStopwatch.stop();
    return MultiPassReport(
      passes: passes,
      totalLatencyMs: totalStopwatch.elapsedMilliseconds,
      croppedImagePath: croppedPath,
      enhancedImagePath: enhancedPath,
    );
  }

  Future<OcrPassResult> _runSinglePass({
    required String passName,
    required String imagePath,
  }) async {
    if (_customRecognizer != null) {
      return _customRecognizer!(passName, imagePath);
    }

    if (_recognizer == null) {
      return OcrPassResult(
        passName: passName,
        imagePath: imagePath,
        rawText: '',
        lines: [],
        boundingBoxes: [],
        lineConfidences: [],
        latencyMs: 0,
      );
    }

    final sw = Stopwatch()..start();
    try {
      // Dynamic invocation for google_mlkit_text_recognition TextRecognizer
      // Expects: _recognizer.processImage(InputImage.fromFilePath(imagePath))
      // or custom duck-typed recognizer
      final dynamic inputImage = _recognizer.createInputImage != null
          ? _recognizer.createInputImage(imagePath)
          : imagePath;

      final dynamic recognized = await _recognizer.processImage(inputImage);
      sw.stop();

      final lines = <String>[];
      final boxes = <Rect>[];
      final confidences = <double?>[];

      if (recognized.blocks != null) {
        final sortedBlocks = _optimizer.sortBlocksInReadingOrder(
          List<dynamic>.from(recognized.blocks as Iterable),
        );

        for (final block in sortedBlocks) {
          if ((block as dynamic).lines != null) {
            for (final line in (block.lines as Iterable)) {
              final text = ((line as dynamic).text as String?)?.trim() ?? '';
              if (text.isNotEmpty) {
                lines.add(text);
                if (line.boundingBox != null) {
                  boxes.add(line.boundingBox as Rect);
                }
                confidences.add((line as dynamic).confidence as double?);
              }
            }
          }
        }
      } else if (recognized.text != null) {
        final text = (recognized.text as String).trim();
        if (text.isNotEmpty) {
          lines.addAll(text.split('\n').where((l) => l.trim().isNotEmpty));
        }
      }

      final rawText = lines.join('\n');

      return OcrPassResult(
        passName: passName,
        imagePath: imagePath,
        rawText: rawText,
        lines: lines,
        boundingBoxes: boxes,
        lineConfidences: confidences,
        latencyMs: sw.elapsedMilliseconds,
      );
    } catch (_) {
      sw.stop();
      return OcrPassResult(
        passName: passName,
        imagePath: imagePath,
        rawText: '',
        lines: [],
        boundingBoxes: [],
        lineConfidences: [],
        latencyMs: sw.elapsedMilliseconds,
      );
    }
  }

  void cleanTemporaryFiles(MultiPassReport report) {
    if (report.croppedImagePath != null) {
      final f = File(report.croppedImagePath!);
      if (f.existsSync()) {
        try {
          f.deleteSync();
        } on Exception {/* ignore */}
      }
    }
    if (report.enhancedImagePath != null) {
      final f = File(report.enhancedImagePath!);
      if (f.existsSync()) {
        try {
          f.deleteSync();
        } on Exception {/* ignore */}
      }
    }
  }
}
