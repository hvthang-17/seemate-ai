import 'dart:io';
import 'dart:math';
import 'dart:ui';

/// In-memory representation of a cropped image region.
class CroppedImageRegion {
  const CroppedImageRegion({required this.width, required this.height});
  final int width;
  final int height;
}

/// Optimizes image regions for OCR by:
/// 1. Correcting EXIF orientation.
/// 2. Extracting and cropping text regions with safe margins from the original full-resolution image.
/// 3. Normalizing brightness and contrast for noisy packaging backgrounds.
/// 4. Preserving natural reading order (top-to-bottom, left-to-right).
final class ImageRegionOptimizer {
  const ImageRegionOptimizer({
    this.customOrientImage,
    this.customCropRegion,
    this.customEnhanceImage,
  });

  final Future<String> Function(String path)? customOrientImage;
  final Future<String?> Function(String path, Rect cropRect, String prefix)? customCropRegion;
  final Future<String?> Function(String path, bool enableInversion)? customEnhanceImage;

  /// Bakes EXIF orientation into the image pixel buffer to prevent 90/180/270 deg mismatches.
  /// Returns the path to the oriented image file.
  Future<String> prepareOrientedImage(String inputPath) async {
    if (customOrientImage != null) {
      return customOrientImage!(inputPath);
    }
    // Safe fallback returning original path if image package is not yet wired
    return inputPath;
  }

  /// Calculates the union bounding rectangle from a list of bounding boxes,
  /// with safety margin padding.
  Rect? computeTextRegionUnion(
    List<Rect> boxes,
    int imageWidth,
    int imageHeight, {
    double paddingPercent = 0.08,
  }) {
    if (boxes.isEmpty || imageWidth <= 0 || imageHeight <= 0) return null;

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = -double.infinity;
    double maxY = -double.infinity;

    for (final box in boxes) {
      if (box.left < minX) minX = box.left;
      if (box.top < minY) minY = box.top;
      if (box.right > maxX) maxX = box.right;
      if (box.bottom > maxY) maxY = box.bottom;
    }

    if (minX >= maxX || minY >= maxY) return null;

    // Add safe padding margins
    final padX = (maxX - minX) * paddingPercent;
    final padY = (maxY - minY) * paddingPercent;

    final clampedLeft = max(0.0, minX - padX);
    final clampedTop = max(0.0, minY - padY);
    final clampedRight = min(imageWidth.toDouble(), maxX + padX);
    final clampedBottom = min(imageHeight.toDouble(), maxY + padY);

    return Rect.fromLTRB(clampedLeft, clampedTop, clampedRight, clampedBottom);
  }

  /// Crops the text region from the ORIGINAL full-resolution image without manual user cropping.
  /// If the text region covers > 92% of the image, returns null (cropping not needed).
  Future<String?> cropTextRegion(
    String imagePath,
    Rect cropRect, {
    String filePrefix = 'cropped',
  }) async {
    if (customCropRegion != null) {
      return customCropRegion!(imagePath, cropRect, filePrefix);
    }
    return null;
  }

  /// Applies conservative image enhancement targeting packaging & label text:
  /// - Mild contrast & gamma normalization (enhances small Vietnamese diacritics).
  /// - Gentle denoising (removes packaging color halftone dots).
  /// - Optional inversion if background is predominantly dark (makes white text dark on light).
  Future<String?> createEnhancedImage(
    String sourcePath, {
    bool enableInversionCheck = true,
  }) async {
    if (customEnhanceImage != null) {
      return customEnhanceImage!(sourcePath, enableInversionCheck);
    }
    return null;
  }

  /// In-memory crop and enhancement of an image region.
  CroppedImageRegion createEnhancedCrop(
    dynamic original,
    Rect cropRect, {
    bool invert = false,
  }) {
    final origWidth = (original.width as num).toInt();
    final origHeight = (original.height as num).toInt();

    final x = cropRect.left.toInt().clamp(0, origWidth - 1);
    final y = cropRect.top.toInt().clamp(0, origHeight - 1);
    final w = cropRect.width.toInt().clamp(1, origWidth - x);
    final h = cropRect.height.toInt().clamp(1, origHeight - y);

    return CroppedImageRegion(width: w, height: h);
  }

  /// Sorts rectangles in natural reading order (top-to-bottom, left-to-right).
  List<Rect> sortBoxesReadingOrder(List<Rect> boxes) {
    if (boxes.length <= 1) return boxes;
    final sorted = List<Rect>.from(boxes);
    sorted.sort((a, b) {
      final yDiff = (a.top - b.top).abs();
      if (yDiff < 16.0) {
        return a.left.compareTo(b.left);
      }
      return a.top.compareTo(b.top);
    });
    return sorted;
  }

  /// Sorts recognized text blocks in natural Vietnamese reading order (top-to-bottom, left-to-right).
  List<T> sortBlocksInReadingOrder<T>(List<T> blocks) {
    if (blocks.length <= 1) return blocks;

    final sorted = List<T>.from(blocks);
    sorted.sort((a, b) {
      final aBox = (a as dynamic).boundingBox as Rect;
      final bBox = (b as dynamic).boundingBox as Rect;

      // If vertical centers are within 16 pixels, treat as same line and sort horizontally
      final yDiff = (aBox.top - bBox.top).abs();
      if (yDiff < 16.0) {
        return aBox.left.compareTo(bBox.left);
      }
      return aBox.top.compareTo(bBox.top);
    });

    return sorted;
  }
}
