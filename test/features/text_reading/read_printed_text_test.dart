import 'dart:typed_data';

import 'package:flutter_agentic_starter/features/text_reading/text_reading.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReadPrintedText & MlkitTextSource', () {
    late FakeMlkitPlugin fakePlugin;
    late MlkitTextSource source;
    late TextReadingRepositoryImpl repository;
    late ReadPrintedText useCase;

    final dummyBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
    const metadata = ImageMetadata(
      width: 1920,
      height: 1080,
      format: PixelFormat.nv21,
      rotationDegrees: 90,
    );

    setUp(() {
      fakePlugin = FakeMlkitPlugin();
      source = MlkitTextSource(fakePlugin);
      repository = TextReadingRepositoryImpl(source);
      useCase = ReadPrintedText(repository);
    });

    tearDown(() async {
      await source.dispose();
    });

    test('returns OcrSuccess with Vietnamese diacritics preserved', () async {
      const vietnameseText = 'Thuốc nhỏ mắt V.Rohto - Hạn sử dụng: 12/2027';
      fakePlugin.response = vietnameseText;

      final input = OcrInput(
        sessionId: 'session-001',
        bytes: dummyBytes,
        metadata: metadata,
      );

      final result = await useCase(input);

      expect(result, isA<OcrSuccess>());
      expect((result as OcrSuccess).text, equals(vietnameseText));
      expect(fakePlugin.lastBytes, equals(dummyBytes));
      expect(fakePlugin.lastMetadata, equals(metadata));
    });

    test('returns OcrEmpty when plugin detects no text (null)', () async {
      fakePlugin.response = null;

      final input = OcrInput(
        sessionId: 'session-002',
        bytes: dummyBytes,
        metadata: metadata,
      );

      final result = await useCase(input);
      expect(result, isA<OcrEmpty>());
    });

    test('returns OcrEmpty when plugin returns whitespace-only text', () async {
      fakePlugin.response = '   \n  \t  ';

      final input = OcrInput(
        sessionId: 'session-003',
        bytes: dummyBytes,
        metadata: metadata,
      );

      final result = await useCase(input);
      expect(result, isA<OcrEmpty>());
    });

    test('returns OcrFailure when plugin throws an exception', () async {
      fakePlugin.shouldThrow = true;

      final input = OcrInput(
        sessionId: 'session-004',
        bytes: dummyBytes,
        metadata: metadata,
      );

      final result = await useCase(input);
      expect(result, isA<OcrFailure>());
      expect((result as OcrFailure).message, contains('ML Kit native recognition error'));
    });

    test('returns OcrCancelled when session was cancelled before execution', () async {
      fakePlugin.response = 'Some text';

      final input = OcrInput(
        sessionId: 'session-to-cancel-early',
        bytes: dummyBytes,
        metadata: metadata,
      );

      repository.cancelSession('session-to-cancel-early');

      final result = await useCase(input);
      expect(result, isA<OcrCancelled>());
    });

    test('returns OcrFailure when source is already disposed', () async {
      await source.dispose();

      final input = OcrInput(
        sessionId: 'session-after-dispose',
        bytes: dummyBytes,
        metadata: metadata,
      );

      final result = await useCase(input);
      expect(result, isA<OcrFailure>());
      expect((result as OcrFailure).message, contains('disposed'));
    });

    test('dispose closes the underlying plugin', () async {
      expect(fakePlugin.isClosed, isFalse);
      await source.dispose();
      expect(fakePlugin.isClosed, isTrue);
    });
  });
}
