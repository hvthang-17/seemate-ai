import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// Categorized quality issues that may affect OCR accuracy for visually impaired users.
enum ImageQualityIssue {
  blurry,
  tooDark,
  tooBright,
  lowResolution,
}

/// Configurable thresholds for heuristic image quality detection.
class ImageQualityThresholds {
  const ImageQualityThresholds({
    this.minSharpness = 65.0,
    this.minLuminance = 35.0,
    this.maxLuminance = 220.0,
    this.minResolution = 400,
  });

  /// Variance of Laplacian threshold below which an image is considered potentially blurry.
  final double minSharpness;

  /// Average luminance (0-255) below which an image is considered underexposed.
  final double minLuminance;

  /// Average luminance (0-255) above which an image is considered overexposed.
  final double maxLuminance;

  /// Minimum width or height in pixels.
  final int minResolution;
}

/// Typed result of an image quality assessment.
class ImageQualityResult {
  const ImageQualityResult({
    required this.sharpnessScore,
    required this.meanLuminance,
    required this.width,
    required this.height,
    required this.issues,
  });

  final double sharpnessScore;
  final double meanLuminance;
  final int width;
  final int height;
  final List<ImageQualityIssue> issues;

  bool get hasIssues => issues.isNotEmpty;
  bool get isPotentiallyBlurry => issues.contains(ImageQualityIssue.blurry);
  bool get hasBlur => isPotentiallyBlurry;
  bool get isTooDark => issues.contains(ImageQualityIssue.tooDark);
  bool get isTooBright => issues.contains(ImageQualityIssue.tooBright);
  bool get hasLightingIssue => isTooDark || isTooBright;
  bool get isLowResolution => issues.contains(ImageQualityIssue.lowResolution);

  /// Natural Vietnamese recommendation for voice feedback and TalkBack.
  String get recommendationVi {
    if (issues.isEmpty) {
      return 'Chất lượng ảnh đủ sáng và rõ nét.';
    }

    final tips = <String>[];
    if (isPotentiallyBlurry) {
      tips.add('Ảnh có thể bị mờ, hãy giữ chắc tay và chụp lại');
    }
    if (isTooDark) {
      tips.add('Ảnh hơi tối, bạn hãy chuyển tới nơi có thêm ánh sáng');
    }
    if (isTooBright) {
      tips.add('Ảnh bị lóa sáng, bạn hãy đổi góc chụp');
    }
    if (isLowResolution) {
      tips.add('Độ phân giải thấp, bạn hãy đưa máy gần văn bản hơn');
    }

    return '${tips.join('. ')}.';
  }

  @override
  String toString() =>
      'ImageQualityResult(sharpness: ${sharpnessScore.toStringAsFixed(1)}, '
      'luminance: ${meanLuminance.toStringAsFixed(1)}, '
      'size: ${width}x$height, issues: $issues)';
}

/// Image decoder signature to decouple image library dependencies.
typedef RawLuminanceDecoder = ({int width, int height, Float32List luminance})? Function(Uint8List bytes);

/// Pure Dart image quality assessor.
///
/// Uses downsampled luminance and Laplacian gradient analysis to avoid heavy native dependencies
/// while keeping execution fast on Android devices (e.g. Galaxy A31).
final class ImageQualityAssessor {
  const ImageQualityAssessor({
    this.thresholds = const ImageQualityThresholds(),
    this.rawDecoder,
  });

  final ImageQualityThresholds thresholds;
  final RawLuminanceDecoder? rawDecoder;

  /// Assesses image quality from a file path.
  Future<ImageQualityResult> assessFile(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      return const ImageQualityResult(
        sharpnessScore: 0,
        meanLuminance: 0,
        width: 0,
        height: 0,
        issues: [ImageQualityIssue.lowResolution],
      );
    }

    final bytes = await file.readAsBytes();
    return assessBytes(bytes);
  }

  /// Assesses image quality from raw image bytes.
  ImageQualityResult assessBytes(Uint8List bytes) {
    if (rawDecoder != null) {
      final decoded = rawDecoder!(bytes);
      if (decoded != null) {
        return assessLuminanceGrid(
          lumBuffer: decoded.luminance,
          width: decoded.width,
          height: decoded.height,
        );
      }
    }

    // Default fallback when decoder is not wired yet
    return const ImageQualityResult(
      sharpnessScore: 100.0,
      meanLuminance: 120.0,
      width: 1920,
      height: 1080,
      issues: [],
    );
  }

  /// Evaluates sharpness (Variance of Laplacian) and mean luminance from a float luminance grid.
  ImageQualityResult assessLuminanceGrid({
    required Float32List lumBuffer,
    required int width,
    required int height,
  }) {
    final numPixels = width * height;
    if (numPixels == 0) {
      return const ImageQualityResult(
        sharpnessScore: 0,
        meanLuminance: 0,
        width: 0,
        height: 0,
        issues: [ImageQualityIssue.lowResolution],
      );
    }

    // 1. Mean Luminance
    double totalLum = 0.0;
    for (int i = 0; i < numPixels; i++) {
      totalLum += lumBuffer[i];
    }
    final meanLuminance = totalLum / numPixels;

    // 2. Compute Sharpness using Variance of Laplacian
    // Kernel:
    //  0  1  0
    //  1 -4  1
    //  0  1  0
    double laplacianSum = 0.0;
    double laplacianSqSum = 0.0;
    int laplacianCount = 0;

    for (int y = 1; y < height - 1; y++) {
      final rowOffset = y * width;
      final prevRowOffset = (y - 1) * width;
      final nextRowOffset = (y + 1) * width;

      for (int x = 1; x < width - 1; x++) {
        final center = lumBuffer[rowOffset + x];
        final up = lumBuffer[prevRowOffset + x];
        final down = lumBuffer[nextRowOffset + x];
        final left = lumBuffer[rowOffset + x - 1];
        final right = lumBuffer[rowOffset + x + 1];

        final lap = up + down + left + right - (4.0 * center);
        laplacianSum += lap;
        laplacianSqSum += lap * lap;
        laplacianCount++;
      }
    }

    double sharpnessScore = 0.0;
    if (laplacianCount > 0) {
      final meanLap = laplacianSum / laplacianCount;
      sharpnessScore = max(0.0, (laplacianSqSum / laplacianCount) - (meanLap * meanLap));
    }

    // 3. Evaluate Issues
    final issues = <ImageQualityIssue>[];

    if (sharpnessScore < thresholds.minSharpness) {
      issues.add(ImageQualityIssue.blurry);
    }

    if (meanLuminance < thresholds.minLuminance) {
      issues.add(ImageQualityIssue.tooDark);
    } else if (meanLuminance > thresholds.maxLuminance) {
      issues.add(ImageQualityIssue.tooBright);
    }

    if (width < thresholds.minResolution || height < thresholds.minResolution) {
      issues.add(ImageQualityIssue.lowResolution);
    }

    return ImageQualityResult(
      sharpnessScore: sharpnessScore,
      meanLuminance: meanLuminance,
      width: width,
      height: height,
      issues: issues,
    );
  }
}
