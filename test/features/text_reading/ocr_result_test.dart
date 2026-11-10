import 'dart:typed_data';

import 'package:flutter_agentic_starter/features/text_reading/data/fake_ocr_engine.dart';
import 'package:flutter_agentic_starter/features/text_reading/domain/enhanced_ocr_result.dart';
import 'package:flutter_agentic_starter/features/text_reading/domain/image_quality_assessor.dart';
import 'package:flutter_agentic_starter/features/text_reading/domain/ocr_engine.dart';
import 'package:flutter_agentic_starter/shared/assistance_contracts/ocr_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OcrResult Contract & Hierarchy', () {
    test('OcrSuccess preserves Vietnamese diacritics and equals by text', () {
      const sample =
          'Thuốc nhỏ mắt V.Rohto kháng khuẩn - Hạn sử dụng: 12/2026. Giá: 50.000đ';
      const result1 = OcrSuccess(sample);
      const result2 = OcrSuccess(sample);

      expect(result1, equals(result2));
      expect(result1.text, equals(sample));
      expect(result1.text.contains('kháng khuẩn'), isTrue);
      expect(result1.toString(), contains(sample));
    });

    test('OcrEmpty equality and toString', () {
      const empty1 = OcrEmpty();
      const empty2 = OcrEmpty();

      expect(empty1, equals(empty2));
      expect(empty1.toString(), equals('OcrEmpty()'));
    });

    test('OcrFailure captures error message', () {
      const failure1 = OcrFailure('File corrupt');
      const failure2 = OcrFailure('File corrupt');

      expect(failure1, equals(failure2));
      expect(failure1.message, equals('File corrupt'));
    });

    test('OcrCancelled represents cancellation cleanly', () {
      const cancelled = OcrCancelled();
      expect(cancelled, isA<OcrResult>());
      expect(cancelled.toString(), equals('OcrCancelled()'));
    });
  });

  group('FakeOcrEngine execution', () {
    late FakeOcrEngine engine;

    setUp(() {
      engine = FakeOcrEngine();
    });

    tearDown(() async {
      await engine.dispose();
    });

    test('recognizeFromFile delegates properly and returns OcrSuccess', () async {
      const expectedText = 'Công hòa Xã hội Chủ nghĩa Việt Nam';
      engine.cannedResult = const OcrSuccess(expectedText);

      final result = await engine.recognizeFromFile('/path/to/doc.jpg');
      expect(result, isA<OcrSuccess>());
      expect((result as OcrSuccess).text, equals(expectedText));
      expect(engine.lastRecognizedFile, equals('/path/to/doc.jpg'));
    });

    test('recognizeFromFile returns OcrEmpty when image has no text', () async {
      engine.cannedResult = const OcrEmpty();

      final result = await engine.recognizeFromFile('/path/to/blank.jpg');
      expect(result, isA<OcrEmpty>());
    });

    test('recognizeFromFile returns OcrFailure when error occurs', () async {
      engine.cannedResult = const OcrFailure('Image decode failed');

      final result = await engine.recognizeFromFile('/path/to/bad.jpg');
      expect(result, isA<OcrFailure>());
      expect((result as OcrFailure).message, contains('Image decode failed'));
    });

    test('recognizeFromInput passes frame bytes and metadata', () async {
      const metadata = ImageMetadata(
        width: 1280,
        height: 720,
        format: PixelFormat.nv21,
        rotationDegrees: 90,
      );
      final input = OcrInput(
        sessionId: 'session-123',
        bytes: Uint8List.fromList([1, 2, 3]),
        metadata: metadata,
      );

      engine.cannedResult = const OcrSuccess('Bảng hiệu nhà thuốc');
      final result = await engine.recognizeFromInput(input);

      expect(result, isA<OcrSuccess>());
      expect(engine.lastRecognizedInput?.sessionId, equals('session-123'));
      expect(engine.lastRecognizedInput?.metadata.rotationDegrees, equals(90));
    });

    test('returns failure after engine is disposed', () async {
      await engine.dispose();
      final result = await engine.recognizeFromFile('/path/to/doc.jpg');
      expect(result, isA<OcrFailure>());
    });
  });
}
