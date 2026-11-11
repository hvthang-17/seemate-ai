import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_agentic_starter/shared/assistance_contracts/assistance_contracts.dart';

void main() {
  group('ObjectKey Vietnamese parsing', () {
    test('parses common Vietnamese phrases to matching ObjectKey', () {
      expect(ObjectKey.tryParseVietnamese('tìm chai nước'), ObjectKey.bottle);
      expect(ObjectKey.tryParseVietnamese('tìm điện thoại'), ObjectKey.phone);
      expect(ObjectKey.tryParseVietnamese('tìm quyển sách'), ObjectKey.book);
      expect(ObjectKey.tryParseVietnamese('tìm chìa khóa'), ObjectKey.keys);
      expect(ObjectKey.tryParseVietnamese('tìm cái ghế'), ObjectKey.chair);
      expect(ObjectKey.tryParseVietnamese('tìm cái bàn'), ObjectKey.table);
      expect(ObjectKey.tryParseVietnamese('tìm cái ví'), ObjectKey.wallet);
      expect(ObjectKey.tryParseVietnamese('tìm bánh mì'), ObjectKey.bread);
    });

    test('returns null for unsupported phrases', () {
      expect(ObjectKey.tryParseVietnamese('tìm con voi'), isNull);
      expect(ObjectKey.tryParseVietnamese('tìm cây bút'), isNull);
    });

    test('retains all 19 product keys for compatibility', () {
      expect(ObjectKey.values.length, 19);
    });
  });

  group('BoundingBox zone calculation', () {
    test('derives left zone when centerX < leftBoundary', () {
      const box = BoundingBox(left: 0.1, top: 0.2, width: 0.1, height: 0.2);
      expect(box.centerX, closeTo(0.15, 0.001));
      expect(box.deriveZone(), HorizontalZone.left);
    });

    test('derives center zone when centerX is between boundaries', () {
      const box = BoundingBox(left: 0.4, top: 0.2, width: 0.2, height: 0.2);
      expect(box.centerX, closeTo(0.5, 0.001));
      expect(box.deriveZone(), HorizontalZone.center);
    });

    test('derives right zone when centerX > rightBoundary', () {
      const box = BoundingBox(left: 0.7, top: 0.2, width: 0.2, height: 0.2);
      expect(box.centerX, closeTo(0.8, 0.001));
      expect(box.deriveZone(), HorizontalZone.right);
    });

    test('includes both configured boundaries in the center zone', () {
      const leftEdge = BoundingBox(left: .125, top: .2, width: .25, height: .2);
      const rightEdge = BoundingBox(left: .625, top: .2, width: .25, height: .2);
      expect(
        leftEdge.deriveZone(leftBoundary: .25, rightBoundary: .75),
        HorizontalZone.center,
      );
      expect(
        rightEdge.deriveZone(leftBoundary: .25, rightBoundary: .75),
        HorizontalZone.center,
      );
    });
  });

  group('FakeObjectDetector', () {
    test('filters detections by confidence threshold', () async {
      final detector = FakeObjectDetector(
        cannedDetections: [
          const DetectedObject(
            key: ObjectKey.bottle,
            label: 'Bottle',
            confidence: 0.75,
            boundingBox: BoundingBox(
              left: 0.1,
              top: 0.1,
              width: 0.2,
              height: 0.3,
            ),
            zone: HorizontalZone.left,
          ),
          const DetectedObject(
            key: ObjectKey.phone,
            label: 'Phone',
            confidence: 0.40,
            boundingBox: BoundingBox(
              left: 0.4,
              top: 0.1,
              width: 0.2,
              height: 0.3,
            ),
            zone: HorizontalZone.center,
          ),
        ],
      );

      final frame = createFakeCameraFrame();
      final result = await detector.detect(frame, confidenceThreshold: 0.50);

      expect(result.isRight(), isTrue);
      result.fold((_) => fail('Expected success'), (result) {
        final list = result.objects;
        expect(list.length, 1);
        expect(list.first.key, ObjectKey.bottle);
      });
    });

    test('filters detections by targetKey in search mode', () async {
      final detector = FakeObjectDetector(
        cannedDetections: [
          const DetectedObject(
            key: ObjectKey.bottle,
            label: 'Bottle',
            confidence: 0.85,
            boundingBox: BoundingBox(
              left: 0.1,
              top: 0.1,
              width: 0.2,
              height: 0.3,
            ),
            zone: HorizontalZone.left,
          ),
          const DetectedObject(
            key: ObjectKey.chair,
            label: 'Chair',
            confidence: 0.90,
            boundingBox: BoundingBox(
              left: 0.5,
              top: 0.1,
              width: 0.3,
              height: 0.5,
            ),
            zone: HorizontalZone.center,
          ),
        ],
      );

      final frame = createFakeCameraFrame();
      final result = await detector.detect(frame, targetKey: ObjectKey.chair);

      result.fold((_) => fail('Expected success'), (result) {
        final list = result.objects;
        expect(list.length, 1);
        expect(list.first.key, ObjectKey.chair);
      });
    });
  });
}
