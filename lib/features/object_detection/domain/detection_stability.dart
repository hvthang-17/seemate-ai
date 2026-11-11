import 'dart:math' as math;

import '../../../shared/assistance_contracts/object_detection_contract.dart';

/// Associates same-class boxes across processed frames.
final class DetectionStability {
  static const _recognitionHits = 2;
  static const _searchHits = 3;
  static const _minimumOverlap = 0.50;

  List<({DetectedObject detection, int hits, bool missedFrame})> _previous = [];

  void reset() => _previous = [];

  /// Input and output preserve the detector's confidence order.
  List<DetectedObject> update(
    List<DetectedObject> detections, {
    required bool isTargetSearch,
  }) {
    final requiredHits = isTargetSearch ? _searchHits : _recognitionHits;
    final matches = <({int current, int previous, double overlap})>[];
    for (var current = 0; current < detections.length; current++) {
      final detection = detections[current];
      for (var previous = 0; previous < _previous.length; previous++) {
        final prior = _previous[previous].detection;
        if (detection.key != prior.key) continue;
        final overlap = _iou(detection.boundingBox, prior.boundingBox);
        if (overlap >= _minimumOverlap) {
          matches.add((current: current, previous: previous, overlap: overlap));
        }
      }
    }
    matches.sort((a, b) {
      final recencyOrder = (_previous[a.previous].missedFrame ? 1 : 0)
          .compareTo(_previous[b.previous].missedFrame ? 1 : 0);
      if (recencyOrder != 0) return recencyOrder;
      final overlapOrder = b.overlap.compareTo(a.overlap);
      if (overlapOrder != 0) return overlapOrder;
      final currentOrder = a.current.compareTo(b.current);
      return currentOrder != 0
          ? currentOrder
          : a.previous.compareTo(b.previous);
    });

    final hitsByDetection = <int, int>{};
    final usedPrevious = <int>{};
    for (final match in matches) {
      if (hitsByDetection.containsKey(match.current) ||
          !usedPrevious.add(match.previous)) {
        continue;
      }
      hitsByDetection[match.current] = math.min(
        detections[match.current].zone ==
                _previous[match.previous].detection.zone
            ? _previous[match.previous].hits + 1
            : 1,
        requiredHits,
      );
    }

    final currentTracks = [
      for (var index = 0; index < detections.length; index++)
        (
          detection: detections[index],
          hits: hitsByDetection[index] ?? 1,
          missedFrame: false,
        ),
    ];
    _previous = [
      ...currentTracks,
      if (!isTargetSearch)
        for (var index = 0; index < _previous.length; index++)
          if (!usedPrevious.contains(index) && !_previous[index].missedFrame)
            (detection: _previous[index].detection, hits: 1, missedFrame: true),
    ];
    return [
      for (final track in currentTracks)
        if (track.hits == requiredHits) track.detection,
    ];
  }

  static double _iou(BoundingBox a, BoundingBox b) {
    final width = math.min(a.right, b.right) - math.max(a.left, b.left);
    final height = math.min(a.bottom, b.bottom) - math.max(a.top, b.top);
    if (width <= 0 || height <= 0) return 0;
    final intersection = width * height;
    return intersection /
        (a.width * a.height + b.width * b.height - intersection);
  }
}
